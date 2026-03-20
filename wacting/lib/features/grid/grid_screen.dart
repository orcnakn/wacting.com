import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'providers/grid_state.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/services/socket_service.dart';
import '../../core/config/app_config.dart';
import '../../core/models/icon_model.dart';
import '../../app/constants.dart';
import '../../app/theme.dart';
import 'day_night_layer.dart';
import 'lod_manager.dart';

// ─── Continent → Country mapping ─────────────────────────────────────────────
const Map<String, List<String>> _continentCountries = {
  'Europe': [
    'Albania','Andorra','Austria','Belarus','Belgium','Bosnia and Herzegovina',
    'Bulgaria','Croatia','Cyprus','Czech Republic','Czechia','Denmark','Estonia',
    'Finland','France','Germany','Greece','Hungary','Iceland','Ireland','Italy',
    'Kosovo','Latvia','Liechtenstein','Lithuania','Luxembourg','Malta','Moldova',
    'Monaco','Montenegro','Netherlands','North Macedonia','Norway','Poland',
    'Portugal','Romania','Russia','San Marino','Serbia','Slovakia','Slovenia',
    'Spain','Sweden','Switzerland','Ukraine','United Kingdom','Vatican',
    'Republic of Serbia','Northern Cyprus',
  ],
  'Asia': [
    'Afghanistan','Armenia','Azerbaijan','Bahrain','Bangladesh','Bhutan','Brunei',
    'Cambodia','China','East Timor','Timor-Leste','Georgia','India','Indonesia',
    'Iran','Iraq','Israel','Japan','Jordan','Kazakhstan','Kuwait','Kyrgyzstan',
    'Laos','Lebanon','Malaysia','Maldives','Mongolia','Myanmar','Nepal','North Korea',
    'Oman','Pakistan','Palestine','Philippines','Qatar','Saudi Arabia','Singapore',
    'South Korea','Sri Lanka','Syria','Taiwan','Tajikistan','Thailand','Turkey',
    'Turkmenistan','United Arab Emirates','Uzbekistan','Vietnam','Yemen',
  ],
  'Africa': [
    'Algeria','Angola','Benin','Botswana','Burkina Faso','Burundi','Cameroon',
    'Cape Verde','Central African Republic','Chad','Comoros','Congo',
    'Democratic Republic of the Congo','Republic of the Congo',
    'Ivory Coast','Djibouti','Egypt','Equatorial Guinea','Eritrea','Eswatini',
    'Ethiopia','Gabon','Gambia','Ghana','Guinea','Guinea-Bissau','Kenya','Lesotho',
    'Liberia','Libya','Madagascar','Malawi','Mali','Mauritania','Mauritius','Morocco',
    'Mozambique','Namibia','Niger','Nigeria','Rwanda','Senegal','Sierra Leone',
    'Somalia','Somaliland','South Africa','South Sudan','Sudan','Tanzania','Togo',
    'Tunisia','Uganda','Zambia','Zimbabwe','Western Sahara',
    'United Republic of Tanzania','Swaziland','Côte d\'Ivoire',
  ],
  'North America': [
    'Antigua and Barbuda','Bahamas','Barbados','Belize','Canada','Costa Rica',
    'Cuba','Dominica','Dominican Republic','El Salvador','Grenada','Guatemala',
    'Haiti','Honduras','Jamaica','Mexico','Nicaragua','Panama','Saint Kitts and Nevis',
    'Saint Lucia','Saint Vincent and the Grenadines','Trinidad and Tobago',
    'United States of America','United States','Puerto Rico','Greenland',
  ],
  'South America': [
    'Argentina','Bolivia','Brazil','Chile','Colombia','Ecuador','Guyana','Paraguay',
    'Peru','Suriname','Uruguay','Venezuela','French Guiana','Falkland Islands',
  ],
  'Oceania': [
    'Australia','Fiji','Kiribati','Marshall Islands','Micronesia','Nauru',
    'New Zealand','Palau','Papua New Guinea','Samoa','Solomon Islands','Tonga',
    'Tuvalu','Vanuatu','New Caledonia',
  ],
  'Antarctica': ['Antarctica'],
};

String? _continentForCountry(String countryName) {
  for (final entry in _continentCountries.entries) {
    if (entry.value.contains(countryName)) return entry.key;
  }
  return null;
}
// ─────────────────────────────────────────────────────────────────────────────

class GridScreen extends ConsumerStatefulWidget {
  const GridScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<GridScreen> createState() => _GridScreenState();
}

class _GridScreenState extends ConsumerState<GridScreen> {
  final MapController _mapController = MapController();
  double _currentZoom = 4.0;
  final LatLng _initialCenter = const LatLng(41.0082, 28.9784);

  // ── Region selection state ──
  bool _regionSelectMode = false;       // toggle: show/hide polygon overlay
  List<_CountryPolygon> _countryPolygons = [];  // 110m countries
  List<_CountryPolygon> _admin1Polygons = [];   // 50m admin-1 (states/provinces)
  List<_CountryPolygon> _oceanPolygons = [];    // ocean/sea regions
  List<_CityPoint> _cityPoints = [];            // major cities
  final Set<String> _selectedCountries = {};    // individual country names
  final Set<String> _selectedContinents = {};   // whole-continent selections
  final Set<String> _excludedCountries = {};    // countries excluded from continent selection
  final Set<String> _selectedRegions = {};      // admin-1 regions ("state|country")
  final Set<String> _selectedOceans = {};       // ocean/sea names
  final Set<String> _selectedCities = {};       // city names ("city|country")
  bool _isCountriesLoaded = false;
  bool _isAdmin1Loaded = false;
  bool _isOceansLoaded = false;
  bool _isCitiesLoaded = false;

