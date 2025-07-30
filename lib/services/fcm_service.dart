import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../supabase_service.dart';

/// Firebase Cloud Messaging Service for Goat Goat
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

  // Firebase Messaging instance
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Feature flags for gradual rollout
  static const bool _enableFCM =
      !kIsWeb; // Disable FCM on web for now due to compatibility issues
  static const bool _enableLocalNotifications = !kIsWeb;
  static const bool _enableTopicSubscriptions = !kIsWeb;
  static const bool _enableDeepLinking = true;
  static const bool _enableTokenStorage = !kIsWeb;

  // Current FCM token
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Initialization status
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Notification callback for deep linking
  Function(Map<String, dynamic>)? _onNotificationTapped;

  /// Initialize FCM service with zero-risk pattern
  Future<bool> initialize({
    Function(Map<String, dynamic>)? onNotificationTapped,
  }) async {
    if (!_enableFCM) {
      if (kDebugMode) {
        print('🔔 FCM Service: Feature disabled by flag');
      }
      return false;
    }

    try {
      if (kDebugMode) {
        print('🔔 FCM Service: Starting initialization...');
      }

      _onNotificationTapped = onNotificationTapped;

      // Request permissions first
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        if (kDebugMode) {
          print('❌ FCM Service: Permissions not granted');
        }
        return false;
      }

      // Initialize local notifications
      if (_enableLocalNotifications) {
        await _initializeLocalNotifications();
      }

      // Get FCM token
      await _getFCMToken();

      // Setup message handlers
      _setupMessageHandlers();

      // Subscribe to default topics
      if (_enableTopicSubscriptions) {
        await _subscribeToDefaultTopics();
      }

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ FCM Service: Initialized successfully');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM Service: Initialization failed - $e');
      }
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    try {
      // Request Firebase Messaging permissions
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        if (kDebugMode) {
          print('✅ FCM: Firebase notification permissions granted');
        }
        return true;
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        if (kDebugMode) {
          print('⚠️ FCM: Provisional notification permissions granted');
        }
        return true;
      } else {
        if (kDebugMode) {
          print('❌ FCM: Notification permissions denied');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Permission request failed - $e');
      }
      return false;
    }
  }

  /// Initialize local notifications for foreground handling
  Future<void> _initializeLocalNotifications() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/ic_notification');

      // iOS initialization settings
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Combined initialization settings
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS,
          );

      // Initialize with callback for notification taps
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'goat_goat_notifications',
        'Goat Goat Notifications',
        description: 'Notifications for Goat Goat app',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);

      if (kDebugMode) {
        print('✅ FCM: Local notifications initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Local notifications initialization failed - $e');
      }
    }
  }

  /// Get and store FCM token
  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();

      if (_fcmToken != null) {
        if (kDebugMode) {
          print('🔑 FCM Token: ${_fcmToken!.substring(0, 20)}...');
        }

        // Store token in Supabase for admin notifications
        if (_enableTokenStorage) {
          await _storeTokenInDatabase();
        }
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode) {
          print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
        }

        if (_enableTokenStorage) {
          _storeTokenInDatabase();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to get token - $e');
      }
    }
  }

  /// Store FCM token in Supabase database
  Future<void> _storeTokenInDatabase() async {
    if (!_enableTokenStorage || _fcmToken == null) return;

    try {
      // TODO: Implement token storage in user profile
      // This will be used by admin panel to send targeted notifications
      // For now, just log the token
      if (kDebugMode) {
        print('📝 FCM: Token ready for database storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to store token in database - $e');
      }
    }
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle app launch from terminated state
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });

    if (kDebugMode) {
      print('✅ FCM: Message handlers configured');
    }
  }

  /// Handle foreground messages by showing local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('📱 FCM: Foreground message received - ${message.messageId}');
      print('   Title: ${message.notification?.title}');
      print('   Body: ${message.notification?.body}');
    }

    // Show local notification for foreground messages
    if (_enableLocalNotifications) {
      await _showLocalNotification(message);
    }
  }

  /// Handle message when app is opened from notification
  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    if (kDebugMode) {
      print('🔗 FCM: Message opened app - ${message.messageId}');
      print('   Data: ${message.data}');
    }

    // Handle deep linking
    if (_enableDeepLinking && _onNotificationTapped != null) {
      _onNotificationTapped!(message.data);
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'goat_goat_notifications',
            'Goat Goat Notifications',
            channelDescription: 'Notifications for Goat Goat app',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@drawable/ic_notification',
            enableVibration: true,
            playSound: true,
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'Goat Goat',
        message.notification?.body ?? 'You have a new notification',
        details,
        payload: message.data.toString(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to show local notification - $e');
      }
    }
  }

  /// Handle local notification tap
  void _onLocalNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('🔔 FCM: Local notification tapped - ${response.payload}');
    }

    // Parse payload and handle deep linking
    if (_enableDeepLinking &&
        _onNotificationTapped != null &&
        response.payload != null) {
      try {
        // TODO: Parse payload and extract data
        final data = <String, dynamic>{'payload': response.payload};
        _onNotificationTapped!(data);
      } catch (e) {
        if (kDebugMode) {
          print('❌ FCM: Failed to parse notification payload - $e');
        }
      }
    }
  }

  /// Subscribe to default topics for broadcast notifications
  Future<void> _subscribeToDefaultTopics() async {
    if (!_enableTopicSubscriptions) return;

    try {
      // Subscribe to general notifications
      await subscribeToTopic('all_users');

      // Subscribe to platform-specific topics
      if (defaultTargetPlatform == TargetPlatform.android) {
        await subscribeToTopic('android_users');
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await subscribeToTopic('ios_users');
      } else {
        await subscribeToTopic('web_users');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to subscribe to default topics - $e');
      }
    }
  }

  /// Subscribe to a specific topic
  Future<bool> subscribeToTopic(String topic) async {
    if (!_enableTopicSubscriptions || !_isInitialized) return false;

    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('✅ FCM: Subscribed to topic - $topic');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to subscribe to topic $topic - $e');
      }
      return false;
    }
  }

  /// Unsubscribe from a specific topic
  Future<bool> unsubscribeFromTopic(String topic) async {
    if (!_enableTopicSubscriptions || !_isInitialized) return false;

    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('✅ FCM: Unsubscribed from topic - $topic');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to unsubscribe from topic $topic - $e');
      }
      return false;
    }
  }

  /// Get current notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _firebaseMessaging.getNotificationSettings();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    print('🔔 FCM: Background message received - ${message.messageId}');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
  }
}
