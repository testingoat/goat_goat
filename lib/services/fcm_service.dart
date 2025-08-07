import 'fcm_interface.dart';
import 'fcm_mobile.dart' if (dart.library.html) 'fcm_web.dart';

/// Firebase Cloud Messaging Service for Goat Goat
///
/// Interface-based implementation that uses platform-specific implementations:
/// - Mobile: Real Firebase Cloud Messaging
/// - Web: Stub implementation for compilation compatibility
///
/// Features:
/// - Device token management and storage
/// - Foreground and background notification handling
/// - Deep linking capabilities
/// - Topic subscription management
/// - Zero-risk implementation with feature flags
/// - 100% backward compatibility with existing SMS system
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Platform-specific implementation
  final FCMInterface _impl = FCMImplementation();

  // Getters for external access
  bool get isInitialized => _isInitialized;
  bool _isInitialized = false;

  /// Initialize FCM service with zero-risk pattern
  Future<bool> initialize({
    Function(Map<String, dynamic>)? onNotificationTapped,
  }) async {
    if (_isInitialized) return true;

    final result = await _impl.initialize(
      onNotificationTapped: onNotificationTapped,
    );

    if (result) {
      _isInitialized = true;
    }

    return result;
  }

  /// Subscribe to a specific topic
  Future<bool> subscribeToTopic(String topic) async {
    return await _impl.subscribeToTopic(topic);
  }

  /// Unsubscribe from a specific topic
  Future<bool> unsubscribeFromTopic(String topic) async {
    return await _impl.unsubscribeFromTopic(topic);
  }

  /// Get current notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _impl.getNotificationSettings();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    return await _impl.areNotificationsEnabled();
  }

  /// Get detailed diagnostics information
  Future<Map<String, dynamic>> getDiagnostics() async {
    return await _impl.getDiagnostics();
  }

  /// Show local notification (appears in system notification panel)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    return await _impl.showLocalNotification(
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Store FCM token for a specific seller (call this after seller login)
  Future<bool> storeTokenForSeller(String sellerId) async {
    return await _impl.storeTokenForSeller(sellerId);
  }
}

/// Background message handler (must be top-level function)
/// This is a stub for web compatibility - real implementation is in fcm_mobile.dart
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {
  // No-op on web, real implementation on mobile
}