  // ── Pause/Resume state ──
  bool _paused = false;
  List<IconModel> _pausedSnapshot = [];
  List<IconModel>? _lastIcons;

  // ── Map filter state ──
  String _mapFilter = 'all'; // all, nearby, trending, protested, newest
  bool _filterDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    socketService.connect(AppConfig.socketUrl);
  }

  // ── Lazy-load 110m countries ──
  Future<void> _ensureCountriesLoaded() async {
    if (_isCountriesLoaded) return;
    try {
      final raw = await rootBundle.loadString('assets/map/ne_110m_countries.geojson');
      final Map<String, dynamic> geoJson = jsonDecode(raw);
      final List features = geoJson['features'] as List;

      final List<_CountryPolygon> parsed = [];
      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        final name = (props['ADMIN'] ?? props['NAME'] ?? props['name'] ?? 'Unknown') as String;
        final continent = (props['CONTINENT'] ?? '') as String;
        final geometry = feature['geometry'];
        final type = geometry['type'] as String;

        if (type == 'Polygon') {
          final coords = geometry['coordinates'] as List;
          parsed.add(_CountryPolygon(
            name: name,
            continent: continent.isNotEmpty ? continent : _continentForCountry(name),
            parentCountry: null,
            outerRing: _parseRing(coords[0] as List),
            holes: coords.length > 1
                ? coords.sublist(1).map((h) => _parseRing(h as List)).toList()
                : <List<LatLng>>[],
          ));
        } else if (type == 'MultiPolygon') {
          for (final polygon in geometry['coordinates'] as List) {
            parsed.add(_CountryPolygon(
              name: name,
              continent: continent.isNotEmpty ? continent : _continentForCountry(name),
              parentCountry: null,
              outerRing: _parseRing((polygon as List)[0] as List),
              holes: polygon.length > 1
                  ? polygon.sublist(1).map((h) => _parseRing(h as List)).toList()
                  : <List<LatLng>>[],
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _countryPolygons = parsed;
          _isCountriesLoaded = true;
        });
      }
    } catch (e) {
      debugPrint("Failed to load country borders: $e");
    }
  }

  // ── Lazy-load 50m admin-1 (states/provinces) ──
  Future<void> _ensureAdmin1Loaded() async {
    if (_isAdmin1Loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/map/ne_50m_admin1.geojson');
      final Map<String, dynamic> geoJson = jsonDecode(raw);
      final List features = geoJson['features'] as List;

      final List<_CountryPolygon> parsed = [];
      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        final name = (props['name'] ?? 'Unknown') as String;
        final admin = (props['admin'] ?? 'Unknown') as String;
        final geometry = feature['geometry'];
        final type = geometry['type'] as String;

        if (type == 'Polygon') {
          final coords = geometry['coordinates'] as List;
          parsed.add(_CountryPolygon(
            name: name,
            continent: _continentForCountry(admin),
            parentCountry: admin,
            outerRing: _parseRing(coords[0] as List),
            holes: coords.length > 1
                ? coords.sublist(1).map((h) => _parseRing(h as List)).toList()
                : <List<LatLng>>[],
          ));
        } else if (type == 'MultiPolygon') {
          for (final polygon in geometry['coordinates'] as List) {
            parsed.add(_CountryPolygon(
              name: name,
              continent: _continentForCountry(admin),
              parentCountry: admin,
              outerRing: _parseRing((polygon as List)[0] as List),
              holes: polygon.length > 1
                  ? polygon.sublist(1).map((h) => _parseRing(h as List)).toList()
                  : <List<LatLng>>[],
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _admin1Polygons = parsed;
          _isAdmin1Loaded = true;
        });
      }
    } catch (e) {
      debugPrint("Failed to load admin-1 borders: $e");
    }
  }

  Future<void> _ensureOceansLoaded() async {
    if (_isOceansLoaded) return;
    try {
      final raw = await rootBundle.loadString('assets/map/ocean_regions.geojson');
      final Map<String, dynamic> geoJson = jsonDecode(raw);
      final List features = geoJson['features'] as List;
      final List<_CountryPolygon> parsed = [];
      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        final name = (props['name'] ?? 'Unknown') as String;
        final geometry = feature['geometry'];
        final type = geometry['type'] as String;
        if (type == 'Polygon') {
          final coords = geometry['coordinates'] as List;
          parsed.add(_CountryPolygon(
            name: name, continent: null, parentCountry: null,
            outerRing: _parseRing(coords[0] as List),
            holes: coords.length > 1
                ? coords.sublist(1).map((h) => _parseRing(h as List)).toList()
                : <List<LatLng>>[],
          ));
        }
      }
      if (mounted) {
        setState(() { _oceanPolygons = parsed; _isOceansLoaded = true; });
      }
    } catch (e) {
      debugPrint("Failed to load ocean regions: $e");
    }
  }

  Future<void> _ensureCitiesLoaded() async {
    if (_isCitiesLoaded) return;
    try {
      final raw = await rootBundle.loadString('assets/map/major_cities.geojson');
      final Map<String, dynamic> geoJson = jsonDecode(raw);
      final List features = geoJson['features'] as List;
      final List<_CityPoint> parsed = [];
      for (final feature in features) {
        final props = feature['properties'] as Map<String, dynamic>;
        final coords = feature['geometry']['coordinates'] as List;
        parsed.add(_CityPoint(
          name: (props['name'] ?? '') as String,
          country: (props['country'] ?? '') as String,
          continent: (props['continent'] ?? '') as String,
          point: LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
          population: (props['population'] as num?)?.toInt() ?? 0,
        ));
      }
      if (mounted) {
        setState(() { _cityPoints = parsed; _isCitiesLoaded = true; });
      }
    } catch (e) {
      debugPrint("Failed to load cities: $e");
    }
  }

  List<LatLng> _parseRing(List coords) {
    return coords.map<LatLng>((c) => LatLng((c as List)[1].toDouble(), c[0].toDouble())).toList();
  }

  @override
  void dispose() {
    socketService.dispose();
    super.dispose();
  }

  LatLng _offsetToLatLng(Offset pos) {
    double lng = (pos.dx / 510) * 360 - 180;
    double lat = 90 - (pos.dy / 510) * 180;
    // Normalize longitude to -180..180
    while (lng > 180) lng -= 360;
    while (lng < -180) lng += 360;
    return LatLng(lat.clamp(-90, 90), lng);
  }

  // ── Ray-casting point-in-polygon ──
  bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) != (polygon[j].latitude > point.latitude) &&
          point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  String? _findCountryAtPoint(LatLng point) {
    for (final cp in _countryPolygons) {
      if (_pointInPolygon(point, cp.outerRing)) {
        bool inHole = false;
        for (final hole in cp.holes) {
          if (_pointInPolygon(point, hole)) { inHole = true; break; }
        }
        if (!inHole) return cp.name;
      }
    }
    return null;
  }

  String? _findOceanAtPoint(LatLng point) {
    // First try specific sea/ocean polygons from GeoJSON
    for (final cp in _oceanPolygons) {
      if (_pointInPolygon(point, cp.outerRing)) return cp.name;
    }
    // Fallback: determine ocean by coordinates (covers gaps in polygons)
    final lat = point.latitude;
    final lng = point.longitude;
    // Southern Ocean
    if (lat < -60) return 'Southern Ocean';
    // Arctic Ocean
    if (lat > 65) return 'Arctic Ocean';
    // Indian Ocean: roughly between Africa, Asia and Australia
    if (lat < 30 && lat > -60 && lng > 20 && lng < 120) return 'Indian Ocean';
    // South Pacific: southern hemisphere, east of Australia to Americas
    if (lat < 0 && (lng >= 120 || lng < -60)) return 'South Pacific Ocean';
    // North Pacific: northern hemisphere, Asia to Americas (wide)
    if (lat >= 0 && lat <= 65 && (lng >= 120 || lng <= -80)) return 'North Pacific Ocean';
    // South Atlantic: southern hemisphere, between Americas and Africa
    if (lat < 0 && lng >= -60 && lng <= 20) return 'South Atlantic Ocean';
    // North Atlantic: default for remaining northern water
    return 'North Atlantic Ocean';
  }

  _CityPoint? _findNearestCity(LatLng point, {double maxDistKm = 50.0}) {
    _CityPoint? nearest;
    double minDist = double.infinity;
    for (final city in _cityPoints) {
      final dist = const Distance().as(LengthUnit.Kilometer, point, city.point);
      if (dist < minDist && dist <= maxDistKm) {
        minDist = dist;
        nearest = city;
      }
    }
    return nearest;
  }

  // Find admin-1 region at a point
  _CountryPolygon? _findAdmin1AtPoint(LatLng point) {
    for (final cp in _admin1Polygons) {
      if (_pointInPolygon(point, cp.outerRing)) {
        bool inHole = false;
        for (final hole in cp.holes) {
          if (_pointInPolygon(point, hole)) { inHole = true; break; }
        }
        if (!inHole) {
          debugPrint('🏙️ Found admin-1: ${cp.name} (${cp.parentCountry})');
          return cp;
        }
      }
    }
    return null;
  }

  // ── Determine current zoom level label ──
  String get _zoomLevel {
    if (_currentZoom < 4) return 'continents';
    if (_currentZoom < 7) return 'countries';
    if (_currentZoom < 10) return 'regions';
    return 'cities';
  }

  // ── Check if a country polygon is selected (directly or via continent) ──
  bool _isCountrySelected(String countryName) {
    // Excluded countries are never selected (even if their continent is)
    if (_excludedCountries.contains(countryName)) return false;
    if (_selectedCountries.contains(countryName)) return true;
    final cont = _continentForCountry(countryName);
    if (cont != null && _selectedContinents.contains(cont)) return true;
    return false;
  }

  // Check if an admin-1 region is selected
  bool _isRegionSelected(String regionName, String? parentCountry) {
    final key = '$regionName|$parentCountry';
    if (_selectedRegions.contains(key)) return true;
    // Also selected if its parent country is selected
    if (parentCountry != null && _isCountrySelected(parentCountry)) return true;
    return false;
  }

  // ── World offsets for multi-copy rendering ──
  static const List<double> _worldOffsets = [-720, -360, 0, 360, 720];

  // ── Create polygon copies at each world offset ──
  List<Polygon> _multiWorldPolygon(_CountryPolygon cp, Color fillColor, Color borderColor, double borderWidth) {
    return _worldOffsets.map((offset) => Polygon(
      points: cp.outerRing.map((p) => LatLng(p.latitude, p.longitude + offset)).toList(),
      holePointsList: cp.holes.map((hole) =>
        hole.map((p) => LatLng(p.latitude, p.longitude + offset)).toList()
      ).toList(),
      color: fillColor,
      borderColor: borderColor,
      borderStrokeWidth: borderWidth,
      isFilled: true,
    )).toList();
  }

  // ── Normalize longitude to -180..180 ──
  LatLng _normalizeLng(LatLng point) {
    double lng = point.longitude;
    while (lng > 180) lng -= 360;
    while (lng < -180) lng += 360;
    return LatLng(point.latitude, lng);
  }

  // ── Handle tap in region-select mode ──
  void _handleRegionTap(LatLng rawPoint) {
    // Normalize longitude so taps on any world copy map to the same region
    final point = _normalizeLng(rawPoint);
    final level = _zoomLevel;

    if (level == 'continents') {
      final country = _findCountryAtPoint(point);
      if (country == null) {
        if (_isOceansLoaded) {
          final ocean = _findOceanAtPoint(point);
          if (ocean != null) {
            setState(() {
              if (_selectedOceans.contains(ocean)) {
                _selectedOceans.remove(ocean);
              } else {
                _selectedOceans.add(ocean);
              }
            });
            _showSelectionSnackbar(ocean);
          }
        }
        return;
      }
      final continent = _continentForCountry(country);
      if (continent == null) return;

      setState(() {
        if (_selectedContinents.contains(continent)) {
          _selectedContinents.remove(continent);
          final members = _continentCountries[continent] ?? [];
          _selectedCountries.removeAll(members);
          _excludedCountries.removeAll(members); // Clear exclusions too
        } else {
          _selectedContinents.add(continent);
          // Clear any individual selections for countries in this continent
          // since the continent selection covers them all
          final members = _continentCountries[continent] ?? [];
          _selectedCountries.removeAll(members);
        }
      });
      _showSelectionSnackbar('🌍 $continent');
    } else if (level == 'countries') {
      final country = _findCountryAtPoint(point);
      if (country == null) {
        if (_isOceansLoaded) {
          final ocean = _findOceanAtPoint(point);
          if (ocean != null) {
            setState(() {
              if (_selectedOceans.contains(ocean)) {
                _selectedOceans.remove(ocean);
              } else {
                _selectedOceans.add(ocean);
              }
            });
            _showSelectionSnackbar(ocean);
          }
        }
        return;
      }

      final cont = _continentForCountry(country);
      final isViaContinent = cont != null && _selectedContinents.contains(cont);

      setState(() {
        if (_excludedCountries.contains(country)) {
          _excludedCountries.remove(country);
        } else if (isViaContinent) {
          _excludedCountries.add(country);
        } else if (_selectedCountries.contains(country)) {
          _selectedCountries.remove(country);
        } else {
          _selectedCountries.add(country);
        }
      });
      final excluded = _excludedCountries.contains(country);
      _showSelectionSnackbar(excluded ? '$country (cikarildi)' : country);
    } else if (level == 'cities') {
      // First check if tap is on land
      final country = _findCountryAtPoint(point);
      if (country != null) {
        if (_isCitiesLoaded) {
          final city = _findNearestCity(point);
          if (city != null) {
            final key = '${city.name}|${city.country}';
            setState(() {
              if (_selectedCities.contains(key)) {
                _selectedCities.remove(key);
              } else {
                _selectedCities.add(key);
              }
            });
            _showSelectionSnackbar('${city.name} (${city.country})');
            return;
          }
        }
        if (_isAdmin1Loaded) {
          final region = _findAdmin1AtPoint(point);
          if (region != null) {
            final key = '${region.name}|${region.parentCountry}';
            setState(() {
              if (_selectedRegions.contains(key)) {
                _selectedRegions.remove(key);
              } else {
                _selectedRegions.add(key);
              }
            });
            _showSelectionSnackbar('${region.name} (${region.parentCountry})');
            return;
          }
        }
      } else {
        // Water area - try ocean selection
        _trySelectOcean(point);
      }
    } else {
      // Regions zoom (>=7) — select admin-1 state/province
      // First check if on land
      final country = _findCountryAtPoint(point);
      if (country != null) {
        if (_isAdmin1Loaded) {
          final region = _findAdmin1AtPoint(point);
          if (region != null) {
            final key = '${region.name}|${region.parentCountry}';
            final parentCountry = region.parentCountry;

            setState(() {
              if (_selectedRegions.contains(key)) {
                _selectedRegions.remove(key);
              } else if (parentCountry != null && _excludedCountries.contains(parentCountry)) {
                _selectedRegions.add(key);
              } else if (parentCountry != null && _isCountrySelected(parentCountry)) {
                _selectedRegions.add(key);
              } else {
                _selectedRegions.add(key);
              }
            });
            _showSelectionSnackbar('${region.name} (${region.parentCountry})');
            return;
          }
        }
        // Fallback: country-level selection
        setState(() {
          if (_selectedCountries.contains(country)) {
            _selectedCountries.remove(country);
          } else {
            _selectedCountries.add(country);
          }
        });
        _showSelectionSnackbar(country);
      } else {
        // Water area - try ocean selection
        _trySelectOcean(point);
      }
    }
  }

  void _trySelectOcean(LatLng point) {
    if (!_isOceansLoaded) return;
    final ocean = _findOceanAtPoint(point);
    if (ocean != null) {
      setState(() {
        if (_selectedOceans.contains(ocean)) {
          _selectedOceans.remove(ocean);
        } else {
          _selectedOceans.add(ocean);
        }
      });
      _showSelectionSnackbar(ocean);
    }
  }

  void _showSelectionSnackbar(String label) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label | Toplam: $_totalSelectionCount bolge',
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: AppColors.accentBlue,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Summary of all selected regions ──
  String get _selectionSummary {
    final parts = <String>[];
    for (final c in _selectedContinents) {
      final excluded = _excludedCountries.where((cc) {
        final cont = _continentForCountry(cc);
        return cont == c;
      }).toList();
      final reIncludedRegions = _selectedRegions.where((r) {
        final split = r.split('|');
        if (split.length < 2) return false;
        return excluded.contains(split[1]);
      }).toList();
      if (excluded.isEmpty) {
        parts.add(c);
      } else {
        final excStr = excluded.join(', ');
        if (reIncludedRegions.isEmpty) {
          parts.add('$c ($excStr haric)');
        } else {
          final reStr = reIncludedRegions.map((r) => r.split('|')[0]).join(', ');
          parts.add('$c ($excStr haric, $reStr dahil)');
        }
      }
    }
    for (final c in _selectedCountries) {
      final cont = _continentForCountry(c);
      if (cont != null && _selectedContinents.contains(cont)) continue;
      final regionExclusions = _selectedRegions.where((r) {
        final split = r.split('|');
        return split.length >= 2 && split[1] == c;
      }).toList();
      if (regionExclusions.isEmpty) {
        parts.add(c);
      } else {
        final regStr = regionExclusions.map((r) => r.split('|')[0]).join(', ');
        parts.add('$c ($regStr dahil)');
      }
    }
    for (final r in _selectedRegions) {
      final split = r.split('|');
      final parent = split.length >= 2 ? split[1] : null;
      if (parent != null && _isCountrySelected(parent)) continue;
      if (parent != null && _excludedCountries.contains(parent)) continue;
      parts.add('${split[0]}${parent != null ? ' ($parent)' : ''}');
    }
    return parts.isEmpty ? 'Seçim yok' : parts.join(', ');
  }

  int get _totalSelectionCount {
    final all = <String>{..._selectedCountries};
    for (final c in _selectedContinents) {
      all.addAll(_continentCountries[c] ?? []);
    }
    all.removeAll(_excludedCountries);
    return all.length + _selectedRegions.length + _selectedOceans.length + _selectedCities.length;
  }

  // Active polygons based on zoom level
  bool get _isGeoJsonLoaded => _isCountriesLoaded;
  List<_CountryPolygon> get _activePolygons {
    if (_currentZoom >= 10 && _isAdmin1Loaded) return _admin1Polygons;
    if (_currentZoom >= 7 && _isAdmin1Loaded) return _admin1Polygons;
    return _countryPolygons;
  }

  // ──────────────────────────── BUILD ────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<List<IconModel>>(
            stream: socketService.iconStream,
            initialData: const [],
            builder: (context, snapshot) {
              final liveIcons = snapshot.data ?? [];

              if (!_paused) {
                _pausedSnapshot = liveIcons;
              }
              _lastIcons = _paused ? _pausedSnapshot : liveIcons;
              final icons = _lastIcons!;

              const circleAuras = <CircleMarker>[];

              final zoom = _currentZoom;

              final markerDots = <Marker>[];
              for (final icon in icons) {
                  final latLng = _offsetToLatLng(icon.position);
                  final Color displayColor = icon.displayColor;
                  final double wacSize = icon.size;
                  final double baseOpacity = LodManager.opacityForWac(wacSize, zoom);

                  for (final worldOffset in _worldOffsets) {
                    final offsetPoint = LatLng(latLng.latitude, latLng.longitude + worldOffset);

                    if (LodManager.isFullDetail(zoom, wacSize)) {
                      final String? slogan = icon.campaignSlogan;
                      final double rectW = LodManager.rectWidth(wacSize, zoom);
                      final double rectH = LodManager.rectHeight(wacSize, zoom);
                      final double fontSize = LodManager.sloganFontSize(wacSize, zoom);
                      final double markerW = slogan != null ? (rectW + 40).clamp(rectW, 140.0) : rectW + 4;
                      final double markerH = slogan != null ? rectH + fontSize + 8 : rectH + 4;

                      markerDots.add(Marker(
                          point: offsetPoint,
                          width: markerW,
                          height: markerH,
                          child: Opacity(
                            opacity: baseOpacity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: rectW,
                                  height: rectH,
                                  decoration: BoxDecoration(
                                    color: displayColor,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(color: displayColor.withOpacity(0.6), blurRadius: wacSize >= 100 ? 10 : 5, spreadRadius: wacSize >= 100 ? 2 : 1),
                                    ],
                                  ),
                                ),
                                if (slogan != null)
                                  Container(
                                    margin: const EdgeInsets.only(top: 1),
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      slogan,
                                      style: TextStyle(
                                        color: displayColor,
                                        fontSize: fontSize,
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ));
                    } else {
                      final double dotSize = LodManager.dotSizeAtZoom(zoom, wacSize);

                      markerDots.add(Marker(
                          point: offsetPoint,
                          width: dotSize + 6,
                          height: dotSize + 6,
                          child: Opacity(
                            opacity: baseOpacity,
                            child: Center(
                              child: Container(
                                width: dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  color: displayColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: displayColor.withOpacity(0.7), blurRadius: wacSize >= 100 ? 8 : 4, spreadRadius: wacSize >= 100 ? 2 : 1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ));
                    }
                  }
              }

              // ── Polygon layer ──
              // Always show selected polygons from BOTH layers at every zoom level.
              // In region-select mode: also show the active layer's unselected boundaries.
              final List<Polygon> polygonWidgets = [];
              final Set<String> _renderedSelected = {};

              if (_regionSelectMode && _isGeoJsonLoaded) {
                // 1) Active layer: show all polygons (selected = cyan, unselected = faint)
                // Render at multiple world offsets for seamless wrapping
                for (final cp in _activePolygons) {
                  final bool selected = cp.parentCountry != null
                      ? _isRegionSelected(cp.name, cp.parentCountry)
                      : _isCountrySelected(cp.name);
                  if (selected) {
                    _renderedSelected.add(cp.parentCountry != null
                        ? '${cp.name}|${cp.parentCountry}'
                        : 'country:${cp.name}');
                  }
                  polygonWidgets.addAll(_multiWorldPolygon(
                    cp,
                    selected ? Colors.cyan.withOpacity(0.35) : Colors.cyan.withOpacity(0.08),
                    selected ? Colors.cyanAccent : Colors.cyan.withOpacity(0.7),
                    selected ? 3.0 : 1.2,
                  ));
                }

                // 2) Also render selected items from the OTHER layer so they stay visible on zoom
                if (_currentZoom < 7 && _isAdmin1Loaded) {
                  for (final cp in _admin1Polygons) {
                    final key = '${cp.name}|${cp.parentCountry}';
                    if (_selectedRegions.contains(key) && !_renderedSelected.contains(key)) {
                      polygonWidgets.addAll(_multiWorldPolygon(
                        cp,
                        Colors.cyan.withOpacity(0.30),
                        Colors.cyanAccent.withOpacity(0.8),
                        2.0,
                      ));
                    }
                  }
                }
                if (_currentZoom >= 7 && _isCountriesLoaded) {
                  for (final cp in _countryPolygons) {
                    if (_isCountrySelected(cp.name) && !_renderedSelected.contains('country:${cp.name}')) {
                      polygonWidgets.addAll(_multiWorldPolygon(
                        cp,
                        Colors.cyan.withOpacity(0.25),
                        Colors.cyanAccent.withOpacity(0.7),
                        2.0,
                      ));
                    }
                  }
                }

                if (_isOceansLoaded) {
                  for (final cp in _oceanPolygons) {
                    final bool selected = _selectedOceans.contains(cp.name);
                    polygonWidgets.addAll(_multiWorldPolygon(
                      cp,
                      selected ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.05),
                      selected ? Colors.lightBlueAccent : Colors.blue.withOpacity(0.3),
                      selected ? 2.5 : 0.8,
                    ));
                  }
                }
              }

              // Calculate dynamic minZoom so world never shows twice
              final screenWidth = MediaQuery.of(context).size.width;
              final dynamicMinZoom = math.max(2.0, (math.log(screenWidth / 256) / math.ln2));

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: _currentZoom,
                  minZoom: dynamicMinZoom,
                  maxZoom: 18.0,
                  // Constrain latitude to Mercator bounds, longitude free for wrapping
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-85.0, -900.0),  // allow 2.5 extra worlds each side
                      const LatLng(85.0, 900.0),
                    ),
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (position.zoom != null) {
                      if (mounted) setState(() => _currentZoom = position.zoom!);
                    }
                    // Snap-back: when user scrolls beyond 2 worlds, snap to center
                    if (position.center != null && hasGesture) {
                      final lng = position.center!.longitude;
                      if (lng > 540 || lng < -540) {
                        final normalizedLng = ((lng + 180) % 360) - 180;
                        _mapController.move(
                          LatLng(position.center!.latitude, normalizedLng),
                          position.zoom ?? _currentZoom,
                        );
                      }
                    }
                  },
                  onTap: (tapPosition, point) {
                      // ── If region-select mode is on, handle region taps ──
                      if (_regionSelectMode && _isGeoJsonLoaded) {
                        _handleRegionTap(point);
                        return;
                      }

                      // ── Normal mode: icon hit detection ──
                      // Normalize tap point longitude for icon matching
                      final normalizedTapPoint = _normalizeLng(point);
                      // Use the DISPLAYED icons (paused or live)
                      final displayIcons = _paused ? _pausedSnapshot : icons;
                      for (var icon in displayIcons) {
                          final String userSlogan = icon.id.startsWith('mock')
                              ? 'Mock Token ${icon.id}'
                              : 'World exploration mode.';
                          final iconPoint = _offsetToLatLng(icon.position);
                          final dist = const Distance().as(LengthUnit.Kilometer, normalizedTapPoint, iconPoint);
                          final double tokenPower = icon.size > 1.0 ? (icon.size - 1.0) : 0.0;
                          // Tap radius = actual aura radius (10km per tokenPower) + 5km base for the dot
                          final auraRadiusKm = tokenPower * 10.0;
                          final touchRadiusKm = auraRadiusKm + 5.0; // 5km grace for the dot itself
                          if (dist < touchRadiusKm) {
                              _showPublicProfile(context, icon, userSlogan, displayIcons);
                              break;
                          }
                      }
                  }
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.wacting.app',
                  ),
                  const DayNightLayer(),
                  // Only show polygon overlay in region-select mode
                  if (polygonWidgets.isNotEmpty)
                    PolygonLayer(polygons: polygonWidgets),
                  CircleLayer(circles: circleAuras),
                  MarkerLayer(markers: markerDots),
                ],
              );
            }
          ),

          // ── Semantic Zoom Overlay ──
          Positioned(
            top: 40,
            left: MediaQuery.of(context).size.width / 2 - 100,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _regionSelectMode
                        ? Colors.orange.withOpacity(0.3)
                        : AppColors.accentBlue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _regionSelectMode
                          ? Colors.orangeAccent
                          : AppColors.accentBlue.withOpacity(0.5),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _regionSelectMode
                          ? (_zoomLevel == 'continents'
                              ? 'SELECT CONTINENTS'
                              : _zoomLevel == 'countries'
                                  ? 'SELECT COUNTRIES'
                                  : _zoomLevel == 'cities'
                                      ? 'SELECT CITIES'
                                      : 'SELECT REGIONS')
                          : (_currentZoom < 4
                              ? 'CONTINENTS'
                              : _currentZoom < 7
                                  ? 'COUNTRIES'
                                  : _currentZoom < 10
                                      ? 'REGIONS'
                                      : 'CITIES'),
                      style: TextStyle(
                        color: _regionSelectMode ? Colors.orangeAccent : AppColors.accentBlue,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Focus Button ──
          Positioned(
            bottom: 30,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'center_btn',
              backgroundColor: AppColors.navyPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.accentTeal, width: 2)
              ),
              child: Icon(Icons.center_focus_strong, color: AppColors.accentTeal),
              onPressed: () {
                final displayIcons = _paused ? _pausedSnapshot : (_lastIcons ?? []);
                if (displayIcons.isNotEmpty) {
                  final myIcon = displayIcons.first;
                  final focusZoom = LodManager.focusZoom(myIcon.size);
                  final latLng = _offsetToLatLng(myIcon.position);
                  _mapController.move(latLng, focusZoom);
                } else {
                  _mapController.move(_initialCenter, 4.0);
                }
                if (_paused) {
                  setState(() => _paused = false);
                }
              },
            ),
          ),

          // ── Pause/Resume Button ──
          Positioned(
            bottom: 30,
            left: 80,
            child: FloatingActionButton(
              heroTag: 'pause_btn',
              backgroundColor: _paused
                  ? Colors.amber.shade900
                  : AppColors.navyPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _paused ? AppColors.accentAmber : AppColors.accentTeal,
                  width: 2,
                ),
              ),
              child: Icon(
                _paused ? Icons.play_arrow : Icons.pause,
                color: _paused ? AppColors.accentAmber : AppColors.accentTeal,
              ),
              onPressed: () {
                setState(() => _paused = !_paused);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    _paused ? '⏸' : '▶',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: (_paused ? Colors.amber.shade800 : Colors.cyan).withOpacity(0.85),
                  duration: const Duration(milliseconds: 600),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height - 100,
                    left: MediaQuery.of(context).size.width / 2 - 28,
                    right: MediaQuery.of(context).size.width / 2 - 28,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ));
              },
            ),
          ),

          // ── Selection Badge (always visible when something is selected) ──
          if (_totalSelectionCount > 0)
            Positioned(
              top: 80,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: const BoxConstraints(maxWidth: 220),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentTeal, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Restricted (${_totalSelectionCount}):',
                        style: TextStyle(color: AppColors.accentTeal, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _selectionSummary,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          // ── Region Select Toggle Button ──
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton.extended(
              heroTag: 'region_toggle_btn',
              backgroundColor: _regionSelectMode
                  ? Colors.orange.shade900
                  : AppColors.navyPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _regionSelectMode ? Colors.orangeAccent : AppColors.accentTeal,
                  width: 2,
                ),
              ),
              icon: Icon(
                _regionSelectMode ? Icons.check_circle : Icons.map_outlined,
                color: Colors.white,
              ),
              label: Text(
                _regionSelectMode
                    ? 'DONE (${_totalSelectionCount})'
                    : 'SELECT REGIONS',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                if (!_regionSelectMode) {
                  // Entering region-select mode — lazy-load GeoJSON layers + auto-pause
                  await _ensureCountriesLoaded();
                  await _ensureAdmin1Loaded();
                  await _ensureOceansLoaded();
                  await _ensureCitiesLoaded();
                  setState(() {
                    _regionSelectMode = true;
                    _paused = true;  // Auto-pause icons for inspection
                  });
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                      '📍 Bölge seçimi AÇIK — haritaya dokunarak seçin.\n'
                      'Uzaklaş → kıta seç\n'
                      'Yaklaş → ülke/bölge seç\n'
                      '❘❘ İkonlar durduruldu',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ));
                } else {
                  // Exiting region-select mode — apply selections + auto-resume
                  setState(() {
                    _regionSelectMode = false;
                    _paused = false;  // Auto-resume icons
                  });
                  debugPrint('Applied region bounds: $_selectionSummary');
                  ScaffoldMessenger.of(context).clearSnackBars();
                  if (_totalSelectionCount > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        '✅ Seçim uygulandı: $_selectionSummary\n'
                        '▶ İkonlar devam ediyor',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.cyan,
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('▶ Bölge seçimi kapandı — ikonlar devam ediyor',
                        style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.cyan,
                      duration: Duration(seconds: 2),
                    ));
                  }
                }
              },
            ),
          ),

          // ── Map Filter Dropdown ──
          Positioned(
            top: 16,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _filterDropdownOpen = !_filterDropdownOpen),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.navyPrimary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentTeal, width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_list, color: AppColors.accentTeal, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _filterLabel(_mapFilter),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Icon(_filterDropdownOpen ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.accentTeal, size: 14),
                    ]),
                  ),
                ),
                if (_filterDropdownOpen)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navyPrimary.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _filterOption('all', 'Tum Kampanyalar', Icons.public),
                        _filterOption('nearby', 'Bolgemdekiler', Icons.near_me),
                        _filterOption('trending', 'Trend Kampanyalar', Icons.trending_up),
                        _filterOption('protested', 'Linclenenler', Icons.warning_amber),
                        _filterOption('newest', 'Yeni Kampanyalar', Icons.fiber_new),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'nearby': return 'Bolgemdekiler';
      case 'trending': return 'Trend';
      case 'protested': return 'Linclenenler';
      case 'newest': return 'Yeni';
      default: return 'Filtre';
    }
  }

  Widget _filterOption(String key, String label, IconData icon) {
    final selected = _mapFilter == key;
    return GestureDetector(
      onTap: () => setState(() {
        _mapFilter = key;
        _filterDropdownOpen = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected ? AppColors.accentTeal.withOpacity(0.15) : Colors.transparent,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? AppColors.accentTeal : Colors.white70, size: 14),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: selected ? AppColors.accentTeal : Colors.white70,
            fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
        ]),
      ),
    );
  }

  // ──────────────────────── PUBLIC PROFILE MODAL ────────────────────────

  void _showPublicProfile(BuildContext context, IconModel icon, String slogan, List<IconModel> allIcons) {
      double tokensToSend = 10.0;

      final double tokenPower = icon.size > 1.0 ? (icon.size - 1.0) : 0.0;
      final double influenceRadiusKm = (tokenPower * 100).clamp(10, 1500).toDouble();
      final iconPoint = _offsetToLatLng(icon.position);

      final nearbyUsers = allIcons.where((other) {
          if (other.id == icon.id) return false;
          final otherPoint = _offsetToLatLng(other.position);
          final dist = const Distance().as(LengthUnit.Kilometer, iconPoint, otherPoint);
          return dist <= influenceRadiusKm;
      }).toList();

      nearbyUsers.sort((a, b) => b.size.compareTo(a.size));

      showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surfaceWhite,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) {
              return StatefulBuilder(
                  builder: (ctx, setModalState) {
                      return Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(ctx).viewInsets.bottom,
                            top: 24, left: 24, right: 24
                          ),
                          child: SingleChildScrollView(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      CircleAvatar(
                                          radius: 40,
                                          backgroundColor: icon.color,
                                          child: const Icon(Icons.person, size: 40, color: Colors.white),
                                      ),
                                      const SizedBox(height: 16),
                                      Text('User: ${icon.id}',
                                          style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('"$slogan"',
                                          style: TextStyle(color: AppColors.accentTeal, fontSize: 16, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600),
                                          textAlign: TextAlign.center),

                                      if (nearbyUsers.isNotEmpty) ...[
                                          const SizedBox(height: 24),
                                          const Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text('Under Influence / Nearby',
                                                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                              height: 120,
                                              decoration: BoxDecoration(
                                                  color: AppColors.surfaceLight,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: AppColors.borderLight)
                                              ),
                                              child: ListView.builder(
                                                  itemCount: nearbyUsers.length,
                                                  padding: const EdgeInsets.all(8),
                                                  itemBuilder: (context, index) {
                                                      final nu = nearbyUsers[index];
                                                      final nuSlogan = nu.id.startsWith('mock')
                                                          ? 'Mock Token Billionaire'
                                                          : 'World domination imminent.';
                                                      return ListTile(
                                                          leading: CircleAvatar(radius: 12, backgroundColor: nu.color),
                                                          title: Text(nu.id, style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                                                          subtitle: Text('"$nuSlogan"', style: TextStyle(color: AppColors.textTertiary, fontSize: 10, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                          trailing: Text('${nu.size.toStringAsFixed(1)} Power', style: TextStyle(color: AppColors.accentTeal, fontSize: 10)),
                                                          dense: true,
                                                          contentPadding: EdgeInsets.zero,
                                                      );
                                                  }
                                              )
                                          )
                                      ],

                                      const SizedBox(height: 24),
                                      Divider(color: AppColors.borderLight),
                                      const SizedBox(height: 16),
                                      Text('Send Tokens with Follow Request',
                                          style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 8),
                                      Slider(
                                          value: tokensToSend, min: 0, max: 1000, divisions: 100,
                                          activeColor: AppColors.accentTeal,
                                          label: '${tokensToSend.toInt()} WAC',
                                          onChanged: (val) => setModalState(() => tokensToSend = val),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.accentTeal,
                                              minimumSize: const Size(double.infinity, 50),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                          ),
                                          onPressed: () {
                                              Navigator.pop(ctx);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Follow request sent with ${tokensToSend.toInt()} tokens!')));
                                          },
                                          child: Text('FOLLOW & SEND ${tokensToSend.toInt()} WAC',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(height: 24),
                                  ],
                              )
                          )
                      );
                  }
              );
          }
      );
  }
}

/// Internal helper: parsed polygon with name, continent, and optional parent country
class _CountryPolygon {
  final String name;
  final String? continent;
  final String? parentCountry;  // null for country-level, set for admin-1
  final List<LatLng> outerRing;
  final List<List<LatLng>> holes;

  _CountryPolygon({required this.name, this.continent, this.parentCountry, required this.outerRing, required this.holes});
}

class _CityPoint {
  final String name;
  final String country;
  final String continent;
  final LatLng point;
  final int population;

  _CityPoint({required this.name, required this.country, required this.continent, required this.point, required this.population});
}
