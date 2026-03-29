import 'dart:math';

/// Level-of-Detail manager for map icon rendering.
///
/// Campaign visibility is driven by the level system:
///   level = followerLevel + yearLevel + wacLevel
///   Physical size: baseValue = level^2 * sqrt(level)
///     width_m = baseValue * 2, height_m = baseValue  (2:1 aspect ratio)
///
/// Dynamic render limits (pixel-based):
///   > 100px width  → polygon locked to 100×50px
///   10–100px width → render at true projected size
///   < 10px width   → replace polygon with fixed-size dot icon
///
/// Higher level campaigns are visible at lower zoom levels,
/// creating a natural visibility hierarchy on the map.
class LodManager {
  static const double gridLineThreshold = 4.0;
  static const double heatmapThreshold = 0.1;

  // Pixel clamp limits for campaign signs
  static const double _maxWidthPx = 100.0;
  static const double _minWidthPx = 10.0;
  /// Dot radius for campaigns below the 10px threshold.
  static const double dotRadius = 4.0;

  static bool shouldDrawGridLines(double currentZoom) {
    return currentZoom >= gridLineThreshold;
  }

  static bool shouldDrawHeatmap(double currentZoom) {
    return currentZoom <= heatmapThreshold;
  }

  // ─── Web Mercator projection ──────────────────────────────────────────────

  /// Pixels per meter at a given latitude and map zoom level.
  /// Based on 256px tile system: resolution = cos(lat) * 2π * R / (256 * 2^zoom)
  static double pixelsPerMeter(double latDegrees, double mapZoom) {
    final latRad = latDegrees * pi / 180.0;
    final metersPerPixel =
        (cos(latRad) * 2 * pi * 6378137) / (256 * pow(2, mapZoom));
    return 1.0 / metersPerPixel;
  }

  /// Convert physical meters to screen pixels at given lat/zoom.
  static double metersToPixels(
      double meters, double latDegrees, double mapZoom) {
    return meters * pixelsPerMeter(latDegrees, mapZoom);
  }

  // ─── Campaign sign rendering ──────────────────────────────────────────────

  /// Whether the campaign sign should render as a full polygon (tabela)
  /// vs a dot icon. Returns true if widthPx >= 10.
  static bool isFullDetail(
      double widthMeters, double latDegrees, double mapZoom) {
    if (widthMeters <= 0) return false;
    final px = metersToPixels(widthMeters, latDegrees, mapZoom);
    return px >= _minWidthPx;
  }

  /// Get the clamped rendered width in pixels.
  /// Returns null if below the 10px threshold (render as dot instead).
  static double? renderWidthPx(
      double widthMeters, double latDegrees, double mapZoom) {
    if (widthMeters <= 0) return null;
    final px = metersToPixels(widthMeters, latDegrees, mapZoom);
    if (px < _minWidthPx) return null;
    return px.clamp(_minWidthPx, _maxWidthPx);
  }

  /// Get the clamped rendered height in pixels (always width / 2 for 2:1 ratio).
  static double? renderHeightPx(
      double widthMeters, double latDegrees, double mapZoom) {
    final w = renderWidthPx(widthMeters, latDegrees, mapZoom);
    if (w == null) return null;
    return w / 2.0;
  }

  /// Minimum zoom level where this campaign first becomes visible as a dot (~1px).
  /// Higher level = lower minZoom = visible earlier when zooming out.
  static double minVisibleZoom(double widthMeters, double latDegrees) {
    if (widthMeters <= 0) return 22.0; // Never visible
    // Solve: widthMeters * pixelsPerMeter(lat, zoom) >= 1.0
    // → 256 * 2^zoom / (cos(lat) * 2π * R) * widthMeters >= 1
    // → 2^zoom >= cos(lat) * 2π * R / (256 * widthMeters)
    // → zoom >= log2(cos(lat) * 2π * R / (256 * widthMeters))
    final latRad = latDegrees * pi / 180.0;
    final ratio = (cos(latRad) * 2 * pi * 6378137) / (256 * widthMeters);
    if (ratio <= 0) return 0.0;
    return (log(ratio) / ln2).clamp(0.0, 22.0);
  }

  /// Minimum zoom level where this campaign shows as full polygon (≥10px).
  static double minFullDetailZoom(double widthMeters, double latDegrees) {
    if (widthMeters <= 0) return 22.0;
    // Solve: widthMeters * ppm >= 10
    final latRad = latDegrees * pi / 180.0;
    final ratio =
        (cos(latRad) * 2 * pi * 6378137) / (256 * widthMeters) * _minWidthPx;
    if (ratio <= 0) return 0.0;
    return (log(ratio) / ln2).clamp(0.0, 22.0);
  }

  /// Opacity for campaign icons — higher levels more visible at low zoom.
  static double campaignOpacity(
      double level, double widthMeters, double latDegrees, double mapZoom) {
    if (widthMeters <= 0) return 0.0;
    final minZoom = minVisibleZoom(widthMeters, latDegrees);
    if (mapZoom < minZoom) return 0.0;
    // Fade in over 1 zoom level
    final fadeIn = ((mapZoom - minZoom) / 1.0).clamp(0.0, 1.0);
    return fadeIn;
  }

  /// Slogan font size — scales with rendered width.
  static double sloganFontSize(double renderedWidthPx) {
    return (renderedWidthPx * 0.14).clamp(8.0, 14.0);
  }

  /// Focus zoom: enough to see the campaign as a full polygon.
  static double focusZoom(double widthMeters, double latDegrees) {
    return minFullDetailZoom(widthMeters, latDegrees) + 1.0;
  }

  // ─── User icon LOD (non-campaign members) ─────────────────────────────────
  // Unchanged from previous system.

  static double userDotSize(double zoom) {
    if (zoom < 3.0) return 2.0;
    if (zoom < 5.0) return 2.5;
    if (zoom < 7.0) return 3.0;
    if (zoom < 10.0) {
      final t = ((zoom - 7.0) / 3.0).clamp(0.0, 1.0);
      return 3.0 + 2.0 * t;
    }
    final t = ((zoom - 10.0) / 3.0).clamp(0.0, 1.0);
    return 5.0 + 3.0 * t;
  }

  static bool isUserFullDetail(double zoom) {
    return zoom >= 13.0;
  }

  static double userOpacity(double zoom, bool isMyIcon) {
    if (isMyIcon) return 1.0;
    if (zoom < 2.0) return 0.4;
    if (zoom < 3.0) return 0.5;
    if (zoom < 5.0) return 0.6;
    if (zoom < 8.0) return 0.75;
    return 1.0;
  }

  static bool shouldRenderUser(double zoom, bool isMyIcon) {
    return true;
  }
}
