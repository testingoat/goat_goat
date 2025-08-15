# FCM Notification Fix Plan

## Problem Statement
FCM notifications are being received successfully within the app but are not appearing in the mobile status bar or notification area.

## Root Cause Analysis

### 1. Notification Channel ID Mismatch
- **AndroidManifest.xml** defines the default notification channel as: `goat_goat_notifications`
- **Flutter code** uses: `high_importance_channel` for creating and showing notifications
- This mismatch prevents Android from properly displaying notifications in the status bar

### 2. Background Message Handling
- The background message handler needs verification to ensure it properly displays system notifications

## Detailed Fix Instructions

### Phase 1: Fix Notification Channel Mismatch

#### Step 1: Update Notification Channel Creation
In `lib/services/fcm_mobile.dart`, locate the `_initializeLocalNotifications` method and modify the channel creation:

```dart
// Change from:
const channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

// Change to:
const channel = AndroidNotificationChannel(
  'goat_goat_notifications',  // Match AndroidManifest.xml
  'Goat Goat Notifications',    // More descriptive name
  description: 'This channel is used for Goat Goat app notifications.',
  importance: Importance.high,
);
```

#### Step 2: Update Notification Display Methods
In the same file, update both `_showLocalNotification` and `showLocalNotification` methods:

```dart
// In _showLocalNotification method, change:
const androidDetails = AndroidNotificationDetails(
  'high_importance_channel',
  // ...

// To:
const androidDetails = AndroidNotificationDetails(
  'goat_goat_notifications',
  // ...
```

```dart
// In showLocalNotification method, change:
const androidDetails = AndroidNotificationDetails(
  'high_importance_channel',
  // ...

// To:
const androidDetails = AndroidNotificationDetails(
  'goat_goat_notifications',
  // ...
```

### Phase 2: Verify Background Message Handling

#### Step 1: Add Diagnostic Logging
In `lib/main.dart`, enhance the background message handler with detailed logging:

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for background context
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kDebugMode) {
    print("🔔 Background message received: ${message.messageId}");
    print("📱 Title: ${message.notification?.title}");
    print("📝 Body: ${message.notification?.body}");
    print("📦 Data: ${message.data}");
  }

  // Show system notification (this appears in notification panel)
  try {
    final fcmService = FCMService();
    await fcmService.showLocalNotification(
      title: message.notification?.title ?? 'Goat Goat',
      body: message.notification?.body ?? 'You have a new notification',
      payload: jsonEncode(message.data),
    );
    
    if (kDebugMode) {
      print("✅ Background notification displayed successfully");
    }
  } catch (e) {
    if (kDebugMode) {
      print("❌ Error showing background notification: $e");
    }
  }
}
```

#### Step 2: Test Background Message Handling
1. Send a test FCM message while the app is in the background
2. Check logs to verify the background handler is triggered
3. Verify the notification appears in the status bar

## Verification Steps

### 1. Notification Channel Verification
- Check Android settings to confirm the "Goat Goat Notifications" channel exists
- Verify the channel has proper importance level set

### 2. Background Message Testing
- Send test FCM messages with app in different states:
  - Foreground
  - Background
  - Killed

### 3. Permission Verification
- Ensure `POST_NOTIFICATIONS` permission is granted on Android 13+
- Check that notification permissions are enabled in app settings

## Expected Outcomes
After implementing these fixes:
- FCM notifications will appear in the status bar
- Notification channels will be properly configured
- Background messages will be handled correctly
- Notifications will display consistently across all app states

## Rollback Plan
If issues occur after implementation:
1. Revert channel ID changes to original values
2. Restore original background handler implementation
3. Test with a known working FCM configuration