import 'package:flutter/foundation.dart';
import 'fcm_interface.dart';

/// Web implementation of FCM using stub methods
/// This provides no-op implementations for web builds where Firebase Messaging
/// is not available or causes compilation issues
class FCMImplementation implements FCMInterface {
  static final FCMImplementation _instance = FCMImplementation._internal();
  factory FCMImplementation() => _instance;
  FCMImplementation._internal();

  bool _isInitialized = false;

  @override
  Future<bool> initialize({
    Function(Map<String, dynamic>)? onNotificationTapped,
  }) async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - initialize() called');
    }
    _isInitialized = true;
    return true;
  }

  @override
  Future<bool> subscribeToTopic(String topic) async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - subscribeToTopic($topic) called');
    }
    return true;
  }

  @override
  Future<bool> unsubscribeFromTopic(String topic) async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - unsubscribeFromTopic($topic) called');
    }
    return true;
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - getNotificationSettings() called');
    }
    return _WebNotificationSettings();
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - areNotificationsEnabled() called');
    }
    return false; // Web doesn't support FCM notifications in this build
  }

  @override
  Future<Map<String, dynamic>> getDiagnostics() async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - getDiagnostics() called');
    }
    
    return {
      'is_initialized': _isInitialized,
      'platform': 'web',
      'fcm_enabled': false,
      'token_storage_enabled': false,
      'topic_subscriptions_enabled': false,
      'has_token': false,
      'token_length': 0,
      'notification_status': 'denied',
      'notifications_enabled': false,
      'implementation': 'web_stub',
    };
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - showLocalNotification($title, $body) called');
      print('🔔 FCM: Web notifications not supported in this build');
    }
    // No-op on web
  }

  @override
  Future<bool> storeTokenForSeller(String sellerId) async {
    if (kDebugMode) {
      print('🔔 FCM: Web stub - storeTokenForSeller($sellerId) called');
    }
    return true; // Return success but do nothing
  }
}

/// Web implementation of NotificationSettings
class _WebNotificationSettings implements NotificationSettings {
  @override
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.denied;
}
