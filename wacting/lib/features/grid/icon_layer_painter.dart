import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/models/icon_model.dart';
import 'providers/grid_state.dart';

class IconLayerPainter extends CustomPainter {
  final ViewportState viewport;
  final List<IconModel> icons;
  final double timeElapsed; // Used for animation of orbits

  IconLayerPainter({
    required this.viewport,
    required this.icons,
    required this.timeElapsed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (viewport.screenSize == Size.zero || icons.isEmpty) return;

    canvas.save();
    canvas.scale(viewport.zoom, viewport.zoom);
    canvas.translate(-viewport.position.dx, -viewport.position.dy);

    for (final icon in icons) {
      // Ensure it is inside the viewport via bounding rect checking
      // (Assuming icons have already been filtered roughly by a spatial index, 
      //  but double checking exact intersection here is safe)
      final iconRect = Rect.fromCircle(center: icon.position, radius: icon.size / 2);
      if (!viewport.visibleWorldBounds.overlaps(iconRect)) continue;

      _drawIcon(canvas, icon);
      _drawFollowerSwarm(canvas, icon);
    }

    canvas.restore();
  }

  void _drawIcon(Canvas canvas, IconModel icon) {
    final paint = Paint()
      ..color = icon.color
      ..style = PaintingStyle.fill;
    
    // Add glow effect for the icon
    paint.maskFilter = MaskFilter.blur(BlurStyle.outer, icon.size * 0.2);

    if (icon.shapeIndex == 0) {
      // Circle
      canvas.drawCircle(icon.position, icon.size / 2, paint);
    } else if (icon.shapeIndex == 1) {
      // Diamond
      final path = Path()
        ..moveTo(icon.position.dx, icon.position.dy - icon.size / 2)
        ..lineTo(icon.position.dx + icon.size / 2, icon.position.dy)
        ..lineTo(icon.position.dx, icon.position.dy + icon.size / 2)
        ..lineTo(icon.position.dx - icon.size / 2, icon.position.dy)
        ..close();
      canvas.drawPath(path, paint);
    } else {
       // Placeholder for Hexagon or others
       canvas.drawCircle(icon.position, icon.size / 2, paint);
    }
  }

  void _drawFollowerSwarm(Canvas canvas, IconModel icon) {
    // We visually represent up to a maximum number of distinct dots so it doesn't clutter.
    // The number of orbiting dots scales logarithmically with true follower count.
    final int swarmDensity = min((log(max(1, icon.followerCount)) * 5).toInt(), 50);
    
    if (swarmDensity <= 0) return;

    final paint = Paint()
      ..color = icon.color.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    final double orbitRadius = (icon.size / 2) * 1.5; // Orbit a bit outside the main body
    
    for (int i = 0; i < swarmDensity; i++) {
       // Offset each particle mathematically
       final double angleOffset = (2 * pi / swarmDensity) * i;
       // timeElapsed provides uniform rotation speed to the swarm
       final double currentAngle = angleOffset + (timeElapsed * 2); 
       
       // Add slight sinusoidal wobble to the orbit radius for "swarming" effect
       final double wobble = sin(currentAngle * 3 + i) * (icon.size * 0.1);
       final double r = orbitRadius + wobble;

       final double x = icon.position.dx + cos(currentAngle) * r;
       final double y = icon.position.dy + sin(currentAngle) * r;

       canvas.drawCircle(Offset(x, y), max(0.5, icon.size * 0.05), paint);
    }
  }

  @override
  bool shouldRepaint(covariant IconLayerPainter oldDelegate) {
    // Repaint continuously if timeElapsed changes (which drives the animation)
    return true; 
  }
}
