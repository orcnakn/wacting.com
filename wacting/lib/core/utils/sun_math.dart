import 'dart:math';

class MapIlluminationTracker {
  /// Returns the current solar declination angle in radians.
  static double getSolarDeclination(DateTime time) {
    // Determine the day of the year
    final dayOfYear = time.difference(DateTime(time.year, 1, 1)).inDays + 1;
    // Fractional year in radians
    final gamma = (2 * pi / 365.25) * (dayOfYear - 1 + (time.hour - 12) / 24);
    
    // Estimate solar declination
    return 0.006918 -
        0.399912 * cos(gamma) +
        0.070257 * sin(gamma) -
        0.006758 * cos(2 * gamma) +
        0.000907 * sin(2 * gamma) -
        0.002697 * cos(3 * gamma) +
        0.00148 * sin(3 * gamma);
  }

  /// Calculates the fraction of sunlight [0, 1] for a given point on Earth.
  static double getIlluminationFactor(
      double latitude, double longitude, DateTime utcTime) {
    final declination = getSolarDeclination(utcTime);

    // Equation of time (approximated)
    final dayOfYear = utcTime.difference(DateTime(utcTime.year, 1, 1)).inDays + 1;
    final b = (2 * pi / 364) * (dayOfYear - 81);
    final eqTime = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b); // minutes

    // Calculate True Solar Time (TST) in minutes
    final solarTimeMin = (utcTime.hour * 60 + utcTime.minute) + (longitude * 4) + eqTime;
    
    // Hour angle in degrees
    final hourAngle = (solarTimeMin / 4) - 180;
    
    // Convert to radians
    final latRad = latitude * pi / 180;
    final hRad = hourAngle * pi / 180;

    // Zenith angle
    final cosZenith = sin(latRad) * sin(declination) +
        cos(latRad) * cos(declination) * cos(hRad);

    // Normalize to an illumination factor with a smooth twilight gradient.
    // > 0 is Day, between -0.1 and 0 is twilight (civil to nautical).
    if (cosZenith >= 0) {
      return 1.0; 
    } else if (cosZenith > -0.20) {
      // Smooth interpolation for twilight (-0.20 to 0.0)
      return (cosZenith + 0.20) / 0.20;
    } else {
      return 0.0; // Night
    }
  }
}
