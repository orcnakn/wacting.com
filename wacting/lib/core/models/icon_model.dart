import 'dart:ui';
import 'package:equatable/equatable.dart';

class IconModel extends Equatable {
  final String id;
  final String userId;
  final Offset position;
  final double size;
  final Color color;
  final int shapeIndex; // 0=circle, 1=diamond, 2=hexagon
  final double speed;
  final int followerCount;
  final int exploreMode; // 0=City, 1=Country, 2=World
  
  const IconModel({
    required this.id,
    required this.userId,
    required this.position,
    required this.size,
    required this.color,
    required this.shapeIndex,
    required this.speed,
    required this.followerCount,
    this.exploreMode = 0,
  });

  bool get isMicro => size < 5.0;
  bool get isSmall => size >= 5.0 && size < 25.0;
  bool get isMedium => size >= 25.0 && size < 100.0;
  bool get isLarge => size >= 100.0 && size < 500.0;
  bool get isGiant => size >= 500.0;

  @override
  List<Object?> get props => [
        id,
        userId,
        position,
        size,
        color,
        shapeIndex,
        speed,
        followerCount,
        exploreMode,
      ];
}
