import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/socket_service.dart';
import '../../core/models/icon_model.dart';
import '../grid/day_night_layer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Animated background: world map + icons + W traveler
// W roams near screen center (around login area). Icons get swallowed.
// Text cycles: WACTING → WE ACTING → WACTING → WORK ACTING → WACTING → ...
// ─────────────────────────────────────────────────────────────────────────────

class AuthBackgroundAnimation extends StatefulWidget {
  final ValueChanged<bool> onMerge;

  const AuthBackgroundAnimation({Key? key, required this.onMerge})
      : super(key: key);

  @override
  State<AuthBackgroundAnimation> createState() =>
      _AuthBackgroundAnimationState();
}

class _AuthBackgroundAnimationState extends State<AuthBackgroundAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _tickController;
  final Random _rng = Random();
  final MapController _mapController = MapController();

  // W traveler — stays near center area (around login)
  LatLng _wPos = const LatLng(35.0, 15.0);
  LatLng _wTarget = const LatLng(40.0, 25.0);
  final double _wSpeed = 0.15;
  double _wScale = 1.0;

  // Rotating text phrases
  static const List<String> _phrases = [
    'WE ACTING', 'WORLD ACTING', 'WHOLE ACTING', 'WITH ACTING',
    'WAKE ACTING', 'WHITE ACTING', 'WHY ACTING', 'WORTH ACTING',
    'WILL ACTING', 'WORD ACTING', 'WATCH ACTING', 'WILD ACTING',
    'WEATHER ACTING', 'WELL ACTING', 'WEALTH ACTING', 'WRAP ACTING',
    'WAY ACTING', 'WISE ACTING', 'WORK ACTING', 'WARN ACTING',
    'WIN ACTING', 'WARM ACTING', 'WORD ACTING', 'WOW ACTING',
    'WEAR ACTING', 'WINDOW ACTING', 'WAVE ACTING', 'WHISPEAR ACTING',
    'WEEKEND ACTING', 'WHISTLE ACTING', 'WALTZ ACTING',
    'WHOOP ACTING', 'WHIRL ACTING',
  ];
  int _phraseIndex = 0;
  String _currentText = 'WACTING';
  bool _isTransitioning = false;

  // Waypoints — tighter orbit near center of visible map
  static const List<LatLng> _waypoints = [
    LatLng(40.0, 10.0),
    LatLng(45.0, 30.0),
    LatLng(35.0, 50.0),
    LatLng(30.0, 20.0),
    LatLng(42.0, -5.0),
    LatLng(38.0, 40.0),
    LatLng(48.0, 15.0),
    LatLng(33.0, 35.0),
    LatLng(44.0, 0.0),
    LatLng(36.0, 25.0),
  ];
  int _waypointIndex = 0;

  // Attraction
  static const double _attractRadius = 50.0;
  final Set<String> _capturedIds = {};
  final List<_AttractingIcon> _attractingIcons = [];

  // Edge icons
  final List<_EdgeIcon> _edgeIcons = [];
  int _edgeSpawnCounter = 0;

  List<IconModel> _lastIcons = [];

  @override
  void initState() {
    super.initState();
    _wTarget = _waypoints[_waypointIndex];
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _tickController.repeat();
  }

  @override
  void dispose() {
    _tickController.dispose();
    super.dispose();
  }

  void _tick() {
    setState(() {
      // ── Move W ──
      final dLat = _wTarget.latitude - _wPos.latitude;
      final dLng = _wTarget.longitude - _wPos.longitude;
      final dist = sqrt(dLat * dLat + dLng * dLng);

      if (dist < _wSpeed * 2) {
        _waypointIndex = (_waypointIndex + 1) % _waypoints.length;
        _wTarget = _waypoints[_waypointIndex];
      } else {
        final norm = 1.0 / dist;
        _wPos = LatLng(
          _wPos.latitude + dLat * norm * _wSpeed,
          _wPos.longitude + dLng * norm * _wSpeed,
        );
      }

      // ── W scale pulse decay ──
      if (_wScale > 1.0) {
        _wScale -= 0.02;
        if (_wScale < 1.0) _wScale = 1.0;
      }

      // ── Update attracting icons → swallow on arrival ──
      _attractingIcons.removeWhere((ai) {
        ai.progress += 0.06;
        if (ai.progress >= 1.0) {
          // Swallowed!
          _wScale = 1.3;
          if (!_isTransitioning) {
            _isTransitioning = true;
            // Show next phrase
            _currentText = _phrases[_phraseIndex];
            _phraseIndex = (_phraseIndex + 1) % _phrases.length;
            widget.onMerge(true);
            // Return to WACTING after 1 second
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) {
                setState(() {
                  _currentText = 'WACTING';
                  _isTransitioning = false;
                });
                widget.onMerge(false);
              }
            });
          }
          return true;
        }
        return false;
      });

      // ── Update edge icons ──
      _edgeIcons.removeWhere((ei) {
        ei.lat += ei.dLat;
        ei.lng += ei.dLng;
        ei.life--;
        return ei.life <= 0;
      });

      // ── Spawn edge icons more frequently ──
      _edgeSpawnCounter++;
      if (_edgeSpawnCounter >= 60) {
        _edgeSpawnCounter = 0;
        _spawnEdgeIcon();
      }

      // ── Release old captured IDs ──
      if (_capturedIds.length > 15) {
        final toRemove = _capturedIds.take(_capturedIds.length - 8).toList();
        _capturedIds.removeAll(toRemove);
      }
    });
  }

  void _spawnEdgeIcon() {
    final colors = [
      const Color(0xFF2196F3),
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF00BCD4),
      const Color(0xFFFF5722),
      const Color(0xFF607D8B),
    ];
    final color = colors[_rng.nextInt(colors.length)];

    // Spawn from edges but aim toward center area (near login window)
    final edge = _rng.nextInt(4);
    double lat, lng, dLat, dLng;
    // Target area: lat 25-50, lng -10 to 50 (center of visible map)
    final targetLat = 25 + _rng.nextDouble() * 25;
    final targetLng = -10 + _rng.nextDouble() * 60;

    switch (edge) {
      case 0: // top
        lat = 70.0;
        lng = -100 + _rng.nextDouble() * 200;
        break;
      case 1: // bottom
        lat = -40.0;
        lng = -100 + _rng.nextDouble() * 200;
        break;
      case 2: // left
        lat = 10 + _rng.nextDouble() * 50;
        lng = -150.0;
        break;
      default: // right
        lat = 10 + _rng.nextDouble() * 50;
        lng = 150.0;
        break;
    }

    // Direction toward center
    final toLat = targetLat - lat;
    final toLng = targetLng - lng;
    final toDist = sqrt(toLat * toLat + toLng * toLng);
    final speed = 0.08 + _rng.nextDouble() * 0.12;
    dLat = (toLat / toDist) * speed;
    dLng = (toLng / toDist) * speed;

    _edgeIcons.add(_EdgeIcon(
      lat: lat,
      lng: lng,
      dLat: dLat,
      dLng: dLng,
      color: color,
      size: 4.0 + _rng.nextDouble() * 8.0,
      life: 400 + _rng.nextInt(400),
    ));
  }

  Offset? _latLngToScreen(LatLng point) {
    try {
      final camera = _mapController.camera;
      final projected = camera.latLngToScreenPoint(point);
      return Offset(projected.x, projected.y);
    } catch (_) {
      return null;
    }
  }

  LatLng _offsetToLatLng(Offset pos) {
    double lng = (pos.dx / 510) * 360 - 180;
    double lat = 90 - (pos.dy / 510) * 180;
    return LatLng(lat, lng);
  }

  void _checkAttractions(Size screenSize) {
    final wScreen = _latLngToScreen(_wPos);
    if (wScreen == null) return;

    for (final icon in _lastIcons) {
      if (_capturedIds.contains(icon.id)) continue;

      final iconLatLng = _offsetToLatLng(icon.position);
      final iconScreen = _latLngToScreen(iconLatLng);
      if (iconScreen == null) continue;

      final dx = iconScreen.dx - wScreen.dx;
      final dy = iconScreen.dy - wScreen.dy;
      final screenDist = sqrt(dx * dx + dy * dy);

      if (screenDist < _attractRadius) {
        _capturedIds.add(icon.id);
        _attractingIcons.add(_AttractingIcon(
          startPos: iconScreen,
          color: icon.displayColor,
          progress: 0.0,
        ));
      }
    }

    // Check edge icons
    for (int i = _edgeIcons.length - 1; i >= 0; i--) {
      final ei = _edgeIcons[i];
      final eiScreen = _latLngToScreen(LatLng(ei.lat, ei.lng));
      if (eiScreen == null) continue;

      final dx = eiScreen.dx - wScreen.dx;
      final dy = eiScreen.dy - wScreen.dy;
      if (sqrt(dx * dx + dy * dy) < _attractRadius) {
        _attractingIcons.add(_AttractingIcon(
          startPos: eiScreen,
          color: ei.color,
          progress: 0.0,
        ));
        _edgeIcons.removeAt(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IconModel>>(
      stream: socketService.iconStream,
      initialData: const [],
      builder: (context, snapshot) {
        _lastIcons = snapshot.data ?? [];

        // Real icon markers
        final markers = _lastIcons.map((icon) {
          final latLng = _offsetToLatLng(icon.position);
          final sz = (icon.size * 2).clamp(4.0, 50.0).toDouble();
          return Marker(
            point: latLng,
            width: sz,
            height: sz,
            child: Container(
              decoration: BoxDecoration(
                color: icon.displayColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: icon.displayColor.withOpacity(0.5),
                      blurRadius: sz / 2.0),
                ],
              ),
            ),
          );
        }).toList();

        // Edge icon markers
        final edgeMarkers = _edgeIcons.map((ei) {
          return Marker(
            point: LatLng(ei.lat, ei.lng),
            width: ei.size,
            height: ei.size,
            child: Container(
              decoration: BoxDecoration(
                color: ei.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: ei.color.withOpacity(0.5),
                      blurRadius: ei.size / 2.0),
                ],
              ),
            ),
          );
        }).toList();

        return LayoutBuilder(builder: (context, constraints) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkAttractions(
                Size(constraints.maxWidth, constraints.maxHeight));
          });

          return Stack(
            children: [
              // ── World map ──
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(35.0, 20.0),
                  initialZoom: 2.5,
                  cameraConstraint: CameraConstraint.contain(
                    bounds: LatLngBounds(
                      const LatLng(-90, -180),
                      const LatLng(90, 180),
                    ),
                  ),
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.wacting.app',
                  ),
                  const DayNightLayer(),
                  MarkerLayer(markers: markers),
                  MarkerLayer(markers: edgeMarkers),
                  // W marker with text
                  MarkerLayer(markers: [
                    Marker(
                      point: _wPos,
                      width: 120,
                      height: 70,
                      child: _buildWMarker(),
                    ),
                  ]),
                ],
              ),

              // ── Attracting icons overlay (above map, below login) ──
              ..._buildAttractingOverlays(),
            ],
          );
        });
      },
    );
  }

  /// W icon with rotating WACTING text above
  Widget _buildWMarker() {
    return SizedBox(
      width: 120,
      height: 70,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cycling text ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              _currentText,
              key: ValueKey(_currentText),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: _currentText == 'WACTING'
                    ? FontWeight.bold
                    : FontWeight.w400,
                letterSpacing: _currentText == 'WACTING' ? 3 : 1.5,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 8),
                  Shadow(color: Colors.black, blurRadius: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // ── W circle with pulse ──
          Transform.scale(
            scale: _wScale,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF416C).withOpacity(0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('W',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAttractingOverlays() {
    final wScreen = _latLngToScreen(_wPos);
    if (wScreen == null) return [];

    return _attractingIcons.map((ai) {
      final currentX =
          ai.startPos.dx + (wScreen.dx - ai.startPos.dx) * ai.progress;
      final currentY =
          ai.startPos.dy + (wScreen.dy - ai.startPos.dy) * ai.progress;
      final scale = 1.0 - ai.progress * 0.7;
      final opacity = (1.0 - ai.progress * 0.5).clamp(0.0, 1.0);

      return Positioned(
        left: currentX - 8,
        top: currentY - 8,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: ai.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: ai.color.withOpacity(0.6), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _AttractingIcon {
  final Offset startPos;
  final Color color;
  double progress;

  _AttractingIcon({
    required this.startPos,
    required this.color,
    required this.progress,
  });
}

class _EdgeIcon {
  double lat;
  double lng;
  double dLat;
  double dLng;
  final Color color;
  final double size;
  int life;

  _EdgeIcon({
    required this.lat,
    required this.lng,
    required this.dLat,
    required this.dLng,
    required this.color,
    required this.size,
    required this.life,
  });
}
