// Stub implementation for FCM Service on web
// This prevents import errors when building for web

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  Future<bool> initialize() async => false;
  bool get isInitialized => false;
  String? get fcmToken => null;
}
