import 'dart:async';
import 'dart:math';
import 'dart:ui';
import '../models/icon_model.dart';
import '../../features/grid/providers/grid_state.dart';

class SocketService {
  final _iconStreamController = StreamController<List<IconModel>>.broadcast();
  Stream<List<IconModel>> get iconStream => _iconStreamController.stream;
  Timer? _mockPhysicsTimer;
  List<IconModel> _mockIcons = [];

  void connect(String serverUrl) {
    print('Mock Mode: Initializing Local Physics Engine');
    final rand = Random();
    
    // Generate 100 fake players 
    for(int i = 0; i < 100; i++) {
        _mockIcons.add(IconModel(
            id: 'mock_$i',
            userId: 'user_$i',
            position: Offset(rand.nextDouble() * 510, rand.nextDouble() * 510),
            size: rand.nextDouble() * 3 + 1,
            color: Color((rand.nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0),
            shapeIndex: 0,
            speed: rand.nextDouble() * 10 + 2,
            followerCount: rand.nextInt(500),
            exploreMode: rand.nextInt(3), // 0=City, 1=Country, 2=World
        ));
    }

    // Movement per 1 second
    _mockPhysicsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final List<IconModel> moved = [];
        for(var icon in _mockIcons) {
             // 0=City, 1=Country, 2=World
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
             
             // Toroidal Wrap
             if(nx < 0) nx += 510;
             if(nx > 510) nx -= 510;
             if(ny < 0) ny += 510;
             if(ny > 510) ny -= 510;
             
             moved.add(IconModel(
                id: icon.id,
                userId: icon.userId,
                size: icon.size,
                color: icon.color,
                shapeIndex: icon.shapeIndex,
                speed: icon.speed,
                followerCount: icon.followerCount,
                exploreMode: icon.exploreMode,
                position: Offset(nx, ny)
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
