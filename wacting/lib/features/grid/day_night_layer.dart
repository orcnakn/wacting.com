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

    // Build terminator latitudes for each longitude (base, -180..180)
    final List<double> termLats = [];
    final List<double> termLons = List.generate(181, (i) => -180.0 + i * 2.0);
    for (final lon in termLons) {
      final solarTimeMin = (time.hour * 60 + time.minute) + (lon * 4) + eqTime;
      final hourAngle = (solarTimeMin / 4) - 180;
      final hRad = hourAngle * math.pi / 180;
      double latRad;
      if (declination.abs() < 0.001) {
        latRad = 0;
      } else {
        final tanLat = -math.cos(hRad) / math.tan(declination);
        latRad = math.atan(tanLat);
      }
      termLats.add((latRad * 180 / math.pi).clamp(-85.0, 85.0));
    }

    // Draw night polygon for each of the 5 world copies
    const List<double> worldOffsets = [-720, -360, 0, 360, 720];

    final List<List<math.Point<double>>> allPolygons = [];

    for (final offset in worldOffsets) {
      final List<math.Point<double>> pts = [];
      bool anyVisible = false;

      try {
        for (int i = 0; i < termLons.length; i++) {
          final pt = camera.latLngToScreenPoint(
              LatLng(termLats[i], termLons[i] + offset));
          pts.add(math.Point(pt.x, pt.y));
          if (pt.x >= -256 && pt.x <= camera.nonRotatedSize.x + 256) {
            anyVisible = true;
          }
        }

        if (!anyVisible) continue;

        // Close polygon around the night pole
        if (declination > 0) {
          final p1 = camera.latLngToScreenPoint(LatLng(-85.0, 180.0 + offset));
          final p2 = camera.latLngToScreenPoint(LatLng(-85.0, -180.0 + offset));
          pts.add(math.Point(p1.x, p1.y));
          pts.add(math.Point(p2.x, p2.y));
        } else {
          final p1 = camera.latLngToScreenPoint(LatLng(85.0, 180.0 + offset));
          final p2 = camera.latLngToScreenPoint(LatLng(85.0, -180.0 + offset));
          pts.add(math.Point(p1.x, p1.y));
          pts.add(math.Point(p2.x, p2.y));
        }

        allPolygons.add(pts);
      } catch (_) {}
    }

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DayNightMapPainter(polygons: allPolygons),
      ),
    );
  }
}

class _DayNightMapPainter extends CustomPainter {
  final List<List<math.Point<double>>> polygons;

  _DayNightMapPainter({required this.polygons});

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty) return;

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25.0);

    for (final points in polygons) {
      if (points.isEmpty) continue;
      final path = Path();
      path.moveTo(points.first.x, points.first.y);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].x, points[i].y);
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DayNightMapPainter oldDelegate) => true;
}
