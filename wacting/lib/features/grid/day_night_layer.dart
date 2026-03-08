import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../core/utils/sun_math.dart';

class DayNightLayer extends StatelessWidget {
  const DayNightLayer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final time = DateTime.now().toUtc();
    
    final declination = MapIlluminationTracker.getSolarDeclination(time);
    final dayOfYear = time.difference(DateTime(time.year, 1, 1)).inDays + 1;
    final b = (2 * math.pi / 364) * (dayOfYear - 81);
    final eqTime = 9.87 * math.sin(2 * b) - 7.53 * math.cos(b) - 1.5 * math.sin(b);

    final List<math.Point<double>> screenPoints = [];
    final List<LatLng> polyPoints = [];

    // Calculate terminator points across longitudes
    for (double lon = -180; lon <= 180; lon += 2) {
      final solarTimeMin = (time.hour * 60 + time.minute) + (lon * 4) + eqTime;
      final hourAngle = (solarTimeMin / 4) - 180;
      final hRad = hourAngle * math.pi / 180;
      
      double latRad;
      if (declination.abs() < 0.001) {
         latRad = 0; 
      } else {
         final tanLat = - math.cos(hRad) / math.tan(declination);
         latRad = math.atan(tanLat);
      }
      final lat = latRad * 180 / math.pi;
      
      // We clip latitudes strongly to avoid Map rendering glitches at true 90 poles
      polyPoints.add(LatLng(lat.clamp(-85.0, 85.0), lon));
    }

    // Close the polygon to wrap the correct pole (Night Side)
    if (declination > 0) {
      // Sun is North, Night wraps South
      polyPoints.add(const LatLng(-85.0, 180.0));
      polyPoints.add(const LatLng(-85.0, -180.0));
    } else {
      // Sun is South, Night wraps North
      polyPoints.add(const LatLng(85.0, 180.0));
      polyPoints.add(const LatLng(85.0, -180.0));
    }

    try {
      for (final p in polyPoints) {
        final pt = camera.latLngToScreenPoint(p);
        screenPoints.add(math.Point(pt.x, pt.y));
      }
    } catch (_) {}

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DayNightMapPainter(points: screenPoints),
      ),
    );
  }
}

class _DayNightMapPainter extends CustomPainter {
  final List<math.Point<double>> points;

  _DayNightMapPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final path = Path();
    path.moveTo(points.first.x, points.first.y);
    for (int i = 1; i < points.length; i++) {
        // Simple smoothing and line to next vertex
        path.lineTo(points[i].x, points[i].y);
    }
    path.close();

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25.0); // Smooth twilight fade

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DayNightMapPainter oldDelegate) {
    if (oldDelegate.points.length != points.length) return true;
    for (int i = 0; i < points.length; i++) {
        if (oldDelegate.points[i].x != points[i].x || oldDelegate.points[i].y != points[i].y) return true;
    }
    return false;
  }
}
