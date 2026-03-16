import 'dart:math';

class LodManager {
  static const double gridLineThreshold = 4.0;
  static const double heatmapThreshold = 0.1;

  static const double _baseDotSize = 3.0;
  static const double _maxDotSize = 6.0;
  static bool shouldDrawGridLines(double currentZoom) {
    return currentZoom >= gridLineThreshold;
  }

  static bool shouldDrawHeatmap(double currentZoom) {
    return currentZoom <= heatmapThreshold;
  }

  static double opacityForWac(double wacSize) {
    if (wacSize >= 500) return 1.0;
    if (wacSize >= 100) return 0.85;
    if (wacSize >= 25) return 0.65;
    if (wacSize >= 5) return 0.5;
    return 0.35;
  }

  static double zoomForFullDetail(double wacSize) {
    if (wacSize >= 500) return 4.0;
    if (wacSize >= 100) return 6.0;
    if (wacSize >= 25) return 8.0;
    if (wacSize >= 5) return 10.0;
    return 13.0;
  }

  static double zoomForTransition(double wacSize) {
    return zoomForFullDetail(wacSize) - 2.0;
  }

  static double dotSizeAtZoom(double zoom, double wacSize) {
    final transZoom = zoomForTransition(wacSize);
    if (zoom < transZoom) return _baseDotSize;
    final fullZoom = zoomForFullDetail(wacSize);
    final t = ((zoom - transZoom) / (fullZoom - transZoom)).clamp(0.0, 1.0);
    return _baseDotSize + (_maxDotSize - _baseDotSize) * t;
  }

  static bool isFullDetail(double zoom, double wacSize) {
    return zoom >= zoomForFullDetail(wacSize);
  }

  static bool isTransitioning(double zoom, double wacSize) {
    return zoom >= zoomForTransition(wacSize) && zoom < zoomForFullDetail(wacSize);
  }

  static double rectWidth(double wacSize, double zoom) {
    final base = 20.0 + (log(wacSize.clamp(1, 10000)) / ln10) * 8.0;
    final fullZoom = zoomForFullDetail(wacSize);
    final extra = (zoom - fullZoom).clamp(0.0, 6.0) * 3.0;
    return base + extra;
  }

  static double rectHeight(double wacSize, double zoom) {
    return rectWidth(wacSize, zoom) * (2.0 / 3.0);
  }

  static double sloganFontSize(double wacSize, double zoom) {
    final fullZoom = zoomForFullDetail(wacSize);
    final extra = (zoom - fullZoom).clamp(0.0, 6.0);
    return 7.0 + extra * 0.8;
  }

  static double focusZoom(double wacSize) {
    return zoomForFullDetail(wacSize) + 1.0;
  }
}
