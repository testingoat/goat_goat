// Stub implementation for FCM Service on Windows
// This prevents import errors and linker issues when building for Windows

import 'package:flutter/foundation.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  Future<bool> initialize({Function(Map<String, dynamic>)? onNotificationTapped}) async {
    if (kDebugMode) {
      print('🔔 FCM Service: Feature disabled on Windows platform');
    }
    return false;
  }
  
  bool get isInitialized => false;
  String? get fcmToken => null;
  
  Future<bool> subscribeToTopic(String topic) async => false;
  Future<bool> unsubscribeFromTopic(String topic) async => false;
  Future<void> _getFCMToken() async {}
}