import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Smooth day/night overlay rendered as a single GPU-scaled image.
///
/// 1. Computes solar illumination on a small pixel grid (128x64).
/// 2. Encodes it as an RGBA pixel buffer → dart:ui.Image.
/// 3. Draws the image scaled to fill the canvas with bilinear filtering.
///    No rectangles, no grid artifacts — perfectly smooth.
class DayNightLayer extends StatefulWidget {
  const DayNightLayer({Key? key}) : super(key: key);

  @override
  State<DayNightLayer> createState() => _DayNightLayerState();
}

class _DayNightLayerState extends State<DayNightLayer> {
  ui.Image? _nightImage;
  Timer? _timer;
  MapCamera? _lastCamera;
  int _lastMinute = -1;

  // Image resolution — small enough for fast computation,
  // large enough that GPU bilinear scaling looks smooth.
  static const int _imgW = 128;
  static const int _imgH = 64;

  @override
  void initState() {
    super.initState();
    // Refresh every 60s to track sun movement
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nightImage?.dispose();
    super.dispose();
  }

  Future<void> _buildImage(MapCamera camera) async {
    final now = DateTime.now().toUtc();
    final solar = _SolarParams.fromTime(now);

    // RGBA pixel buffer
    final pixels = Uint8List(_imgW * _imgH * 4);

    for (int row = 0; row < _imgH; row++) {
      // Map row to screen Y fraction
      final sy = row / (_imgH - 1);
      for (int col = 0; col < _imgW; col++) {
        final sx = col / (_imgW - 1);
        // Convert screen fraction to lat/lng via camera
        final screenX = sx * camera.size.x;
        final screenY = sy * camera.size.y;
        final ll = camera.pointToLatLng(math.Point(screenX, screenY));
        final lat = ll.latitude.clamp(-85.0, 85.0);
        final opacity = solar.nightOpacity(lat, ll.longitude);

        final idx = (row * _imgW + col) * 4;
        pixels[idx] = 0;     // R
        pixels[idx + 1] = 0; // G
        pixels[idx + 2] = 0; // B
        pixels[idx + 3] = (opacity * 255).round().clamp(0, 140); // A
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      _imgW,
      _imgH,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );

    final img = await completer.future;
    if (mounted) {
      final old = _nightImage;
      setState(() {
        _nightImage = img;
      });
      old?.dispose();
    } else {
      img.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final now = DateTime.now().toUtc();
    final minute = now.hour * 60 + now.minute;

    // Rebuild image when camera changes or time advances
    if (_nightImage == null || camera != _lastCamera || minute != _lastMinute) {
      _lastCamera = camera;
      _lastMinute = minute;
      _buildImage(camera);
    }

    return IgnorePointer(
      child: _nightImage != null
          ? CustomPaint(
              size: Size.infinite,
              painter: _DayNightPainter(image: _nightImage!),
            )
          : const SizedBox.shrink(),
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

  double nightOpacity(double latDeg, double lngDeg) {
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
  final ui.Image image;

  _DayNightPainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium  // GPU bilinear filtering
      ..isAntiAlias = true;
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _DayNightPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
