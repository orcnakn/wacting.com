import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '../models/icon_model.dart';
import '../config/app_config.dart';
import '../../features/grid/providers/grid_state.dart';

// Production: socket_io_client
// ignore: depend_on_referenced_packages
// import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  final _iconStreamController = StreamController<List<IconModel>>.broadcast();
  Stream<List<IconModel>> get iconStream => _iconStreamController.stream;
  Timer? _mockPhysicsTimer;
  List<IconModel> _mockIcons = [];

  void connect(String serverUrl) {
    if (AppConfig.isProduction) {
      _connectProduction(serverUrl);
    } else {
      _connectMock();
    }
  }

  // ─── PRODUCTION MODE ────────────────────────────────────────────────────────
  void _connectProduction(String serverUrl) {
    // Production socket.io connection to wacting-server
    // Uses the real Brownian physics engine running on the VDS
    //
    // Uncomment when deploying to production:
    //
    // final socket = IO.io(serverUrl, <String, dynamic>{
    //   'transports': ['websocket'],
    //   'autoConnect': true,
    // });
    //
    // socket.on('icons', (data) {
    //   final icons = (data as List).map((d) => IconModel.fromJson(d)).toList();
    //   _iconStreamController.add(icons);
    // });
    //
    // socket.connect();
    print('[PRODUCTION] Socket connecting to $serverUrl');
    _connectMock(); // Fallback to mock until socket_io_client is activated
  }

  // ─── DEVELOPMENT / MOCK MODE ────────────────────────────────────────────────
  void _connectMock() {
    print('[DEV] Mock Mode: Initializing Local Physics Engine (${AppConfig.apiBaseUrl})');
    final rand = Random();

    for (int i = 0; i < 100; i++) {
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
      ));
    }

    _mockPhysicsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final List<IconModel> moved = [];
      for (var icon in _mockIcons) {
        double stepSize;
        if (icon.exploreMode == 0) {
          stepSize = 0.5;
        } else if (icon.exploreMode == 1) {
          stepSize = 2.0;
        } else {
          stepSize = 10.0;
        }

        double nx = icon.position.dx + (rand.nextDouble() - 0.5) * stepSize;
        double ny = icon.position.dy + (rand.nextDouble() - 0.5) * stepSize;

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
          position: Offset(nx, ny),
        ));
      }
      _mockIcons = moved;
      _iconStreamController.add(_mockIcons);
    });
  }

  void updateViewportSubscription(ViewportState viewport) {}

  void dispose() {
    _mockPhysicsTimer?.cancel();
    _iconStreamController.close();
  }
}

final socketService = SocketService();
