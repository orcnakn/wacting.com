import 'package:flutter/material.dart';
import '../theme.dart';

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final bool isGhost;

  const ModernButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFF2C3E50),
    this.isGhost = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: isGhost ? Colors.transparent : color,
          border: Border.all(
            color: isGhost ? AppColors.borderMedium : color,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isGhost ? AppColors.navyPrimary : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
