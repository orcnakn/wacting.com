import 'package:flutter/material.dart';
import '../../app/constants.dart';
import '../../core/utils/sun_math.dart';
import 'providers/grid_state.dart';
import 'lod_manager.dart';

class GridPainter extends CustomPainter {
  final ViewportState viewport;
  final DateTime currentTime;
  GridPainter(this.viewport, this.currentTime);

  @override
  void paint(Canvas canvas, Size size) {
    if (viewport.screenSize == Size.zero) return;
    
    // We scale by zoom
    canvas.save();
    canvas.scale(viewport.zoom, viewport.zoom);
    
    // We translate so that viewport.position is at the top-left of the screen
    // Note: To pan in the direction of drag, translate by negative viewport offset.
    canvas.translate(-viewport.position.dx, -viewport.position.dy);
    
    _drawWorldBackground(canvas);
    _drawGridLines(canvas, size, viewport.zoom);

    canvas.restore();
  }

  void _drawWorldBackground(Canvas canvas) {
    final worldRect = Rect.fromLTWH(0, 0, GridConstants.gridWidth.toDouble(), GridConstants.gridHeight.toDouble());
    
    // Create base dark land
    final nightPaint = Paint()..color = ThemeConstants.landNight;
    canvas.drawRect(worldRect, nightPaint);

    // Approximate solar subsolar point
    final declination = MapIlluminationTracker.getSolarDeclination(currentTime);
    
    // Equation of time (approximated)
    final dayOfYear = currentTime.difference(DateTime(currentTime.year, 1, 1)).inDays + 1;
    final b = (2 * 3.14159 / 364) * (dayOfYear - 81);
    final eqTime = 9.87 * 3.14159 / 180 * 2 * b - 7.53 * 3.14159 / 180 * b - 1.5 * 3.14159 / 180 * b; // roughly
    
    // Subsolar longitude: Where is it noon?
    // UTC 12:00 -> lon 0. UTC 00:00 -> lon 180.
    final double subsolarLon = -((currentTime.hour + currentTime.minute / 60.0) - 12.0) * 15.0; 
    
    // Subsolar latitude is declination (in degrees)
    final double subsolarLat = declination * 180.0 / 3.14159;

    // Convert subsolar point to Grid coordinates
    final double subX = (subsolarLon + 180.0) / 360.0 * GridConstants.gridWidth;
    final double subY = (90.0 - subsolarLat) / 180.0 * GridConstants.gridHeight;
    final Offset subsolarOffset = Offset(subX, subY);

    // The terminator is 90 degrees away from the subsolar point.
    // 90 degrees in grid coordinates (width is 360 deg)
    final double terminatorRadius = (90.0 / 360.0) * GridConstants.gridWidth;

    // 1. Draw glowing city lights on the night side 
    // We use a simple noise approximation by drawing many tiny dots across the dark side
    // In a real app this would be a loaded texture or driven by population data.
    _drawCityLights(canvas, worldRect, subsolarOffset, terminatorRadius);

    // 2. Draw the Daylight Overlay using a RadialGradient
    // The gradient goes from full daylight at the center (subsolar) 
    // to twilight at the edge, then transparent in the night.
    final dayGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0, 
      colors: [
        ThemeConstants.landDay.withOpacity(0.5), // High noon
        ThemeConstants.landDay.withOpacity(0.35), 
        ThemeConstants.terminatorLine.withOpacity(0.3), // Twilight boundary
        Colors.transparent, // Night
      ],
      stops: const [0.0, 0.7, 0.95, 1.0],
    );

    // To handle Earth wrapping (if the sun is at the edge of the flat map),
    // we draw the gradient multiple times offset by the map width.
    for (int i = -1; i <= 1; i++) {
        final offsetSubX = subX + (i * GridConstants.gridWidth);
        final offsetSubsolar = Offset(offsetSubX, subY);
        
        final dayPaint = Paint()
          ..shader = dayGradient.createShader(Rect.fromCircle(center: offsetSubsolar, radius: terminatorRadius * 1.05)); 
          // 1.05 expands it slightly to account for atmospheric refraction (twilight)

        canvas.drawRect(worldRect, dayPaint);
    }
  }

  void _drawCityLights(Canvas canvas, Rect worldRect, Offset subsolarOffset, double terminatorRadius) {
     final paint = Paint()
       ..color = ThemeConstants.cityLights.withOpacity(0.8)
       ..style = PaintingStyle.fill
       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5); // Glow effect
       
     // Seeded deterministic noise for city positions
     int seed = 42;
     for(int y = 0; y < GridConstants.gridHeight; y+= 8) {
       for(int x = 0; x < GridConstants.gridWidth; x+= 8) {
          seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
          if (seed % 100 > 92) { // 8% chance to be a city cluster
             
             // Check if it is in the night side (distance > terminator radius)
             // We check against true wrapped distance
             double dx = (x - subsolarOffset.dx).abs();
             if (dx > GridConstants.gridWidth / 2) dx = GridConstants.gridWidth - dx;
             double dy = y - subsolarOffset.dy;
             
             double distSq = dx * dx + dy * dy;
             // If distance is further than the terminator, it's night
             if (distSq > (terminatorRadius * terminatorRadius) * 0.9) {
                 // Calculate fade based on depth into night
                 double glowSize = (seed % 3) == 0 ? 1.5 : 0.8;
                 canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), glowSize, paint);
             }
          }
       }
     }
  }

  void _drawGridLines(Canvas canvas, Size screenSize, double zoom) {
    // Hide grid lines if zoomed out too far to prevent aliasing noise
    if (!LodManager.shouldDrawGridLines(zoom)) return;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.0 / zoom // Grid line width remains thin relative to screen
      ..style = PaintingStyle.stroke;

    final rect = viewport.visibleWorldBounds;

    // Determine start and end logic, bounded by the world
    int startCol = rect.left.floor().clamp(0, GridConstants.gridWidth);
    int endCol = rect.right.ceil().clamp(0, GridConstants.gridWidth);
    
    int startRow = rect.top.floor().clamp(0, GridConstants.gridHeight);
    int endRow = rect.bottom.ceil().clamp(0, GridConstants.gridHeight);

    // Vertical lines
    for (int col = startCol; col <= endCol; col++) {
      double x = col.toDouble();
      canvas.drawLine(Offset(x, rect.top.clamp(0.0, GridConstants.gridHeight.toDouble())), 
                      Offset(x, rect.bottom.clamp(0.0, GridConstants.gridHeight.toDouble())), paint);
    }
    // Horizontal lines
    for (int row = startRow; row <= endRow; row++) {
      double y = row.toDouble();
      canvas.drawLine(Offset(rect.left.clamp(0.0, GridConstants.gridWidth.toDouble()), y), 
                      Offset(rect.right.clamp(0.0, GridConstants.gridWidth.toDouble()), y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
     return oldDelegate.viewport != viewport ||
            oldDelegate.currentTime != currentTime;
  }
}
