class LodManager {
  /// Defines rendering thresholds based on the current zoom level.
  
  // Cutoff for drawing individual grid cell borders. Below this, lines are too dense.
  static const double gridLineThreshold = 4.0; 
  
  // Cutoff for showing normal icons (size < 10)
  static const double normalIconThreshold = 0.5;
  
  // Cutoff for showing small/medium icons. Below this zoom, only giants (size >= 1000) are drawn.
  static const double giantIconOnlyThreshold = 0.01;
  
  // Threshold to start blending in the heatmap density overlay layer
  static const double heatmapThreshold = 0.1;

  static bool shouldDrawGridLines(double currentZoom) {
    return currentZoom >= gridLineThreshold;
  }

  static bool shouldDrawMicroIcons(double currentZoom) {
    return currentZoom >= normalIconThreshold;
  }

  static bool shouldDrawHeatmap(double currentZoom) {
    return currentZoom <= heatmapThreshold;
  }
  
  static bool shouldDrawGiantsOnly(double currentZoom) {
    return currentZoom < giantIconOnlyThreshold;
  }
}
