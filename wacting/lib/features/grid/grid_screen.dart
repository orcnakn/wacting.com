import 'dart:async';
import 'dart:convert';
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
  final Set<String> _selectedCountries = {};    // individual country names
  final Set<String> _selectedContinents = {};   // whole-continent selections
  final Set<String> _excludedCountries = {};    // countries excluded from continent selection
  final Set<String> _selectedRegions = {};      // admin-1 regions ("state|country")
  bool _isCountriesLoaded = false;
  bool _isAdmin1Loaded = false;

  // ── Pause/Resume state ──
  bool _paused = false;
  List<IconModel> _pausedSnapshot = [];  // frozen icons when paused

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
    return LatLng(lat, lng);
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
        // Check holes — if point is inside a hole, skip this polygon
        bool inHole = false;
        for (final hole in cp.holes) {
          if (_pointInPolygon(point, hole)) { inHole = true; break; }
        }
        if (!inHole) {
          debugPrint('🗺️ Found country: ${cp.name} at ${point.latitude}, ${point.longitude}');
          return cp.name;
        }
      }
    }
    debugPrint('❌ No country found at ${point.latitude}, ${point.longitude}');
    return null;
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
    return 'regions';  // admin-1 states/provinces
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

  // ── Handle tap in region-select mode ──
  void _handleRegionTap(LatLng point) {
    final level = _zoomLevel;

    if (level == 'continents') {
      final country = _findCountryAtPoint(point);
      if (country == null) return;
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
      if (country == null) return;

      final cont = _continentForCountry(country);
      final isViaContinent = cont != null && _selectedContinents.contains(cont);

      setState(() {
        if (_excludedCountries.contains(country)) {
          // Re-include: remove from exclusions
          _excludedCountries.remove(country);
        } else if (isViaContinent) {
          // Country is selected via continent → exclude it
          _excludedCountries.add(country);
        } else if (_selectedCountries.contains(country)) {
          // Directly selected → remove
          _selectedCountries.remove(country);
        } else {
          // Not selected → add directly
          _selectedCountries.add(country);
        }
      });
      final excluded = _excludedCountries.contains(country);
      _showSelectionSnackbar(excluded ? '❌ $country (çıkarıldı)' : '🗺️ $country');
    } else {
      // Regions zoom (≥7) — select admin-1 state/province
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
          _showSelectionSnackbar('🏙️ ${region.name} (${region.parentCountry})');
          return;
        }
      }
      // Fallback: use country-level selection
      final country = _findCountryAtPoint(point);
      if (country == null) return;
      setState(() {
        if (_selectedCountries.contains(country)) {
          _selectedCountries.remove(country);
        } else {
          _selectedCountries.add(country);
        }
      });
      _showSelectionSnackbar('🗺️ $country');
    }
  }

  void _showSelectionSnackbar(String label) {
    final allSelected = <String>{..._selectedCountries};
    for (final cont in _selectedContinents) {
      allSelected.addAll(_continentCountries[cont] ?? []);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Toggled: $label\nTotal regions: ${allSelected.length}'),
      backgroundColor: AppColors.accentBlue,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Summary of all selected regions ──
  String get _selectionSummary {
    final parts = <String>[];
    for (final c in _selectedContinents) {
      parts.add('$c (all)');
    }
    for (final c in _selectedCountries) {
      final cont = _continentForCountry(c);
      if (cont != null && _selectedContinents.contains(cont)) continue;
      parts.add(c);
    }
    for (final r in _selectedRegions) {
      final split = r.split('|');
      parts.add('${split[0]} (${split[1]})');
    }
    return parts.join(', ');
  }

  int get _totalSelectionCount {
    final all = <String>{..._selectedCountries};
    for (final c in _selectedContinents) {
      all.addAll(_continentCountries[c] ?? []);
    }
    all.removeAll(_excludedCountries);
    return all.length + _selectedRegions.length;
  }

  // Active polygons based on zoom level
  bool get _isGeoJsonLoaded => _isCountriesLoaded;
  List<_CountryPolygon> get _activePolygons {
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

              // When paused, keep using the frozen snapshot; when live, use stream data
              // Also update the snapshot whenever we get new data (so resume shows latest)
              if (!_paused) {
                _pausedSnapshot = liveIcons;
              }
              final icons = _paused ? _pausedSnapshot : liveIcons;

              // Sort Auras so large ones don't cover small ones
              final sortedAuraIcons = List<IconModel>.from(icons)
                ..sort((a, b) => b.size.compareTo(a.size));

              final circleAuras = sortedAuraIcons.map((icon) {
                 final latLng = _offsetToLatLng(icon.position);
                 final double tokenPower = icon.size > 1.0 ? (icon.size - 1.0) : 0.0;
                 final auraRadiusMeters = tokenPower * 10000.0;
                 final Color auraColor = icon.displayColor;
                 return CircleMarker(
                   point: latLng,
                   radius: auraRadiusMeters,
                   useRadiusInMeter: true,
                   color: auraColor.withOpacity(0.2),
                   borderColor: auraColor.withOpacity(0.4),
                   borderStrokeWidth: 1.0,
                 );
              }).where((c) => c.radius > 0).toList();

              // zoom >= 7 (regions): 3:2 dikdörtgen ikon + slogan etiketi
              // zoom  < 7         : yuvarlak daire ikon
              final bool useRect = _currentZoom >= 7;

              final markerDots = icons.map((icon) {
                  final latLng = _offsetToLatLng(icon.position);
                  final Color displayColor = icon.displayColor;

                  if (useRect) {
                    // 3:2 dikdörtgen ikon + kampanya sloganı
                    final String? slogan = icon.campaignSlogan;
                    return Marker(
                        point: latLng,
                        width: slogan != null ? 90.0 : 15.0,
                        height: slogan != null ? 26.0 : 10.0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 15.0,
                              height: 10.0,
                              decoration: BoxDecoration(
                                color: displayColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            if (slogan != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  slogan,
                                  style: TextStyle(
                                    color: displayColor,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                    );
                  } else {
                    // Daire ikon
                    return Marker(
                        point: latLng,
                        width: 10.0,
                        height: 10.0,
                        child: Container(
                            decoration: BoxDecoration(
                                color: displayColor,
                                shape: BoxShape.circle,
                            ),
                        )
                    );
                  }
              }).toList();

              // ── Polygon layer ──
              // Always show selected polygons from BOTH layers at every zoom level.
              // In region-select mode: also show the active layer's unselected boundaries.
              final List<Polygon> polygonWidgets = [];
              final Set<String> _renderedSelected = {};

              if (_regionSelectMode && _isGeoJsonLoaded) {
                // 1) Active layer: show all polygons (selected = cyan, unselected = faint)
                for (final cp in _activePolygons) {
                  final bool selected = cp.parentCountry != null
                      ? _isRegionSelected(cp.name, cp.parentCountry)
                      : _isCountrySelected(cp.name);
                  if (selected) {
                    _renderedSelected.add(cp.parentCountry != null
                        ? '${cp.name}|${cp.parentCountry}'
                        : 'country:${cp.name}');
                  }
                  polygonWidgets.add(Polygon(
                    points: cp.outerRing,
                    holePointsList: cp.holes,
                    color: selected
                        ? Colors.cyan.withOpacity(0.35)
                        : Colors.cyan.withOpacity(0.08),
                    borderColor: selected
                        ? Colors.cyanAccent
                        : Colors.cyan.withOpacity(0.7),
                    borderStrokeWidth: selected ? 3.0 : 1.2,
                    isFilled: true,
                  ));
                }

                // 2) Also render selected items from the OTHER layer so they stay visible on zoom
                // If active layer is countries (zoom<7), also show selected admin-1 regions
                if (_currentZoom < 7 && _isAdmin1Loaded) {
                  for (final cp in _admin1Polygons) {
                    final key = '${cp.name}|${cp.parentCountry}';
                    if (_selectedRegions.contains(key) && !_renderedSelected.contains(key)) {
                      polygonWidgets.add(Polygon(
                        points: cp.outerRing,
                        holePointsList: cp.holes,
                        color: Colors.cyan.withOpacity(0.30),
                        borderColor: Colors.cyanAccent.withOpacity(0.8),
                        borderStrokeWidth: 2.0,
                        isFilled: true,
                      ));
                    }
                  }
                }
                // If active layer is admin-1 (zoom>=7), also show selected countries
                if (_currentZoom >= 7 && _isCountriesLoaded) {
                  for (final cp in _countryPolygons) {
                    if (_isCountrySelected(cp.name) && !_renderedSelected.contains('country:${cp.name}')) {
                      polygonWidgets.add(Polygon(
                        points: cp.outerRing,
                        holePointsList: cp.holes,
                        color: Colors.cyan.withOpacity(0.25),
                        borderColor: Colors.cyanAccent.withOpacity(0.7),
                        borderStrokeWidth: 2.0,
                        isFilled: true,
                      ));
                    }
                  }
                }
              }

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _initialCenter,
                  initialZoom: _currentZoom,
                  minZoom: 2.0,
                  maxZoom: 18.0,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-90, -180),
                      const LatLng(90, 180),
                    ),
                  ),
                  onPositionChanged: (position, hasGesture) {
                    if (position.zoom != null) {
                      if (mounted) setState(() => _currentZoom = position.zoom!);
                    }
                  },
                  onTap: (tapPosition, point) {
                      // ── If region-select mode is on, handle region taps ──
                      if (_regionSelectMode && _isGeoJsonLoaded) {
                        _handleRegionTap(point);
                        return;
                      }

                      // ── Normal mode: icon hit detection ──
                      // Use the DISPLAYED icons (paused or live)
                      final displayIcons = _paused ? _pausedSnapshot : icons;
                      for (var icon in displayIcons) {
                          final String userSlogan = icon.id.startsWith('mock')
                              ? 'Mock Token ${icon.id}'
                              : 'World exploration mode.';
                          final iconPoint = _offsetToLatLng(icon.position);
                          final dist = const Distance().as(LengthUnit.Kilometer, point, iconPoint);
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
                              ? '🌍 SELECT CONTINENTS'
                              : _zoomLevel == 'countries'
                                  ? '🗺️ SELECT COUNTRIES'
                           : '🏙️ SELECT REGIONS')
                          : (_currentZoom < 4
                              ? '🌍 CONTINENTS'
                              : _currentZoom < 7
                                  ? '🗺️ COUNTRIES'
                                  : '🏙️ REGIONS'),
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

          // ── Center Button ──
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
              onPressed: () => _mapController.move(_initialCenter, 4.0),
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
                    _paused
                        ? '⏸ Paused — icons frozen, tap to inspect'
                        : '▶ Resumed — live positions',
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: _paused ? Colors.amber.shade800 : Colors.cyan,
                  duration: const Duration(seconds: 2),
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
        ],
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
