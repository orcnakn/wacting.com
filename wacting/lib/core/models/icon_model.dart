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

  // Campaign data — used for map icon rendering and movement speed
  final double campaignSpeed;   // 0-1: 1x=1000km/s, 0.6x=5s/1000km, 0=stationary
  final String? campaignSlogan; // Slogan displayed on icon at high zoom
  final Color? campaignColor;   // Campaign icon color (overrides user color on map)
  final bool isCampaignLeader;  // true if this user is the campaign leader
  final double? pinnedLat;      // Campaign leader pinned latitude
  final double? pinnedLng;      // Campaign leader pinned longitude
  final bool isEmergency;       // Emergency campaign flag (red + radio wave)
  final double emergencyAreaM2; // Emergency logo area in m²
  final String? stanceType;    // SUPPORT | REFORM | PROTEST | EMERGENCY
  final String? campaignId;    // Campaign ID for detail lookups
  // Level system — drives visibility hierarchy on the map
  final double level;          // Total campaign level (follower + year + WAC)
  final double widthMeters;    // Physical sign width in meters
  final double heightMeters;   // Physical sign height in meters
  final int profileLevel;      // User's cached profile level (for map z-order)
  final bool isPrivate;        // Whether the user's profile is private

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
    this.campaignSpeed = 0.5,
    this.campaignSlogan,
    this.campaignColor,
    this.isCampaignLeader = false,
    this.pinnedLat,
    this.pinnedLng,
    this.isEmergency = false,
    this.emergencyAreaM2 = 0,
    this.stanceType,
    this.campaignId,
    this.level = 0,
    this.widthMeters = 0,
    this.heightMeters = 0,
    this.profileLevel = 1,
    this.isPrivate = false,
  });

  factory IconModel.fromJson(Map<String, dynamic> json) {
    Color? parsedCampaignColor;
    final rawCampColor = json['campaignColor'] as String?;
    if (rawCampColor != null && rawCampColor.startsWith('#') && rawCampColor.length == 7) {
      final hex = rawCampColor.replaceAll('#', '');
      parsedCampaignColor = Color(int.parse('FF$hex', radix: 16));
    }

    return IconModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      position: Offset(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      size: (json['size'] as num).toDouble(),
      color: const Color(0xFF2196F3),
      shapeIndex: 0,
      speed: (json['baseSpeed'] as num?)?.toDouble() ?? 1.0,
      followerCount: 0,
      exploreMode: (json['exploreMode'] as num?)?.toInt() ?? 0,
      campaignSpeed: (json['campaignSpeed'] as num?)?.toDouble() ?? 0.5,
      campaignSlogan: json['campaignSlogan'] as String?,
      campaignColor: parsedCampaignColor,
      isCampaignLeader: json['isCampaignLeader'] as bool? ?? false,
      pinnedLat: (json['pinnedLat'] as num?)?.toDouble(),
      pinnedLng: (json['pinnedLng'] as num?)?.toDouble(),
      isEmergency: json['isEmergency'] as bool? ?? false,
      emergencyAreaM2: (json['emergencyAreaM2'] as num?)?.toDouble() ?? 0,
      stanceType: json['stanceType'] as String?,
      campaignId: json['campaignId'] as String?,
      level: (json['level'] as num?)?.toDouble() ?? 0,
      widthMeters: (json['widthMeters'] as num?)?.toDouble() ?? 0,
      heightMeters: (json['heightMeters'] as num?)?.toDouble() ?? 0,
      profileLevel: (json['profileLevel'] as num?)?.toInt() ?? 1,
      isPrivate: json['isPrivate'] as bool? ?? false,
    );
  }

  bool get isMicro => size < 5.0;
  bool get isSmall => size >= 5.0 && size < 25.0;
  bool get isMedium => size >= 25.0 && size < 100.0;
  bool get isLarge => size >= 100.0 && size < 500.0;
  bool get isGiant => size >= 500.0;

  /// The effective display color: campaign color if available, otherwise user color
  Color get displayColor => campaignColor ?? color;

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
        campaignSpeed,
        campaignSlogan,
        campaignColor,
        isCampaignLeader,
        pinnedLat,
        pinnedLng,
        isEmergency,
        emergencyAreaM2,
        stanceType,
        campaignId,
        level,
        widthMeters,
        heightMeters,
        profileLevel,
        isPrivate,
      ];
}
