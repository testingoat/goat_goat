// Web stub for Firebase Messaging and related packages
// This file provides stub implementations for web builds where
// Firebase Messaging is not available or causes compilation issues

import 'dart:async';

// Firebase Messaging stubs
class FirebaseMessaging {
  static FirebaseMessaging get instance => FirebaseMessaging._();
  FirebaseMessaging._();

  Future<String?> getToken({String? vapidKey}) async => null;
  Future<void> deleteToken() async {}
  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
  Future<NotificationSettings> requestPermission({
    bool alert = true,
    bool announcement = false,
    bool badge = true,
    bool carPlay = false,
    bool criticalAlert = false,
    bool provisional = false,
    bool sound = true,
  }) async => NotificationSettings._();

  Stream<RemoteMessage> get onMessage => const Stream.empty();
  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();
  Future<RemoteMessage?> getInitialMessage() async => null;

  static Future<void> onBackgroundMessage(
    BackgroundMessageHandler handler,
  ) async {}
}

class NotificationSettings {
  NotificationSettings._();
  AuthorizationStatus get authorizationStatus => AuthorizationStatus.denied;
}

enum AuthorizationStatus { denied, authorized, provisional }

class RemoteMessage {
  RemoteMessage._();
  String? get messageId => null;
  Map<String, dynamic>? get data => null;
  RemoteNotification? get notification => null;
  int? get ttl => null;
}

class RemoteNotification {
  RemoteNotification._();
  String? get title => null;
  String? get body => null;
}

typedef BackgroundMessageHandler = Future<void> Function(RemoteMessage message);

// Flutter Local Notifications stubs
class FlutterLocalNotificationsPlugin {
  Future<bool?> initialize(
    InitializationSettings initializationSettings,
  ) async => false;
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
  ) async {}
}

class InitializationSettings {
  const InitializationSettings({
    this.android,
    this.iOS,
    this.macOS,
    this.linux,
  });

  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;
  final DarwinInitializationSettings? macOS;
  final LinuxInitializationSettings? linux;
}

class AndroidInitializationSettings {
  const AndroidInitializationSettings(this.defaultIcon);
  final String defaultIcon;
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings({
    this.requestSoundPermission = true,
    this.requestBadgePermission = true,
    this.requestAlertPermission = true,
  });

  final bool requestSoundPermission;
  final bool requestBadgePermission;
  final bool requestAlertPermission;
}

class LinuxInitializationSettings {
  const LinuxInitializationSettings({required this.defaultActionName});
  final String defaultActionName;
}

class NotificationDetails {
  const NotificationDetails({this.android, this.iOS, this.macOS, this.linux});
  final AndroidNotificationDetails? android;
  final DarwinNotificationDetails? iOS;
  final DarwinNotificationDetails? macOS;
  final LinuxNotificationDetails? linux;
}

class AndroidNotificationDetails {
  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.importance = Importance.defaultImportance,
    this.priority = Priority.defaultPriority,
  });

  final String channelId;
  final String channelName;
  final String? channelDescription;
  final Importance importance;
  final Priority priority;
}

class DarwinNotificationDetails {
  const DarwinNotificationDetails();
}

class LinuxNotificationDetails {
  const LinuxNotificationDetails();
}

enum Importance { min, low, defaultImportance, high, max }

enum Priority { min, low, defaultPriority, high, max }

// Permission Handler stubs
class Permission {
  static const Permission notification = Permission._('notification');
  const Permission._(this.value);
  final String value;

  Future<PermissionStatus> request() async => PermissionStatus.denied;
  Future<PermissionStatus> status() async => PermissionStatus.denied;
}

enum PermissionStatus {
  denied,
  granted,
  restricted,
  limited,
  permanentlyDenied,
}
