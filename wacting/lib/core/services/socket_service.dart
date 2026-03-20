import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '../models/icon_model.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../../features/grid/providers/grid_state.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ── Speed formula ─────────────────────────────────────────────────────────────
// 1x = 1000 km/s (max). Each 0.1x decrease adds 1 second.
// seconds_per_1000km = 1 + (1 - speed) * 10
// At 1x: 1s, 0.6x: 5s, 0.2x: 9s, 0x: stationary
// Earth circumference ≈ 40075 km, grid 715 px → 1 px ≈ 56.05 km
// Mock grid is 510 px wide, scale accordingly
const double _mockGridWidth = 510.0;
const double _earthCircKm = 40075.0;
const double _kmPerMockPixel = _earthCircKm / _mockGridWidth; // ≈ 78.6

double _campaignStep(double speed) {
  if (speed <= 0) return 0;
  final secondsPer1000km = 1 + (1 - speed) * 10;
  return (1000 / _kmPerMockPixel) / secondsPer1000km; // pixels per second
}
// ─────────────────────────────────────────────────────────────────────────────

class SocketService {
  final _iconStreamController = StreamController<List<IconModel>>.broadcast();
  Stream<List<IconModel>> get iconStream => _iconStreamController.stream;
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationController.stream;
  Timer? _mockPhysicsTimer;
  List<IconModel> _mockIcons = [];
  IO.Socket? _socket;

  void connect(String serverUrl) {
    if (AppConfig.isProduction) {
      _connectProduction(serverUrl);
    } else {
      _connectMock();
    }
  }

  // ─── PRODUCTION MODE ────────────────────────────────────────────────────────
  void _connectProduction(String serverUrl) {
    final token = apiService.token;

    _socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      if (token != null) 'auth': {'token': token},
    });

    _socket!.on('tick', (data) {
      try {
        final icons = (data as List)
            .map((d) => IconModel.fromJson(d as Map<String, dynamic>))
            .toList();
        _iconStreamController.add(icons);
      } catch (e) {
        print('[SOCKET] Error parsing tick: $e');
      }
    });

    _socket!.on('notification', (data) {
      try {
        _notificationController.add(data as Map<String, dynamic>);
      } catch (e) {
        print('[SOCKET] Error parsing notification: $e');
      }
    });

    _socket!.on('connect', (_) {
      print('[PRODUCTION] Socket connected to $serverUrl');
    });

    _socket!.on('connect_error', (err) {
      print('[PRODUCTION] Socket connection error: $err');
    });

    _socket!.connect();
  }

  // ─── DEVELOPMENT / MOCK MODE ────────────────────────────────────────────────
  void _connectMock() {
    print('[DEV] Mock Mode: Initializing Local Physics Engine (${AppConfig.apiBaseUrl})');
    final rand = Random();

    // Campaign colors and slogans for mock icons to demonstrate campaign display
    final List<Color> mockCampaignColors = [
      const Color(0xFF2196F3), const Color(0xFF4CAF50), const Color(0xFFFF9800),
      const Color(0xFFE91E63), const Color(0xFF9C27B0), const Color(0xFF00BCD4),
      const Color(0xFFFF5722), const Color(0xFF607D8B),
    ];
    final List<String> mockSlogans = [
      'Daha iyi bir dünya', 'Birlikte güçlüyüz', 'Değişim zamanı',
      'Haklarımız için', 'Geleceğe yatırım', 'Özgürlük herkese',
      'Barış ve adalet', 'Çevre için mücadele',
    ];

    for (int i = 0; i < 100; i++) {
      final int campIdx = i % mockCampaignColors.length;
      _mockIcons.add(IconModel(
        id: 'mock_$i',
        userId: 'user_$i',
        position: Offset(rand.nextDouble() * 510, rand.nextDouble() * 510),
        size: rand.nextDouble() * 3 + 1,
        color: Color((rand.nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0),
        shapeIndex: 0,
        speed: rand.nextDouble() * 10 + 2,
        followerCount: rand.nextInt(500),
        exploreMode: rand.nextInt(3),
        campaignSpeed: 0.5,  // all mocks start at default (75% of mock_95 speed)
        campaignColor: mockCampaignColors[campIdx],
        campaignSlogan: mockSlogans[campIdx],
      ));
    }

    _mockPhysicsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final List<IconModel> moved = [];
      for (var icon in _mockIcons) {
        // New km-based speed: 1x=1000km/s, 0=stationary
        final double step = _campaignStep(icon.campaignSpeed);

        double nx = icon.position.dx + (rand.nextDouble() - 0.5) * step;
        double ny = icon.position.dy + (rand.nextDouble() - 0.5) * step;

        if (nx < 0) nx += 510;
        if (nx > 510) nx -= 510;
        if (ny < 0) ny += 510;
        if (ny > 510) ny -= 510;

        moved.add(IconModel(
          id: icon.id,
          userId: icon.userId,
          size: icon.size,
          color: icon.color,
          shapeIndex: icon.shapeIndex,
          speed: icon.speed,
          followerCount: icon.followerCount,
          exploreMode: icon.exploreMode,
          campaignSpeed: icon.campaignSpeed,
          campaignColor: icon.campaignColor,
          campaignSlogan: icon.campaignSlogan,
          position: Offset(nx, ny),
        ));
      }
      _mockIcons = moved;
      _iconStreamController.add(_mockIcons);
    });
  }

  void updateViewportSubscription(ViewportState viewport) {
    if (_socket == null || !(_socket!.connected)) return;
    // Map screen bounds to world coordinate space (0-510)
    final minX = viewport.position.dx;
    final minY = viewport.position.dy;
    final maxX = minX + viewport.screenSize.width / viewport.zoom;
    final maxY = minY + viewport.screenSize.height / viewport.zoom;
    _socket!.emit('join_viewport', {'minX': minX, 'minY': minY, 'maxX': maxX, 'maxY': maxY});
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _mockPhysicsTimer?.cancel();
    _iconStreamController.close();
    _notificationController.close();
  }
}

final socketService = SocketService();
