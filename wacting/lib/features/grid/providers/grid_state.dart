import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/constants.dart';

class ViewportState extends Equatable {
  final Offset position; // Top-left position in logical grid coordinates (0 to GridWidth)
  final double zoom;     // 1.0 = normal, <1 = zoomed out
  final Size screenSize; // Logical pixel size of the screen device

  const ViewportState({
    this.position = const Offset(GridConstants.gridWidth / 2, GridConstants.gridHeight / 2),
    this.zoom = 1.0,
    this.screenSize = Size.zero,
  });

  ViewportState copyWith({
    Offset? position,
    double? zoom,
    Size? screenSize,
  }) {
    return ViewportState(
      position: position ?? this.position,
      zoom: zoom ?? this.zoom,
      screenSize: screenSize ?? this.screenSize,
    );
  }

  Rect get visibleWorldBounds {
    if (screenSize == Size.zero) return Rect.zero;
    final widthInWorldUnits = screenSize.width / zoom;
    final heightInWorldUnits = screenSize.height / zoom;
    return Rect.fromLTWH(position.dx, position.dy, widthInWorldUnits, heightInWorldUnits);
  }

  @override
  List<Object?> get props => [position, zoom, screenSize];
}

class ViewportNotifier extends StateNotifier<ViewportState> {
  ViewportNotifier() : super(const ViewportState());

  void setScreenSize(Size size) {
    if (state.screenSize != size) {
      state = state.copyWith(screenSize: size);
    }
  }

  void updateViewport({Offset? newPosition, double? newZoom}) {
    // Implement bounds clamping (Toroidal/Infinite wrapping can be implemented later)
    double z = newZoom ?? state.zoom;
    // Prevent zooming out too far or in too close
    z = z.clamp(0.005, 10.0);

    Offset p = newPosition ?? state.position;
    // Clamp to map boundaries if not wrapping
    p = Offset(
      p.dx.clamp(0.0, GridConstants.gridWidth.toDouble()),
      p.dy.clamp(0.0, GridConstants.gridHeight.toDouble()),
    );

    state = state.copyWith(position: p, zoom: z);
  }

  void translate(Offset deltaLogs) {
    updateViewport(newPosition: state.position + deltaLogs);
  }
}

final viewportProvider = StateNotifierProvider<ViewportNotifier, ViewportState>((ref) {
  return ViewportNotifier();
});
