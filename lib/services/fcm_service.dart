import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Only import Firebase packages on mobile platforms
import 'package:firebase_messaging/firebase_messaging.dart'
    if (dart.library.html) 'fcm_web_stub.dart'
    as firebase_messaging;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    if (dart.library.html) 'fcm_web_stub.dart'
    as local_notifications;

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
  final firebase_messaging.FirebaseMessaging _firebaseMessaging =
      firebase_messaging.FirebaseMessaging.instance;

  // Local notifications plugin
  final local_notifications.FlutterLocalNotificationsPlugin
  _localNotifications = local_notifications.FlutterLocalNotificationsPlugin();

  // Feature flags for gradual rollout
  // Disable full FCM on web and Windows; web will use no-op stubs
  static bool get _enableFCM {
    if (kIsWeb) return false; // web: build-safe no-op via stubs
    if (defaultTargetPlatform == TargetPlatform.windows) return false;
    return true;
  }

  static bool get _enableLocalNotifications {
    if (kIsWeb) return false; // web: local notifications not used
    if (defaultTargetPlatform == TargetPlatform.windows) return false;
    return true;
  }

  static bool get _enableTopicSubscriptions {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.windows) return false;
    return true;
  }

  static const bool _enableDeepLinking = true;

  static bool get _enableTokenStorage {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.windows) return false;
    return true;
  }

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
    // Completely skip Firebase initialization on Windows
    if (defaultTargetPlatform == TargetPlatform.windows) {
      if (kDebugMode) {
        print('🔔 FCM Service: Feature disabled on Windows platform');
      }
      return false;
    }
    // On web, do not initialize native messaging; keep stubs active and return false
    if (kIsWeb) {
      if (kDebugMode) {
        print('🔔 FCM Service: Web build detected, using no-op stubs');
      }
      _onNotificationTapped =
          onNotificationTapped; // still keep callback for consistency
      _isInitialized = false;
      return false;
    }

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
    // Skip permissions on Windows and Web
    if (defaultTargetPlatform == TargetPlatform.windows || kIsWeb) {
      return false;
    }

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
    // Skip local notifications on Windows and Web
    if (defaultTargetPlatform == TargetPlatform.windows || kIsWeb) {
      return;
    }

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
    // Skip token retrieval on Windows and Web
    if (defaultTargetPlatform == TargetPlatform.windows || kIsWeb) {
      return;
    }

    try {
      _fcmToken = await _firebaseMessaging.getToken();

      if (_fcmToken != null) {
        if (kDebugMode) {
          print('🔑 FCM Token: ${_fcmToken!.substring(0, 20)}...');
          print('📱 Device Info: $defaultTargetPlatform');
          print('🔧 Token Length: ${_fcmToken!.length}');
          print('⏰ Token Generated At: ${DateTime.now().toIso8601String()}');
        }

        // Store token in Supabase for admin notifications
        if (_enableTokenStorage) {
          await _storeTokenInDatabase();
        }
      } else {
        if (kDebugMode) {
          print(
            '❌ FCM: Token is null - this might indicate a configuration issue',
          );
        }
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        if (kDebugMode) {
          print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');
          print('⏰ Token Refreshed At: ${DateTime.now().toIso8601String()}');
        }

        if (_enableTokenStorage) {
          _storeTokenInDatabase();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to get token - $e');
        print('🔍 This could be due to:');
        print('   - Firebase project not properly configured');
        print('   - Package/bundle ID mismatch with Firebase console');
        print('   - Missing google-services.json or GoogleService-Info.plist');
        print('   - Network connectivity issues');
        print('   - App not properly signed (for release builds)');
      }
    }
  }

  /// Store FCM token in Supabase database
  Future<void> _storeTokenInDatabase() async {
    if (!_enableTokenStorage || _fcmToken == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Try to determine user type and store token accordingly
        // First check if user is a customer
        final customerResponse = await Supabase.instance.client
            .from('customers')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (customerResponse != null) {
          // User is a customer
          await Supabase.instance.client
              .from('customers')
              .update({'fcm_token': _fcmToken})
              .eq('id', user.id);

          if (kDebugMode) {
            print('✅ FCM: Token stored for customer');
          }
          return;
        }

        // Check if user is a seller (using user_id field)
        final sellerResponse = await Supabase.instance.client
            .from('sellers')
            .select('id')
            .eq('user_id', user.id)
            .maybeSingle();

        if (sellerResponse != null) {
          // User is a seller
          await Supabase.instance.client
              .from('sellers')
              .update({'fcm_token': _fcmToken})
              .eq('user_id', user.id);

          if (kDebugMode) {
            print('✅ FCM: Token stored for seller');
          }
          return;
        }

        // Check if user is an admin
        final adminResponse = await Supabase.instance.client
            .from('admin_users')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (adminResponse != null) {
          // User is an admin
          await Supabase.instance.client
              .from('admin_users')
              .update({'fcm_token': _fcmToken})
              .eq('id', user.id);

          if (kDebugMode) {
            print('✅ FCM: Token stored for admin');
          }
          return;
        }

        if (kDebugMode) {
          print('⚠️ FCM: User not found in any table - token not stored');
        }
      } else {
        if (kDebugMode) {
          print(
            '⚠️ FCM: No authenticated user - checking for seller session...',
          );
        }

        // Check for seller session (sellers don't use Supabase Auth)
        await _storeTokenForSeller();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to store token in database - $e');
      }
    }
  }

  /// Store FCM token for seller (sellers use custom authentication)
  Future<void> _storeTokenForSeller() async {
    try {
      // For now, we'll implement a simpler approach
      // Check if there's any seller data in local storage or session
      // This is a placeholder - in a real implementation, you'd check
      // the current seller session from your app's state management

      if (kDebugMode) {
        print('⚠️ FCM: Seller token storage not yet implemented');
        print('   This requires integration with seller session management');
      }

      if (kDebugMode) {
        print('⚠️ FCM: Seller token storage requires explicit seller ID');
        print('   Call storeTokenForSeller(sellerId) after seller login');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to store token for seller - $e');
      }
    }
  }

  /// Store FCM token for a specific seller (call this after seller login)
  Future<bool> storeTokenForSeller(String sellerId) async {
    if (!_enableTokenStorage || _fcmToken == null) {
      if (kDebugMode) {
        print('⚠️ FCM: Token storage disabled or no token available');
      }
      return false;
    }

    try {
      await Supabase.instance.client
          .from('sellers')
          .update({'fcm_token': _fcmToken})
          .eq('id', sellerId);

      if (kDebugMode) {
        print('✅ FCM: Token stored for seller: $sellerId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM: Failed to store token for seller $sellerId - $e');
      }
      return false;
    }
  }

  /// Setup message handlers for different app states
  void _setupMessageHandlers() {
    // On web, use stubs (no streams) — skip attaching handlers
    if (kIsWeb) {
      if (kDebugMode) {
        print('ℹ️ FCM: Skipping handler wiring on web');
      }
      return;
    }

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
    // Skip on web (no local notifications supported in this build)
    if (kIsWeb) return;
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
  void _onLocalNotificationTapped(dynamic response) {
    // On web, NotificationResponse type doesn't exist; accept dynamic safely
    final payload = (response is Object && !kIsWeb)
        ? (response as dynamic).payload
        : null;
    if (kDebugMode) {
      print('🔔 FCM: Local notification tapped - $payload');
    }

    if (_enableDeepLinking &&
        _onNotificationTapped != null &&
        payload != null) {
      try {
        Map<String, dynamic> data;
        try {
          data = Map<String, dynamic>.from(
            payload != null ? jsonDecode(payload) : <String, dynamic>{},
          );
        } catch (_) {
          data = <String, dynamic>{'payload': payload.toString()};
        }
        if (kDebugMode) {
          print('🔗 FCM: Parsed notification data: $data');
        }
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
    if (kIsWeb) {
      // On web builds, just request permissions and return the real settings from the stub,
      // which is build-safe and returns a denied status by default.
      try {
        await _firebaseMessaging.requestPermission();
      } catch (_) {}
      return await _firebaseMessaging.getNotificationSettings();
    }
    return await _firebaseMessaging.getNotificationSettings();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Get detailed diagnostics information
  Future<Map<String, dynamic>> getDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'is_initialized': _isInitialized,
      'has_token': _fcmToken != null,
      'token_preview': _fcmToken != null
          ? '${_fcmToken!.substring(0, 20)}...'
          : 'null',
      'token_length': _fcmToken?.length ?? 0,
      'platform': defaultTargetPlatform.toString(),
      'feature_flags': {
        'enable_fcm': _enableFCM,
        'enable_local_notifications': _enableLocalNotifications,
        'enable_topic_subscriptions': _enableTopicSubscriptions,
        'enable_deep_linking': _enableDeepLinking,
        'enable_token_storage': _enableTokenStorage,
      },
    };

    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      diagnostics['notification_settings'] = {
        'authorization_status': settings.authorizationStatus.toString(),
        'alert': settings.alert,
        'badge': settings.badge,
        'sound': settings.sound,
      };
    } catch (e) {
      diagnostics['notification_settings_error'] = e.toString();
    }

    return diagnostics;
  }

  /// Show local notification (appears in system notification panel)
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? channelId,
  }) async {
    // Skip on Windows
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return;
    }

    if (!_enableLocalNotifications) {
      if (kDebugMode) {
        print('🔔 Local notifications disabled by feature flag');
      }
      return;
    }

    try {
      // Compatible with all Android versions
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'goat_goat_notifications', // Channel ID
            'Goat Goat Notifications', // Channel name
            channelDescription: 'Notifications from Goat Goat app',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
            // Compatible icon works on all versions
            icon: '@drawable/ic_notification',
            color: Color(0xFF059669),
          );

      // iOS settings
      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );

      if (kDebugMode) {
        print('✅ Local notification shown: $title');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error showing local notification: $e');
      }
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb) {
    // Not supported on web; no-op
    return;
  }
  if (kDebugMode) {
    print('🔔 FCM: Background message received - ${message.messageId}');
    print('   Title: ${message.notification?.title}');
    print('   Body: ${message.notification?.body}');
    print('   Data: ${message.data}');
    // The following properties may not exist on some platforms; guard if needed
    try {
      print('   TTL: ${message.ttl}');
    } catch (_) {}
  }
}
