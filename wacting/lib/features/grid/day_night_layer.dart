import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Smooth day/night overlay using an offscreen image.
///
/// 1. Computes solar illumination on a small grid (sample points).
/// 2. Writes those values as alpha pixels into a tiny RGBA image.
/// 3. Draws the image stretched to fill the screen with bilinear filtering.
///    The GPU handles smooth interpolation — no visible grid cells.
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
        painter: _DayNightImagePainter(camera: camera, solar: solar),
      ),
    );
  }
}

/// Pre-computed solar parameters for the current moment.
class _SolarParams {
  final double sinDec;
  final double cosDec;
  final double eqTimeMin;
  final double solarBaseMin; // (hour*60 + minute) + eqTime

  _SolarParams._({
    required this.sinDec,
    required this.cosDec,
    required this.eqTimeMin,
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
      eqTimeMin: eqTime,
      solarBaseMin: (utc.hour * 60 + utc.minute).toDouble() + eqTime,
    );
  }

  /// Returns night opacity [0.0 = full day, 0.55 = full night].
  double nightOpacity(double latDeg, double lngDeg) {
    // Normalize longitude to -180..180 using modulo (handles any value)
    double lng = ((lngDeg + 180) % 360);
    if (lng < 0) lng += 360;
    lng -= 180;

    final solarTimeMin = solarBaseMin + (lng * 4);
    final hRad = ((solarTimeMin / 4) - 180) * math.pi / 180;

    final latRad = latDeg * math.pi / 180;

    final cosZenith = math.sin(latRad) * sinDec +
        math.cos(latRad) * cosDec * math.cos(hRad);

    // cosZenith >= 0   → day (opacity 0)
    // -0.20 < cosZ < 0 → twilight (smooth gradient 0..0.55)
    // cosZenith <= -0.20 → night (opacity 0.55)
    if (cosZenith >= 0.0) return 0.0;
    if (cosZenith > -0.20) return (-cosZenith / 0.20) * 0.55;
    return 0.55;
  }
}

class _DayNightImagePainter extends CustomPainter {
  final MapCamera camera;
  final _SolarParams solar;

  /// Sample grid resolution for the offscreen image.
  /// Kept small — GPU bilinear upscaling handles smoothness.
  static const int imgW = 160;
  static const int imgH = 80;

  _DayNightImagePainter({required this.camera, required this.solar});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Step sizes: map each image pixel to a screen point
    final stepX = w / imgW;
    final stepY = h / imgH;

    // Build RGBA pixel data
    final pixels = Uint8List(imgW * imgH * 4);
    int offset = 0;

    for (int row = 0; row < imgH; row++) {
      final sy = (row + 0.5) * stepY;
      for (int col = 0; col < imgW; col++) {
        final sx = (col + 0.5) * stepX;

        // Screen point → lat/lng
        final ll = camera.pointToLatLng(math.Point(sx, sy));
        final lat = ll.latitude.clamp(-85.0, 85.0);
        final lng = ll.longitude;

        final opacity = solar.nightOpacity(lat, lng);

        // RGBA — black with computed alpha
        pixels[offset]     = 0;   // R
        pixels[offset + 1] = 0;   // G
        pixels[offset + 2] = 0;   // B
        pixels[offset + 3] = (opacity * 255).round().clamp(0, 255); // A
        offset += 4;
      }
    }

    // Decode pixels into a ui.Image synchronously via ImmutableBuffer + ImageDescriptor
    // We use decodeImageFromPixels with a sync-like pattern via PictureRecorder
    // Since decodeImageFromPixels is async, we use a workaround:
    // Draw the image data as individual vertical gradient strips using drawRect.
    //
    // Better approach: use saveLayer + blur to smooth the grid.
    _drawSmoothed(canvas, size, pixels);
  }

  void _drawSmoothed(Canvas canvas, Size size, Uint8List pixels) {
    final w = size.width;
    final h = size.height;
    final cellW = w / imgW;
    final cellH = h / imgH;

    // Apply Gaussian blur to the entire night layer for smooth transitions.
    // The blur sigma is ~1.5x cell size — eliminates visible grid edges
    // while keeping the day/night boundary crisp enough.
    final blurSigma = math.max(cellW, cellH) * 1.5;

    canvas.saveLayer(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..imageFilter = ui.ImageFilter.blur(
        sigmaX: blurSigma,
        sigmaY: blurSigma,
        tileMode: TileMode.clamp,
      ),
    );

    final paint = Paint()..style = PaintingStyle.fill;
    int offset = 0;

    for (int row = 0; row < imgH; row++) {
      for (int col = 0; col < imgW; col++) {
        final alpha = pixels[offset + 3];
        offset += 4;

        if (alpha == 0) continue; // Skip daylight cells

        paint.color = Color.fromARGB(alpha, 0, 0, 0);
        canvas.drawRect(
          Rect.fromLTWH(col * cellW, row * cellH, cellW + 1, cellH + 1),
          paint,
        );
      }
    }

    canvas.restore(); // Applies the blur
  }

  @override
  bool shouldRepaint(covariant _DayNightImagePainter oldDelegate) => true;
}
