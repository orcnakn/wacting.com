import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/grid_state.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/services/socket_service.dart';
import '../../core/services/locale_service.dart';
import '../../core/services/api_service.dart';
import '../../core/config/app_config.dart';
import '../../core/models/icon_model.dart';
import '../../app/constants.dart';
import '../../app/theme.dart';
import 'day_night_layer.dart';
import 'lod_manager.dart';
import 'emergency_marker.dart';

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

Color _hexToColor(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.parse(hex, radix: 16));
}

// Global callback for navigating to a lat/lng on the map from other screens
typedef MapNavigateCallback = void Function(double lat, double lng, {double zoom});
MapNavigateCallback? globalMapNavigateTo;

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
  List<_CityPoint> _cityPoints = [];            // major cities
  final Set<String> _selectedCountries = {};    // individual country names
  final Set<String> _selectedContinents = {};   // whole-continent selections
  final Set<String> _excludedCountries = {};    // countries excluded from continent selection
  final Set<String> _selectedRegions = {};      // admin-1 regions ("state|country")
  final Set<String> _selectedCities = {};       // city names ("city|country")
  bool _isCountriesLoaded = false;
  bool _isAdmin1Loaded = false;
  bool _isCitiesLoaded = false;

  // ── Pause/Resume state ──
  bool _paused = false;
  List<IconModel> _pausedSnapshot = [];
  List<IconModel>? _lastIcons;

  // ── Map filter state ──
  String _mapFilter = 'all'; // all, protest, reform, support, emergency
  bool _filterDropdownOpen = false;

  // ── Active campaigns panel ──
  bool _campaignPanelOpen = false;
  List<dynamic> _activeCampaigns = [];
  bool _campaignsLoading = false;

  // ── User location pins ──
  List<Map<String, dynamic>> _userLocations = [];
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    socketService.connect(AppConfig.socketUrl);
    globalMapNavigateTo = (double lat, double lng, {double zoom = 8.0}) {
      _mapController.move(LatLng(lat, lng), zoom);
    };
    _fetchUserLocations();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchUserLocations());
    _loadSavedRegions();
  }

  Future<void> _loadSavedRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = apiService.userId ?? 'guest';
      if (mounted) {
        setState(() {
          _selectedContinents.addAll(prefs.getStringList('wacting_selectedContinents_$userId') ?? []);
          _selectedCountries.addAll(prefs.getStringList('wacting_selectedCountries_$userId') ?? []);
          _excludedCountries.addAll(prefs.getStringList('wacting_excludedCountries_$userId') ?? []);
          _selectedRegions.addAll(prefs.getStringList('wacting_selectedRegions_$userId') ?? []);
          _excludedRegions.addAll(prefs.getStringList('wacting_excludedRegions_$userId') ?? []);
          _selectedCities.addAll(prefs.getStringList('wacting_selectedCities_$userId') ?? []);
        });
      }
    } catch (e) {
      debugPrint("Failed to load saved regions: $e");
    }
  }

  Future<void> _saveRegionsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = apiService.userId ?? 'guest';
      await prefs.setStringList('wacting_selectedContinents_$userId', _selectedContinents.toList());
      await prefs.setStringList('wacting_selectedCountries_$userId', _selectedCountries.toList());
      await prefs.setStringList('wacting_excludedCountries_$userId', _excludedCountries.toList());
      await prefs.setStringList('wacting_selectedRegions_$userId', _selectedRegions.toList());
      await prefs.setStringList('wacting_excludedRegions_$userId', _excludedRegions.toList());
      await prefs.setStringList('wacting_selectedCities_$userId', _selectedCities.toList());
    } catch (e) {
      debugPrint("Failed to save regions: $e");
    }
  }

  Future<void> _fetchUserLocations() async {
    if (!apiService.isLoggedIn) return;
    try {
      final locations = await apiService.getUserLocations();
      if (mounted) {
        setState(() {
          _userLocations = locations.cast<Map<String, dynamic>>();
        });
      }
    } catch (_) {}
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
    _locationTimer?.cancel();
    socketService.dispose();
    super.dispose();
  }

  LatLng _offsetToLatLng(Offset pos) {
    double lng = (pos.dx / GridConstants.gridWidth) * 360 - 180;
    double lat = 90 - (pos.dy / GridConstants.gridHeight) * 180;
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

  /// Own icon dot size: always visible, slightly larger than other users
  double _myIconDotSize(double zoom) {
    if (zoom < 4) return 6.0;   // Continents: small but visible
    if (zoom < 7) return 8.0;   // Countries: medium dot
    return 10.0;                 // Regions: standard dot
  }

  // ── Excluded regions: regions removed from a selected country ──
  final Set<String> _excludedRegions = {};  // "region|country" keys

  // ── Check if a country polygon is selected (directly or via continent) ──
  bool _isCountrySelected(String countryName) {
    if (_excludedCountries.contains(countryName)) {
      // Even if excluded from continent, check if re-included via all regions
      // (not implemented — user can re-include individual regions instead)
      return false;
    }
    if (_selectedCountries.contains(countryName)) return true;
    final cont = _continentForCountry(countryName);
    if (cont != null && _selectedContinents.contains(cont)) return true;
    return false;
  }

  // Check if an admin-1 region is selected
  bool _isRegionSelected(String regionName, String? parentCountry) {
    final key = '$regionName|$parentCountry';
    // Explicitly excluded from a selected country?
    if (_excludedRegions.contains(key)) return false;
    // Explicitly selected?
    if (_selectedRegions.contains(key)) return true;
    // Parent country is selected → region is implicitly selected
    if (parentCountry != null && _isCountrySelected(parentCountry)) return true;
    return false;
  }

  // Check if a city is selected
  bool _isCitySelected(String cityName, String? country) {
    final key = '$cityName|$country';
    if (_selectedCities.contains(key)) return true;
    // Implicitly selected if parent country or a region covering it is selected
    // (cities are always explicit for now)
    return false;
  }

  // ── World offsets for multi-copy rendering ──
  static const List<double> _worldOffsets = [0];

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
  // Smart hierarchical selection:
  //   Continent tap: toggle entire continent. If already selected, deselect all.
  //                  If not selected, select it (absorbs individual country selections).
  //   Country tap:   If country is part of selected continent → exclude just this country.
  //                  If country is excluded from continent → re-include it.
  //                  If country is individually selected → deselect it.
  //                  Otherwise → select it individually.
  //   Region tap:    If region's parent country is selected → exclude just this region.
  //                  If region is excluded → re-include it.
  //                  If region is individually selected → deselect it.
  //                  If parent country is excluded from continent → re-include this region.
  //                  Otherwise → select region individually.
  //   City tap:      Toggle city selection (always explicit).
  void _handleRegionTap(LatLng rawPoint) {
    final point = _normalizeLng(rawPoint);
    final level = _zoomLevel;

    if (level == 'continents') {
      final country = _findCountryAtPoint(point);
      if (country == null) return;
      final continent = _continentForCountry(country);
      if (continent == null) return;
      final members = _continentCountries[continent] ?? [];

      setState(() {
        if (_selectedContinents.contains(continent)) {
          // Deselect entire continent
          _selectedContinents.remove(continent);
          _selectedCountries.removeAll(members);
          _excludedCountries.removeAll(members);
          // Also clean up regions/cities for these countries
          _selectedRegions.removeWhere((r) {
            final parts = r.split('|');
            return parts.length >= 2 && members.contains(parts[1]);
          });
          _excludedRegions.removeWhere((r) {
            final parts = r.split('|');
            return parts.length >= 2 && members.contains(parts[1]);
          });
        } else {
          // Select entire continent — absorb individual country selections
          _selectedContinents.add(continent);
          _selectedCountries.removeAll(members);
          _excludedCountries.removeAll(members);
          _excludedRegions.removeWhere((r) {
            final parts = r.split('|');
            return parts.length >= 2 && members.contains(parts[1]);
          });
        }
      });
      _showSelectionSnackbar('$continent');
    } else if (level == 'countries') {
      final country = _findCountryAtPoint(point);
      if (country == null) return;

      final cont = _continentForCountry(country);
      final isViaContinent = cont != null && _selectedContinents.contains(cont);

      setState(() {
        if (_excludedCountries.contains(country)) {
          // Re-include: was excluded from continent selection
          _excludedCountries.remove(country);
          // Clean up any region-level re-inclusions for this country
          _selectedRegions.removeWhere((r) {
            final parts = r.split('|');
            return parts.length >= 2 && parts[1] == country;
          });
          _showSelectionSnackbar('$country (tekrar dahil)');
          return;
        } else if (isViaContinent) {
          // Exclude from continent: only this country removed
          _excludedCountries.add(country);
          _showSelectionSnackbar('$country (cikarildi)');
          return;
        } else if (_selectedCountries.contains(country)) {
          // Deselect individual country
          _selectedCountries.remove(country);
          _selectedRegions.removeWhere((r) {
            final parts = r.split('|');
            return parts.length >= 2 && parts[1] == country;
          });
          _excludedRegions.removeWhere((r) {
            final parts = r.split('|');
            return parts.length >= 2 && parts[1] == country;
          });
        } else {
          // Select individual country
          _selectedCountries.add(country);
        }
      });
      _showSelectionSnackbar(country);
    } else if (level == 'cities') {
      final country = _findCountryAtPoint(point);
      if (country != null) {
        // Try city first
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
        // Fallback: region
        if (_isAdmin1Loaded) {
          _handleRegionToggle(point, country);
        }
      }
    } else {
      // Regions zoom — admin-1 state/province
      final country = _findCountryAtPoint(point);
      if (country != null) {
        if (_isAdmin1Loaded) {
          final handled = _handleRegionToggle(point, country);
          if (handled) return;
        }
        // Fallback: country-level
        setState(() {
          if (_selectedCountries.contains(country)) {
            _selectedCountries.remove(country);
          } else {
            _selectedCountries.add(country);
          }
        });
        _showSelectionSnackbar(country);
      }
    }
  }

  /// Toggle a region within a country. Returns true if a region was found.
  bool _handleRegionToggle(LatLng point, String country) {
    final region = _findAdmin1AtPoint(point);
    if (region == null) return false;

    final key = '${region.name}|${region.parentCountry}';
    final parentCountry = region.parentCountry;
    final parentSelected = parentCountry != null && _isCountrySelected(parentCountry);
    final parentExcluded = parentCountry != null && _excludedCountries.contains(parentCountry);

    setState(() {
      if (_excludedRegions.contains(key)) {
        // Re-include excluded region
        _excludedRegions.remove(key);
      } else if (_selectedRegions.contains(key)) {
        // Deselect explicitly selected region
        _selectedRegions.remove(key);
      } else if (parentSelected) {
        // Parent country is selected → exclude just this region
        _excludedRegions.add(key);
      } else if (parentExcluded) {
        // Parent country is excluded from continent → re-include this region
        _selectedRegions.add(key);
      } else {
        // No parent selected → select region individually
        _selectedRegions.add(key);
      }
    });

    final isExcluded = _excludedRegions.contains(key);
    final isSelected = _selectedRegions.contains(key) || (parentSelected && !isExcluded);
    _showSelectionSnackbar(isExcluded
        ? '${region.name} (cikarildi)'
        : isSelected
            ? '${region.name}'
            : '${region.name} (kaldirildi)');
    return true;
  }

  void _showSelectionSnackbar(String label) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label | $_totalSelectionCount',
          style: const TextStyle(color: Colors.white, fontSize: 11),
          textAlign: TextAlign.center),
      backgroundColor: AppColors.accentBlue.withOpacity(0.9),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(
        bottom: 20,
        left: MediaQuery.of(context).size.width * 0.25,
        right: MediaQuery.of(context).size.width * 0.25,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      final excRegions = _excludedRegions.where((r) {
        final split = r.split('|');
        return split.length >= 2 && split[1] == c;
      }).toList();
      if (excRegions.isEmpty) {
        parts.add(c);
      } else {
        final excStr = excRegions.map((r) => r.split('|')[0]).join(', ');
        parts.add('$c ($excStr haric)');
      }
    }
    for (final r in _selectedRegions) {
      final split = r.split('|');
      final parent = split.length >= 2 ? split[1] : null;
      if (parent != null && _isCountrySelected(parent)) continue;
      if (parent != null && _excludedCountries.contains(parent)) continue;
      parts.add('${split[0]}${parent != null ? ' ($parent)' : ''}');
    }
    for (final c in _selectedCities) {
      final split = c.split('|');
      final city = split[0];
      final country = split.length >= 2 ? split[1] : null;
      parts.add('$city${country != null ? ' ($country)' : ''}');
    }
    return parts.isEmpty ? 'Seçim yok' : parts.join(', ');
  }

  int get _totalSelectionCount {
    final all = <String>{..._selectedCountries};
    for (final c in _selectedContinents) {
      all.addAll(_continentCountries[c] ?? []);
    }
    all.removeAll(_excludedCountries);
    return all.length + _selectedRegions.length + _selectedCities.length - _excludedRegions.length;
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

              final zoom = _currentZoom;

              // Apply campaign type filter
              final filteredIcons = _mapFilter == 'all'
                  ? icons
                  : icons.where((icon) {
                      final stance = icon.stanceType?.toUpperCase();
                      if (stance == null) return true; // Non-campaign icons always visible
                      switch (_mapFilter) {
                        case 'protest': return stance == 'PROTEST';
                        case 'reform': return stance == 'REFORM';
                        case 'support': return stance == 'SUPPORT';
                        case 'emergency': return stance == 'EMERGENCY';
                        default: return true;
                      }
                    }).toList();

              // Emergency campaign markers (now filtered like all others)
              final emergencyMarkers = <Marker>[];
              for (final icon in filteredIcons) {
                if (icon.isEmergency) {
                  final latLng = _offsetToLatLng(icon.position);
                  final double logoSize = (math.sqrt(icon.emergencyAreaM2) / 10).clamp(12.0, 60.0);
                  final double markerSize = logoSize * 3;
                  emergencyMarkers.add(Marker(
                    point: latLng,
                    width: markerSize,
                    height: markerSize,
                    child: EmergencyMarker(
                      color: Colors.red,
                      areaM2: icon.emergencyAreaM2,
                      slogan: icon.campaignSlogan,
                      onTap: () {
                        if (icon.campaignId != null) {
                          _showCampaignDetail(context, icon.campaignId!);
                        } else {
                          final userSlogan = icon.campaignSlogan ?? t('emergency_default');
                          _showPublicProfile(context, icon, userSlogan);
                        }
                      },
                    ),
                  ));
                }
              }

              final markerDots = <Marker>[];
              final myId = apiService.userId;
              for (final icon in filteredIcons) {
                if (icon.isEmergency) continue; // Skip — rendered in emergency layer
                  final latLng = _offsetToLatLng(icon.position);
                  final Color displayColor = icon.displayColor;
                  final double wacSize = icon.size;
                  final bool isCampaignIcon = icon.campaignSlogan != null;
                  final bool isMyIcon = icon.userId == myId;

                  // User icons (no campaign): small dots, person icon at cities zoom
                  if (!isCampaignIcon && !isMyIcon) {
                    if (!LodManager.shouldRenderUser(zoom, false)) continue;
                    final double userOpacity = LodManager.userOpacity(zoom, false);
                    final double dotSize = LodManager.userDotSize(zoom);

                    for (final worldOffset in _worldOffsets) {
                      final offsetPoint = LatLng(latLng.latitude, latLng.longitude + worldOffset);

                      if (LodManager.isUserFullDetail(zoom)) {
                        // Cities zoom: person icon
                        markerDots.add(Marker(
                          point: offsetPoint,
                          width: 22,
                          height: 22,
                          child: Opacity(
                            opacity: userOpacity,
                            child: Container(
                              decoration: BoxDecoration(
                                color: displayColor.withOpacity(0.8),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(Icons.person, color: Colors.white, size: 13),
                            ),
                          ),
                        ));
                      } else {
                        // Below cities: colored dot
                        markerDots.add(Marker(
                          point: offsetPoint,
                          width: dotSize + 4,
                          height: dotSize + 4,
                          child: Opacity(
                            opacity: userOpacity,
                            child: Center(
                              child: Container(
                                width: dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  color: displayColor,
                                  shape: BoxShape.circle,
                                  border: dotSize > 3 ? Border.all(color: Colors.white, width: 0.5) : null,
                                ),
                              ),
                            ),
                          ),
                        ));
                      }
                    }
                    continue;
                  }

                  // Own icon (no campaign): always visible, personal size
                  if (!isCampaignIcon && isMyIcon) {
                    final double myOpacity = 1.0;
                    final double dotSize = zoom >= 10 ? LodManager.dotSizeAtZoom(zoom, wacSize) : _myIconDotSize(zoom);

                    for (final worldOffset in _worldOffsets) {
                      final offsetPoint = LatLng(latLng.latitude, latLng.longitude + worldOffset);

                      if (zoom >= 13.0) {
                        // Full detail at high zoom
                        final double rectW = LodManager.rectWidth(wacSize.clamp(1, 100), zoom);
                        final double rectH = LodManager.rectHeight(wacSize.clamp(1, 100), zoom);
                        markerDots.add(Marker(
                            point: offsetPoint,
                            width: rectW + 4,
                            height: rectH + 4,
                            child: Opacity(
                              opacity: myOpacity,
                              child: Container(
                                width: rectW,
                                height: rectH,
                                decoration: BoxDecoration(
                                  color: displayColor,
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                              ),
                            ),
                        ));
                      } else {
                        markerDots.add(Marker(
                            point: offsetPoint,
                            width: dotSize + 6,
                            height: dotSize + 6,
                            child: Opacity(
                              opacity: myOpacity,
                              child: Center(
                                child: Container(
                                  width: dotSize,
                                  height: dotSize,
                                  decoration: BoxDecoration(
                                    color: displayColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                        ));
                      }
                    }
                    continue;
                  }

                  // Campaign icons: existing LOD behavior
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
                                    border: Border.all(color: Colors.white, width: 1),
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
                                  border: Border.all(color: Colors.white, width: 1),
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
                    if (_selectedRegions.contains(key) && !_excludedRegions.contains(key) && !_renderedSelected.contains(key)) {
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

              }

              // minZoom: at max zoom-out exactly 1 world fills the screen.
              final screenWidth = MediaQuery.of(context).size.width;
              // At zoom z, one world = 256 * 2^z px. Solve: 256 * 2^z = screenWidth
              final dynamicMinZoom = (math.log(screenWidth / 256) / math.ln2);

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: _currentZoom,
                  minZoom: dynamicMinZoom,
                  maxZoom: 18.0,
                  // Single world: constrain to standard bounds
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-85.0, -180.0),
                      const LatLng(85.0, 180.0),
                    ),
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (position.zoom != null) {
                      final oldZoom = _currentZoom;
                      final newZoom = position.zoom!;
                      if (mounted) {
                        setState(() => _currentZoom = newZoom);
                        // Auto-pause when entering regions level (zoom >= 7), auto-resume when leaving
                        if (!_regionSelectMode) {
                          if (oldZoom < 7 && newZoom >= 7 && !_paused) {
                            setState(() => _paused = true);
                          } else if (oldZoom >= 7 && newZoom < 7 && _paused) {
                            setState(() => _paused = false);
                          }
                        }
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
                          final iconPoint = _offsetToLatLng(icon.position);
                          final dist = const Distance().as(LengthUnit.Kilometer, normalizedTapPoint, iconPoint);
                          final touchRadiusKm = 20.0;
                          if (dist < touchRadiusKm) {
                              if (icon.campaignId != null) {
                                _showCampaignDetail(context, icon.campaignId!);
                              } else {
                                final String userSlogan = icon.id.startsWith('mock')
                                    ? 'Mock Token ${icon.id}'
                                    : 'World exploration mode.';
                                _showPublicProfile(context, icon, userSlogan);
                              }
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
                  MarkerLayer(markers: markerDots),
                  // ── User location pins (all users as colored dots, zoom-aware) ──
                  if (_userLocations.isNotEmpty && LodManager.shouldRenderUser(zoom, false))
                    MarkerLayer(
                      markers: _userLocations.map((loc) {
                        final lat = (loc['lat'] as num).toDouble();
                        final lng = (loc['lng'] as num).toDouble();
                        final name = loc['displayName'] ?? '';
                        final color = _hexToColor(loc['colorHex'] ?? '#FFFFFF');
                        final isOwn = loc['userId'] == apiService.userId;
                        final dotSize = isOwn ? LodManager.userDotSize(zoom) + 4 : LodManager.userDotSize(zoom);
                        final opacity = LodManager.userOpacity(zoom, isOwn);

                        if (LodManager.isUserFullDetail(zoom)) {
                          // High zoom: show person icon with name
                          return Marker(
                            point: LatLng(lat, lng),
                            width: 28,
                            height: 28,
                            child: Opacity(
                              opacity: opacity,
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(name.isNotEmpty ? name : 'Kullanici'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          );
                        }

                        // Low/mid zoom: colored dot
                        return Marker(
                          point: LatLng(lat, lng),
                          width: dotSize + 4,
                          height: dotSize + 4,
                          child: Opacity(
                            opacity: opacity,
                            child: Center(
                              child: Container(
                                width: dotSize,
                                height: dotSize,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: dotSize > 4 ? Border.all(color: Colors.white, width: 0.5) : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  // ── Emergency campaign icons ──
                  if (emergencyMarkers.isNotEmpty)
                    MarkerLayer(markers: emergencyMarkers),
                ],
              );
            }
          ),

          // ── Semantic Zoom Overlay ──
          Positioned(
            top: 40,
            left: MediaQuery.of(context).size.width / 2 - 80,
            child: IgnorePointer(
              child: Container(
                width: 160,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: _regionSelectMode
                      ? Colors.orange.withOpacity(0.25)
                      : AppColors.accentBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _regionSelectMode
                        ? Colors.orangeAccent.withOpacity(0.6)
                        : AppColors.accentBlue.withOpacity(0.3),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Focus Button (tap: go to my icon at cities zoom) ──
          Positioned(
            bottom: 30,
            left: 20,
            child: SizedBox(
              width: 40,
              height: 40,
              child: FloatingActionButton(
              heroTag: 'center_btn',
              backgroundColor: AppColors.navyPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppColors.accentTeal, width: 1.5)
              ),
              child: Icon(Icons.center_focus_strong, color: AppColors.accentTeal, size: 18),
              onPressed: () {
                final myId = apiService.userId;
                if (myId != null && _lastIcons != null) {
                  final myIcon = _lastIcons!.cast<IconModel?>().firstWhere(
                    (ic) => ic!.userId == myId, orElse: () => null);
                  if (myIcon != null) {
                    final pos = _offsetToLatLng(myIcon.position);
                    _mapController.move(pos, 11.0);
                    return;
                  }
                }
                _mapController.move(_initialCenter, 11.0);
              },
            )),
          ),

          // ── Pause/Resume Button ──
          Positioned(
            bottom: 30,
            left: 70,
            child: SizedBox(
              width: 40,
              height: 40,
              child: FloatingActionButton(
              heroTag: 'pause_btn',
              backgroundColor: _paused
                  ? Colors.amber.shade900
                  : AppColors.navyPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _paused ? AppColors.accentAmber : AppColors.accentTeal,
                  width: 1.5,
                ),
              ),
              child: Icon(
                _paused ? Icons.play_arrow : Icons.pause,
                color: _paused ? AppColors.accentAmber : AppColors.accentTeal,
                size: 18,
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
            )),
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
            child: SizedBox(
              width: 40,
              height: 40,
              child: FloatingActionButton(
              heroTag: 'region_toggle_btn',
              backgroundColor: _regionSelectMode
                  ? Colors.orange.shade900
                  : AppColors.navyPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: _regionSelectMode ? Colors.orangeAccent : AppColors.accentTeal,
                  width: 1.5,
                ),
              ),
              child: Icon(
                _regionSelectMode ? Icons.check_circle : Icons.map_outlined,
                color: _regionSelectMode ? Colors.orangeAccent : AppColors.accentTeal,
                size: 18,
              ),
              onPressed: () async {
                if (!_regionSelectMode) {
                  // Entering region-select mode — lazy-load GeoJSON layers + auto-pause
                  await _ensureCountriesLoaded();
                  await _ensureAdmin1Loaded();
                  await _ensureCitiesLoaded();
                  setState(() {
                    _regionSelectMode = true;
                    _paused = true;  // Auto-pause icons for inspection
                  });
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text(
                      'Bolge secimi ACIK — haritaya dokunun',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: EdgeInsets.only(
                      bottom: 20,
                      left: MediaQuery.of(context).size.width * 0.2,
                      right: MediaQuery.of(context).size.width * 0.2,
                    ),
                  ));
                } else {
                  // Exiting region-select mode — apply selections + send to server
                  final continents = _selectedContinents.toList();
                  final countries = <String>[
                    ..._selectedCountries,
                  ];
                  // Remove excluded countries
                  countries.removeWhere((c) => _excludedCountries.contains(c));
                  // Add countries from continents (minus excluded)
                  for (final cont in continents) {
                    final members = _continentCountries[cont] ?? [];
                    for (final m in members) {
                      if (!_excludedCountries.contains(m) && !countries.contains(m)) {
                        countries.add(m);
                      }
                    }
                  }
                  final cities = _selectedCities.map((c) => c.split('|')[0]).toList();

                  setState(() {
                    _regionSelectMode = false;
                    _paused = _currentZoom >= 7;  // Stay paused if in regions level
                  });

                  // Send to server
                  try {
                    await apiService.restrictBounds(
                      continents: continents,
                      countries: countries,
                      cities: cities,
                    );
                    await _saveRegionsToPrefs();
                  } catch (e) {
                    debugPrint('Failed to send restrictions: $e');
                  }

                  ScaffoldMessenger.of(context).clearSnackBars();
                  if (_totalSelectionCount > 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        'Secim uygulandi: $_selectionSummary',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      backgroundColor: Colors.cyan,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Bolge secimi kapandi',
                        style: TextStyle(color: Colors.white, fontSize: 11)),
                      backgroundColor: Colors.cyan,
                      duration: Duration(seconds: 2),
                    ));
                  }
                }
              },
            )),
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
                        _filterOption('all', t('filter_all_campaigns'), Icons.public, AppColors.accentTeal),
                        _filterOption('protest', t('filter_protest'), Icons.warning_amber, AppColors.accentAmber),
                        _filterOption('reform', t('filter_reform'), Icons.build_circle, AppColors.accentBlue),
                        _filterOption('support', t('filter_support'), Icons.favorite, AppColors.accentGreen),
                        _filterOption('emergency', t('filter_emergency'), Icons.emergency, AppColors.accentRed),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // ── Active Campaigns Panel ──
          Positioned(
            top: (MediaQuery.of(context).size.height - 70) / 2 - 14,
            left: 16,
            child: GestureDetector(
              onTap: () async {
                if (!_campaignPanelOpen) {
                  setState(() { _campaignPanelOpen = true; _campaignsLoading = true; });
                  try {
                    final all = await apiService.getMyCampaigns();
                    final campaigns = all.where((c) => c['isActive'] == true).toList();
                    if (mounted) setState(() { _activeCampaigns = campaigns; _campaignsLoading = false; });
                  } catch (_) {
                    if (mounted) setState(() { _campaignsLoading = false; });
                  }
                } else {
                  setState(() => _campaignPanelOpen = false);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.navyPrimary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentAmber, width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.flag, color: AppColors.accentAmber, size: 14),
                      const SizedBox(width: 6),
                      Text('Aktif Kampanyalar',
                        style: TextStyle(color: AppColors.accentAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Icon(_campaignPanelOpen ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.accentAmber, size: 14),
                    ]),
                  ),
                  if (_campaignPanelOpen)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 220,
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        color: AppColors.navyPrimary.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.accentAmber.withOpacity(0.5), width: 0.5),
                      ),
                      child: _campaignsLoading
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))),
                          )
                        : _activeCampaigns.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Aktif kampanya yok', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: _activeCampaigns.length,
                              itemBuilder: (_, i) {
                                final c = _activeCampaigns[i] as Map<String, dynamic>;
                                final title = c['title'] ?? 'Kampanya';
                                final slogan = c['slogan'] ?? '';
                                final colorHex = c['iconColor'] as String?;
                                final dotColor = (colorHex != null && colorHex.startsWith('#') && colorHex.length == 7)
                                    ? _hexToColor(colorHex)
                                    : AppColors.accentAmber;
                                final pLat = (c['pinnedLat'] as num?)?.toDouble();
                                final pLng = (c['pinnedLng'] as num?)?.toDouble();
                                final campaignId = c['id'] as String?;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _campaignPanelOpen = false);
                                    if (pLat != null && pLng != null) {
                                      _mapController.move(LatLng(pLat, pLng), 11.0);
                                    } else {
                                      final match = _lastIcons?.cast<IconModel?>().firstWhere(
                                        (ic) => ic!.campaignSlogan == slogan && slogan.isNotEmpty,
                                        orElse: () => null);
                                      if (match != null) {
                                        _mapController.move(_offsetToLatLng(match.position), 11.0);
                                      }
                                    }
                                    if (campaignId != null) {
                                      _showCampaignDetail(context, campaignId);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(children: [
                                      Container(width: 6, height: 6,
                                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                                      const SizedBox(width: 8),
                                      Expanded(child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                          if (slogan.isNotEmpty)
                                            Text(slogan, style: const TextStyle(color: Colors.white54, fontSize: 9),
                                              maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      )),
                                    ]),
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'protest': return t('filter_protest');
      case 'reform': return t('filter_reform');
      case 'support': return t('filter_support');
      case 'emergency': return t('filter_emergency');
      default: return t('filter_all_campaigns');
    }
  }

  Widget _filterOption(String key, String label, IconData icon, Color activeColor) {
    final selected = _mapFilter == key;
    return GestureDetector(
      onTap: () => setState(() {
        _mapFilter = key;
        _filterDropdownOpen = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected ? activeColor.withOpacity(0.15) : Colors.transparent,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? activeColor : Colors.white70, size: 14),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: selected ? activeColor : Colors.white70,
            fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
        ]),
      ),
    );
  }

  // ──────────────────────── CAMPAIGN DETAIL MODAL ────────────────────────

  void _showCampaignDetail(BuildContext context, String campaignId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: apiService.getCampaign(campaignId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator(color: AppColors.accentTeal)),
              );
            }
            if (snapshot.hasError || snapshot.data == null || snapshot.data!['campaign'] == null) {
              return SizedBox(
                height: 200,
                child: Center(child: Text(t('campaign_error'), style: TextStyle(color: AppColors.textTertiary))),
              );
            }

            final c = snapshot.data!['campaign'] as Map<String, dynamic>;
            final title = (c['title'] ?? '') as String;
            final slogan = (c['slogan'] ?? '') as String;
            final stanceType = (c['stanceType'] ?? 'SUPPORT') as String;
            final iconColor = (c['iconColor'] ?? '#2196F3') as String;
            final leaderData = c['leader'] as Map<String, dynamic>?;
            final leaderName = leaderData?['slogan'] ?? 'Unknown';
            final memberCount = c['_count']?['members'] ?? 0;
            final totalWac = double.tryParse((c['totalWacStaked'] ?? '0').toString()) ?? 0;
            final racPool = c['racPool'];
            final totalRac = racPool != null ? (racPool['totalBalance'] ?? 0).toDouble() : 0.0;

            // Parse campaign color
            Color campColor = AppColors.accentBlue;
            if (iconColor.startsWith('#') && iconColor.length == 7) {
              campColor = Color(int.parse('FF${iconColor.substring(1)}', radix: 16));
            }

            // Stance label & color
            final stanceLabel = {
              'PROTEST': t('filter_protest'),
              'REFORM': t('filter_reform'),
              'SUPPORT': t('filter_support'),
              'EMERGENCY': t('filter_emergency'),
            }[stanceType] ?? stanceType;

            final stanceColor = {
              'PROTEST': AppColors.accentAmber,
              'REFORM': AppColors.accentBlue,
              'SUPPORT': AppColors.accentGreen,
              'EMERGENCY': AppColors.accentRed,
            }[stanceType] ?? AppColors.accentBlue;

            return Padding(
              padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campaign logo circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: campColor,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: campColor.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)],
                    ),
                    child: Icon(
                      stanceType == 'EMERGENCY' ? Icons.emergency
                          : stanceType == 'PROTEST' ? Icons.warning_amber
                          : stanceType == 'REFORM' ? Icons.build_circle
                          : Icons.favorite,
                      color: Colors.white, size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(title,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Slogan
                  Text('"$slogan"',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 13, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Stance badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: stanceColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: stanceColor.withOpacity(0.4)),
                    ),
                    child: Text(stanceLabel,
                      style: TextStyle(color: stanceColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 20),
                  Divider(color: AppColors.borderLight),
                  const SizedBox(height: 12),

                  // Stats grid
                  Row(
                    children: [
                      _campaignStat(Icons.person, t('campaign_leader'), '$leaderName', AppColors.accentTeal),
                      _campaignStat(Icons.group, t('campaign_members'), '$memberCount', AppColors.accentBlue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _campaignStat(Icons.monetization_on, t('campaign_total_wac'), totalWac.toStringAsFixed(2), AppColors.accentAmber),
                      _campaignStat(Icons.shield, t('campaign_total_rac'), totalRac.toStringAsFixed(2), AppColors.accentRed),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _campaignStat(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
              style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── PUBLIC PROFILE MODAL ────────────────────────

  void _showPublicProfile(BuildContext context, IconModel icon, String slogan) {
      double tokensToSend = 10.0;

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

  // ── Campaign location picker popup ─────────────────────────────────────────
  void _showCampaignLocationPicker() async {
    List<dynamic> campaigns = [];
    try {
      campaigns = await apiService.getMyCampaigns();
    } catch (_) {}

    if (campaigns.isEmpty) {
      // No campaigns — just center on initial position
      _mapController.move(_initialCenter, 4.0);
      return;
    }

    if (!mounted) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    // Show popup above the focus button
    showDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) => Stack(
        children: [
          Positioned(
            bottom: 100,
            left: 20,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280,
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: AppColors.navyPrimary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentTeal, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.accentTeal.withOpacity(0.3))),
                      ),
                      child: Row(children: [
                        Icon(Icons.flag, color: AppColors.accentTeal, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Kampanyalar (${campaigns.length})',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Icon(Icons.close, color: AppColors.textTertiary, size: 18),
                        ),
                      ]),
                    ),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: campaigns.length,
                        itemBuilder: (_, i) {
                          final c = campaigns[i] as Map<String, dynamic>;
                          final title = c['title'] ?? 'Kampanya';
                          final slogan = c['slogan'] ?? '';
                          final pLat = (c['pinnedLat'] as num?)?.toDouble();
                          final pLng = (c['pinnedLng'] as num?)?.toDouble();
                          final hasLocation = pLat != null && pLng != null;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              if (hasLocation) {
                                _mapController.move(LatLng(pLat, pLng), 8.0);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('$title icin konum belirlenmemis'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: hasLocation ? AppColors.accentTeal : AppColors.textTertiary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (slogan.isNotEmpty)
                                        Text(slogan, style: TextStyle(color: AppColors.textTertiary, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Icon(
                                  hasLocation ? Icons.my_location : Icons.location_off,
                                  color: hasLocation ? AppColors.accentTeal : AppColors.textTertiary,
                                  size: 16,
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
