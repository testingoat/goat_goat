/// FCM Interface
/// Abstract interface for Firebase Cloud Messaging functionality
/// Enables platform-specific implementations (mobile vs web)
abstract class FCMInterface {
  /// Initialize FCM service with zero-risk pattern
  Future<bool> initialize({
    Function(Map<String, dynamic>)? onNotificationTapped,
  });

  /// Subscribe to a specific topic
  Future<bool> subscribeToTopic(String topic);

  /// Unsubscribe from a specific topic
  Future<bool> unsubscribeFromTopic(String topic);

  /// Get current notification settings
  Future<NotificationSettings> getNotificationSettings();

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled();

  /// Get detailed diagnostics information
  Future<Map<String, dynamic>> getDiagnostics();

  /// Show local notification (appears in system notification panel)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  });

  /// Store FCM token for a specific seller (call this after seller login)
  Future<bool> storeTokenForSeller(String sellerId);
}

/// Notification Settings interface
/// Platform-agnostic representation of notification permissions
abstract class NotificationSettings {
  AuthorizationStatus get authorizationStatus;
}

/// Authorization Status enum
/// Platform-agnostic representation of notification authorization
enum AuthorizationStatus { 
  denied, 
  authorized, 
  provisional 
}
