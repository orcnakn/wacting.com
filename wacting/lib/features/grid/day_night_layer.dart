import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Pixel-grid based day/night overlay.
/// For each cell on screen, calculates real solar illumination
/// and draws a smooth, seamless night overlay — no polygon seam issues.
class DayNightLayer extends StatelessWidget {
  const DayNightLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final now = DateTime.now().toUtc();

    // Precompute solar parameters once per frame
    final solar = _SolarParams.fromTime(now);

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DayNightGridPainter(camera: camera, solar: solar),
      ),
    );
  }
}

/// Pre-computed solar parameters for the current moment.
class _SolarParams {
  final double declination; // radians
  final double eqTimeMin;  // equation of time in minutes
  final int hourUTC;
  final int minuteUTC;

  _SolarParams({
    required this.declination,
    required this.eqTimeMin,
    required this.hourUTC,
    required this.minuteUTC,
  });

  factory _SolarParams.fromTime(DateTime utc) {
    final dayOfYear = utc.difference(DateTime(utc.year, 1, 1)).inDays + 1;
    final gamma = (2 * math.pi / 365.25) * (dayOfYear - 1 + (utc.hour - 12) / 24);

    final declination = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final b = (2 * math.pi / 364) * (dayOfYear - 81);
    final eqTime = 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);

    return _SolarParams(
      declination: declination,
      eqTimeMin: eqTime,
      hourUTC: utc.hour,
      minuteUTC: utc.minute,
    );
  }

  /// Returns illumination factor [0.0 = night, 1.0 = day] for a given lat/lng.
  /// Includes smooth civil/nautical twilight gradient.
  double illumination(double latDeg, double lngDeg) {
    // Normalize longitude to -180..180 for solar calc
    double lng = lngDeg;
    while (lng > 180) lng -= 360;
    while (lng < -180) lng += 360;

    final solarTimeMin = (hourUTC * 60 + minuteUTC) + (lng * 4) + eqTimeMin;
    final hourAngle = (solarTimeMin / 4) - 180;

    final latRad = latDeg * math.pi / 180;
    final hRad = hourAngle * math.pi / 180;

    final cosZenith = math.sin(latRad) * math.sin(declination) +
        math.cos(latRad) * math.cos(declination) * math.cos(hRad);

    if (cosZenith >= 0.0) {
      return 1.0; // Day
    } else if (cosZenith > -0.20) {
      // Smooth twilight gradient (civil → nautical)
      return (cosZenith + 0.20) / 0.20;
    } else {
      return 0.0; // Night
    }
  }
}

class _DayNightGridPainter extends CustomPainter {
  final MapCamera camera;
  final _SolarParams solar;

  // Grid resolution — higher = smoother but slower
  // 100x50 = 5000 cells, good balance for web
  static const int gridCols = 100;
  static const int gridRows = 50;

  _DayNightGridPainter({required this.camera, required this.solar});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final cellW = w / gridCols;
    final cellH = h / gridRows;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int row = 0; row < gridRows; row++) {
      for (int col = 0; col < gridCols; col++) {
        // Cell center in screen coordinates
        final cx = (col + 0.5) * cellW;
        final cy = (row + 0.5) * cellH;

        // Convert screen point to lat/lng
        final latLng = camera.pointToLatLng(math.Point(cx, cy));
        final lat = latLng.latitude.clamp(-85.0, 85.0);
        final lng = latLng.longitude;

        final illum = solar.illumination(lat, lng);

        if (illum >= 1.0) continue; // Full daylight — skip drawing

        // Night darkness: 0.55 max opacity, scaled by (1 - illumination)
        final nightOpacity = (1.0 - illum) * 0.55;

        paint.color = Color.fromRGBO(0, 0, 0, nightOpacity.clamp(0.0, 0.55));

        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DayNightGridPainter oldDelegate) => true;
}
