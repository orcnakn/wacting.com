import 'package:flutter/material.dart';

class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const ModernCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.backgroundColor = const Color(0xFF1C1C1E), // Apple Dark Mode Surface
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E), width: 1),
      ),
      child: child,
    );
  }
}
