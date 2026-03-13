import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '../models/icon_model.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../../features/grid/providers/grid_state.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

// ── Reference speed constants ─────────────────────────────────────────────────
// mock_95 base step sizes per explore mode (the reference = 100% speed)
const double _mock95BaseStepCity    = 0.5;   // City mode
const double _mock95BaseStepCountry = 2.0;   // Country mode
const double _mock95BaseStepWorld   = 10.0;  // World mode

// campaignSpeed=0.5 → 75% of mock_95 step; formula: speedMult = (cSpeed/0.5)*0.75
double _effectiveStep(double mock95BaseStep, double campaignSpeed) {
  return mock95BaseStep * (campaignSpeed / 0.5) * 0.75;
}
// ─────────────────────────────────────────────────────────────────────────────

class SocketService {
  final _iconStreamController = StreamController<List<IconModel>>.broadcast();
  Stream<List<IconModel>> get iconStream => _iconStreamController.stream;
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
        // Base step for this icon's explore mode (mock_95 reference speed)
        final double baseStep = icon.exploreMode == 0
            ? _mock95BaseStepCity
            : icon.exploreMode == 1
                ? _mock95BaseStepCountry
                : _mock95BaseStepWorld;

        // Apply campaign speed: 0.5 → 75% of mock_95, 0 → stationary
        final double step = _effectiveStep(baseStep, icon.campaignSpeed);

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

  void updateViewportSubscription(ViewportState viewport) {}

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _mockPhysicsTimer?.cancel();
    _iconStreamController.close();
  }
}

final socketService = SocketService();
