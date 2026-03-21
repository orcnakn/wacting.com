import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Emergency campaign marker with radio wave animation.
/// Shows a red icon with expanding concentric rings (radio signal effect).
class EmergencyMarker extends StatefulWidget {
  final Color color;
  final double areaM2;
  final String? slogan;
  final VoidCallback? onTap;

  const EmergencyMarker({
    Key? key,
    this.color = Colors.red,
    this.areaM2 = 10000,
    this.slogan,
    this.onTap,
  }) : super(key: key);

  @override
  State<EmergencyMarker> createState() => _EmergencyMarkerState();
}

class _EmergencyMarkerState extends State<EmergencyMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Logo size scales with area (sqrt for visual proportion)
    final double logoSize = (math.sqrt(widget.areaM2) / 10).clamp(12.0, 60.0);

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: logoSize * 3,
        height: logoSize * 3,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _RadioWavePainter(
                progress: _controller.value,
                color: widget.color,
                centerSize: logoSize,
              ),
              child: Center(
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: logoSize * 0.6,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RadioWavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double centerSize;

  _RadioWavePainter({
    required this.progress,
    required this.color,
    required this.centerSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = centerSize / 2 + 2;

    // Draw 3 expanding rings at different phases
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final radius = minRadius + (maxRadius - minRadius) * phase;
      final opacity = (1.0 - phase) * 0.5;

      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadioWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
