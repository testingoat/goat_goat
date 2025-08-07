import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Real Firebase imports for mobile
import 'package:firebase_messaging/firebase_messaging.dart'
    as firebase_messaging;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'fcm_interface.dart';

/// Mobile implementation of FCM using real Firebase services
class FCMImplementation implements FCMInterface {
  static final FCMImplementation _instance = FCMImplementation._internal();
  factory FCMImplementation() => _instance;
  FCMImplementation._internal();

  // Firebase Messaging instance
  final firebase_messaging.FirebaseMessaging _firebaseMessaging =
      firebase_messaging.FirebaseMessaging.instance;

  // Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Internal state
  bool _isInitialized = false;
  String? _fcmToken;
  Function(Map<String, dynamic>)? _onNotificationTapped;

  // Feature flags for gradual rollout
  static bool get _enableFCM {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.windows) return false;
    return true;
  }

  static const bool _enableTokenStorage = true;
  static const bool _enableTopicSubscriptions = true;

  @override
  Future<bool> initialize({
    Function(Map<String, dynamic>)? onNotificationTapped,
  }) async {
    if (_isInitialized) return true;

    _onNotificationTapped = onNotificationTapped;

    if (!_enableFCM) {
      if (kDebugMode) {
        print('🔔 FCM: Disabled on this platform');
      }
      _isInitialized = true;
      return true;
    }

    try {
      // Request permissions
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        if (kDebugMode) {
          print('🔔 FCM: Permissions denied');
        }
        return false;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

      // Subscribe to default topics
      await _subscribeToDefaultTopics();

      _isInitialized = true;

      if (kDebugMode) {
        print('🔔 FCM: Successfully initialized');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Initialization failed - $e');
      }
      return false;
    }
  }

  Future<bool> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.windows || kIsWeb) {
      return true;
    }

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final authorized =
          settings.authorizationStatus ==
              firebase_messaging.AuthorizationStatus.authorized ||
          settings.authorizationStatus ==
              firebase_messaging.AuthorizationStatus.provisional;

      if (kDebugMode) {
        print('🔔 FCM: Permission status - ${settings.authorizationStatus}');
      }

      return authorized;
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Permission request failed - $e');
      }
      return false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (defaultTargetPlatform == TargetPlatform.windows || kIsWeb) {
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      );

      // Create notification channel for Android
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        const channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.high,
        );

        await androidPlugin?.createNotificationChannel(channel);
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Local notifications setup failed - $e');
      }
    }
  }

  Future<void> _getFCMToken() async {
    if (defaultTargetPlatform == TargetPlatform.windows || kIsWeb) {
      return;
    }

    try {
      _fcmToken = await _firebaseMessaging.getToken();

      if (kDebugMode && _fcmToken != null) {
        print('🔔 FCM: Token obtained - ${_fcmToken!.substring(0, 20)}...');
      }

      // Store token in database if user is logged in
      await _storeTokenInDatabase();

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _storeTokenInDatabase();
        if (kDebugMode) {
          print('🔔 FCM: Token refreshed - ${newToken.substring(0, 20)}...');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Token retrieval failed - $e');
      }
    }
  }

  void _setupMessageHandlers() {
    // Handle foreground messages
    firebase_messaging.FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    // Handle messages when app is opened from notification
    firebase_messaging.FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageOpenedApp,
    );

    // Handle initial message if app was opened from notification
    firebase_messaging.FirebaseMessaging.instance.getInitialMessage().then((
      message,
    ) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });
  }

  Future<void> _storeTokenInDatabase() async {
    if (!_enableTokenStorage || _fcmToken == null) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      await Supabase.instance.client
          .from('customers')
          .update({'fcm_token': _fcmToken})
          .eq('id', user.id);

      if (kDebugMode) {
        print('🔔 FCM: Token stored in database');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Token storage failed - $e');
      }
    }
  }

  @override
  Future<bool> storeTokenForSeller(String sellerId) async {
    if (!_enableTokenStorage || _fcmToken == null) {
      if (kDebugMode) {
        print('🔔 FCM: Token storage disabled or no token available');
      }
      return false;
    }

    try {
      await Supabase.instance.client
          .from('sellers')
          .update({'fcm_token': _fcmToken})
          .eq('id', sellerId);

      if (kDebugMode) {
        print('🔔 FCM: Token stored for seller $sellerId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Seller token storage failed - $e');
      }
      return false;
    }
  }

  Future<void> _handleForegroundMessage(
    firebase_messaging.RemoteMessage message,
  ) async {
    if (kDebugMode) {
      print('📱 FCM: Foreground message received - ${message.messageId}');
    }

    // Show local notification for foreground messages
    await _showLocalNotification(message);
  }

  Future<void> _handleMessageOpenedApp(
    firebase_messaging.RemoteMessage message,
  ) async {
    if (kDebugMode) {
      print('🔗 FCM: Message opened app - ${message.messageId}');
    }

    // Handle deep linking or navigation
    if (_onNotificationTapped != null && message.data.isNotEmpty) {
      _onNotificationTapped!(message.data);
    }
  }

  Future<void> _showLocalNotification(
    firebase_messaging.RemoteMessage message,
  ) async {
    if (kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title ?? 'New Message',
        message.notification?.body ?? 'You have a new message',
        notificationDetails,
        payload: message.data.toString(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Local notification failed - $e');
      }
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (_onNotificationTapped != null && response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _onNotificationTapped!(data);
      } catch (e) {
        if (kDebugMode) {
          print('🔔 FCM: Notification payload parsing failed - $e');
        }
      }
    }
  }

  Future<void> _subscribeToDefaultTopics() async {
    if (!_enableTopicSubscriptions) return;

    try {
      await _firebaseMessaging.subscribeToTopic('all_users');
      await _firebaseMessaging.subscribeToTopic('app_updates');

      if (kDebugMode) {
        print('🔔 FCM: Subscribed to default topics');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Topic subscription failed - $e');
      }
    }
  }

  @override
  Future<bool> subscribeToTopic(String topic) async {
    if (!_enableTopicSubscriptions || !_isInitialized) return false;

    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('🔔 FCM: Subscribed to topic: $topic');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Topic subscription failed - $e');
      }
      return false;
    }
  }

  @override
  Future<bool> unsubscribeFromTopic(String topic) async {
    if (!_enableTopicSubscriptions || !_isInitialized) return false;

    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('🔔 FCM: Unsubscribed from topic: $topic');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Topic unsubscription failed - $e');
      }
      return false;
    }
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async {
    if (kIsWeb) {
      return _WebNotificationSettings(AuthorizationStatus.denied);
    }

    try {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return _MobileNotificationSettings(settings);
    } catch (e) {
      return _WebNotificationSettings(AuthorizationStatus.denied);
    }
  }

  @override
  Future<bool> areNotificationsEnabled() async {
    final settings = await getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<Map<String, dynamic>> getDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'is_initialized': _isInitialized,
      'platform': defaultTargetPlatform.name,
      'fcm_enabled': _enableFCM,
      'token_storage_enabled': _enableTokenStorage,
      'topic_subscriptions_enabled': _enableTopicSubscriptions,
      'has_token': _fcmToken != null,
      'token_length': _fcmToken?.length ?? 0,
    };

    if (_isInitialized) {
      final settings = await getNotificationSettings();
      diagnostics['notification_status'] = settings.authorizationStatus.name;
      diagnostics['notifications_enabled'] = await areNotificationsEnabled();
    }

    return diagnostics;
  }

  @override
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🔔 FCM: Local notification failed - $e');
      }
    }
  }
}

/// Mobile implementation of NotificationSettings
class _MobileNotificationSettings implements NotificationSettings {
  final firebase_messaging.NotificationSettings _settings;

  _MobileNotificationSettings(this._settings);

  @override
  AuthorizationStatus get authorizationStatus {
    switch (_settings.authorizationStatus) {
      case firebase_messaging.AuthorizationStatus.authorized:
        return AuthorizationStatus.authorized;
      case firebase_messaging.AuthorizationStatus.provisional:
        return AuthorizationStatus.provisional;
      default:
        return AuthorizationStatus.denied;
    }
  }
}

/// Web implementation of NotificationSettings
class _WebNotificationSettings implements NotificationSettings {
  final AuthorizationStatus _status;

  _WebNotificationSettings(this._status);

  @override
  AuthorizationStatus get authorizationStatus => _status;
}
