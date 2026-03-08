import 'package:flutter/material.dart';

class ThemeConstants {
  // Sunlight map colors (Realistic Earth tones)
  static const Color oceanDay = Color(0xFF1E88E5);
  static const Color landDay = Color(0xFF2E7D32); // Deeper green
  static const Color oceanNight = Color(0xFF0D47A1);
  static const Color landNight = Color(0xFF1B5E20);
  static const Color terminatorLine = Color(0xFFFFB74D); // Softer twilight orange
  static const Color cityLights = Color(0xFFFFE082); // Warm glow for night side

  static const Color textPrimaryLight = Color(0xFF111111);
  static const Color textPrimaryDark = Color(0xFFEEEEEE);

  static const Duration mapUpdateInterval = Duration(seconds: 15); // Update more frequently for smooth movement
}

class GridConstants {
  static const int gridWidth = 715;
  static const int gridHeight = 714;
  static const int totalCells = gridWidth * gridHeight;
}
