class NotificationService {
  Future<void> initialize() async {
    print('Mock push notifications initialized for Web');
  }

  void _registerTokenWithBackend(String token) {
     print("FCM Token registered: $token");
  }
}

final notificationService = NotificationService();
