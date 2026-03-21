import 'dart:math';

/// Level-of-Detail manager for map icon rendering.
///
/// Rules:
/// 1. At max zoom-out: ALL icons are equal-size colored dots (uniform)
/// 2. As zoom increases: dots stay the same until the icon's WAC-based
///    threshold is reached, then transition to full rectangle + slogan
/// 3. An invisible center point determines visibility - when it leaves
///    the screen, the icon disappears
/// 4. Even a 100m² area campaign becomes visible at sufficient zoom
class LodManager {
  static const double gridLineThreshold = 4.0;
  static const double heatmapThreshold = 0.1;

  // All icons render as this uniform dot size when zoomed out
  static const double _uniformDotSize = 10.0;

  static bool shouldDrawGridLines(double currentZoom) {
    return currentZoom >= gridLineThreshold;
  }

  static bool shouldDrawHeatmap(double currentZoom) {
    return currentZoom <= heatmapThreshold;
  }

  /// All icons have the same opacity at low zoom; higher WAC = visible earlier
  static double opacityForWac(double wacSize, double zoom) {
    // At very low zoom, large WAC icons are slightly more visible
    if (zoom < 3.0) {
      if (wacSize >= 500) return 1.0;
      if (wacSize >= 100) return 0.9;
      if (wacSize >= 10) return 0.75;
      return 0.6;
    }
    return 1.0;
  }

  /// The zoom level at which this icon transitions from dot to full detail.
  /// Larger WAC = transitions earlier (at lower zoom).
  /// Tiny campaigns need very high zoom to become visible as rectangles.
  static double zoomForFullDetail(double wacSize) {
    if (wacSize >= 1000) return 3.0;
    if (wacSize >= 500) return 4.0;
    if (wacSize >= 100) return 6.0;
    if (wacSize >= 25) return 8.0;
    if (wacSize >= 5) return 10.0;
    if (wacSize >= 1) return 13.0;
    return 15.0; // Even tiny campaigns visible at very high zoom
  }

  /// Transition starts 2 zoom levels before full detail
  static double zoomForTransition(double wacSize) {
    return zoomForFullDetail(wacSize) - 2.0;
  }

  /// Dot size: uniform at low zoom, grows during transition
  static double dotSizeAtZoom(double zoom, double wacSize) {
    final transZoom = zoomForTransition(wacSize);
    // Below transition: uniform dot for ALL icons
    if (zoom < transZoom) return _uniformDotSize;
    // During transition: grow from dot to full marker
    final fullZoom = zoomForFullDetail(wacSize);
    final t = ((zoom - transZoom) / (fullZoom - transZoom)).clamp(0.0, 1.0);
    return _uniformDotSize + (16.0 - _uniformDotSize) * t;
  }

  /// Whether to show full detail (rectangle + slogan)
  static bool isFullDetail(double zoom, double wacSize) {
    return zoom >= zoomForFullDetail(wacSize);
  }

  /// Whether in the transition zone (dot growing)
  static bool isTransitioning(double zoom, double wacSize) {
    return zoom >= zoomForTransition(wacSize) && zoom < zoomForFullDetail(wacSize);
  }

  /// Rectangle width for full-detail mode
  static double rectWidth(double wacSize, double zoom) {
    final base = 30.0 + (log(wacSize.clamp(1, 10000)) / ln10) * 12.0;
    final fullZoom = zoomForFullDetail(wacSize);
    final extra = (zoom - fullZoom).clamp(0.0, 6.0) * 4.0;
    return base + extra;
  }

  /// Rectangle height (2:3 ratio)
  static double rectHeight(double wacSize, double zoom) {
    return rectWidth(wacSize, zoom) * (2.0 / 3.0);
  }

  /// Slogan font size scales with zoom beyond full detail
  static double sloganFontSize(double wacSize, double zoom) {
    final fullZoom = zoomForFullDetail(wacSize);
    final extra = (zoom - fullZoom).clamp(0.0, 6.0);
    return 9.0 + extra * 1.0;
  }

  /// Focus zoom: enough to see the icon's slogan clearly
  static double focusZoom(double wacSize) {
    return zoomForFullDetail(wacSize) + 1.0;
  }

  // ─── User icon LOD (non-campaign members) ──────────────────────────────────
  // User icons: colored dots, 1/10 of campaign icon size at that zoom level
  //   - zoom < 7:  ~3px dot (campaigns are ~30px rect → 1/10 ≈ 3px)
  //   - zoom 7-10: grow 3→5px
  //   - zoom 10-13: grow 5→8px
  //   - zoom >= 13: full detail (small rect)
  //   - Own icon: ALWAYS visible at any zoom

  /// Dot size for user (non-campaign) icons — ~1/10 of campaign icon at same zoom
  static double userDotSize(double zoom) {
    if (zoom < 7.0) return 3.0;
    if (zoom < 10.0) {
      final t = ((zoom - 7.0) / 3.0).clamp(0.0, 1.0);
      return 3.0 + 2.0 * t; // 3→5
    }
    final t = ((zoom - 10.0) / 3.0).clamp(0.0, 1.0);
    return 5.0 + 3.0 * t; // 5→8
  }

  /// Whether a user icon should show full detail (cities zoom)
  static bool isUserFullDetail(double zoom) {
    return zoom >= 13.0;
  }

  /// Opacity for user icons — fades at very low zoom
  static double userOpacity(double zoom, bool isMyIcon) {
    if (isMyIcon) return 1.0;
    if (zoom < 3.0) return 0.0;  // Very low zoom: hide
    if (zoom < 5.0) return 0.3;  // Countries: faint
    if (zoom < 8.0) return 0.6;  // Regions: visible
    return 1.0;                   // Cities+: full
  }

  /// Whether a user icon should be rendered at all
  static bool shouldRenderUser(double zoom, bool isMyIcon) {
    if (isMyIcon) return true;
    return zoom >= 3.0;
  }
}
