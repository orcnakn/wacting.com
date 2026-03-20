import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Smooth day/night overlay using bilinear interpolation.
///
/// 1. Computes solar illumination on a coarse sample grid.
/// 2. Renders a fine output grid where each cell's opacity is
///    bilinear-interpolated from the 4 surrounding samples.
/// 3. No blur layer needed — no edge artifacts, perfectly consistent
///    across all world copies.
class DayNightLayer extends StatelessWidget {
  const DayNightLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final now = DateTime.now().toUtc();
    final solar = _SolarParams.fromTime(now);

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DayNightPainter(camera: camera, solar: solar),
      ),
    );
  }
}

class _SolarParams {
  final double sinDec;
  final double cosDec;
  final double solarBaseMin;

  _SolarParams._({
    required this.sinDec,
    required this.cosDec,
    required this.solarBaseMin,
  });

  factory _SolarParams.fromTime(DateTime utc) {
    final dayOfYear = utc.difference(DateTime(utc.year, 1, 1)).inDays + 1;
    final gamma = (2 * math.pi / 365.25) * (dayOfYear - 1 + (utc.hour - 12) / 24);

    final dec = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final b = (2 * math.pi / 364) * (dayOfYear - 81);
    final eqTime = 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);

    return _SolarParams._(
      sinDec: math.sin(dec),
      cosDec: math.cos(dec),
      solarBaseMin: (utc.hour * 60 + utc.minute).toDouble() + eqTime,
    );
  }

  /// Returns night opacity [0.0 = full day, 0.55 = full night].
  double nightOpacity(double latDeg, double lngDeg) {
    // Normalize longitude to -180..180 using modulo (handles any value)
    double lng = ((lngDeg + 180) % 360);
    if (lng < 0) lng += 360;
    lng -= 180;

    final hRad = ((solarBaseMin + lng * 4) / 4 - 180) * math.pi / 180;
    final latRad = latDeg * math.pi / 180;

    final cosZenith = math.sin(latRad) * sinDec +
        math.cos(latRad) * cosDec * math.cos(hRad);

    if (cosZenith >= 0.0) return 0.0;
    if (cosZenith > -0.20) return (-cosZenith / 0.20) * 0.55;
    return 0.55;
  }
}

class _DayNightPainter extends CustomPainter {
  final MapCamera camera;
  final _SolarParams solar;

  // Coarse sample grid — illumination computed here
  static const int sampleCols = 64;
  static const int sampleRows = 32;

  // Fine render grid — bilinear-interpolated, drawn to canvas
  // ~6x6 px cells on a 1920x1080 screen — invisible to the eye
  static const int renderCols = 320;
  static const int renderRows = 180;

  _DayNightPainter({required this.camera, required this.solar});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // ── Step 1: Compute coarse sample grid ──
    final samples = Float64List(sampleCols * sampleRows);
    final sStepX = w / (sampleCols - 1);
    final sStepY = h / (sampleRows - 1);

    for (int row = 0; row < sampleRows; row++) {
      final sy = row * sStepY;
      for (int col = 0; col < sampleCols; col++) {
        final sx = col * sStepX;
        final ll = camera.pointToLatLng(math.Point(sx, sy));
        final lat = ll.latitude.clamp(-85.0, 85.0);
        samples[row * sampleCols + col] = solar.nightOpacity(lat, ll.longitude);
      }
    }

    // ── Step 2: Render fine grid with bilinear interpolation ──
    final cellW = w / renderCols;
    final cellH = h / renderRows;
    final paint = Paint()..style = PaintingStyle.fill;

    // Scale factors: render grid → sample grid
    final scaleX = (sampleCols - 1) / renderCols;
    final scaleY = (sampleRows - 1) / renderRows;

    for (int row = 0; row < renderRows; row++) {
      // Sample grid Y coordinate (continuous)
      final gy = (row + 0.5) * scaleY;
      final y0 = gy.floor().clamp(0, sampleRows - 2);
      final fy = gy - y0;
      final fy1 = 1.0 - fy;
      final rowOff0 = y0 * sampleCols;
      final rowOff1 = (y0 + 1) * sampleCols;

      for (int col = 0; col < renderCols; col++) {
        // Sample grid X coordinate (continuous)
        final gx = (col + 0.5) * scaleX;
        final x0 = gx.floor().clamp(0, sampleCols - 2);
        final fx = gx - x0;

        // Bilinear interpolation from 4 surrounding samples
        final val = samples[rowOff0 + x0] * (1.0 - fx) * fy1 +
            samples[rowOff0 + x0 + 1] * fx * fy1 +
            samples[rowOff1 + x0] * (1.0 - fx) * fy +
            samples[rowOff1 + x0 + 1] * fx * fy;

        if (val < 0.01) continue; // Skip daylight cells

        final alpha = (val * 255).round().clamp(0, 140);
        paint.color = Color.fromARGB(alpha, 0, 0, 0);
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DayNightPainter oldDelegate) => true;
}
