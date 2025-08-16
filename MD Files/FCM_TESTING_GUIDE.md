# FCM Testing Guide

This guide provides instructions for testing the Firebase Cloud Messaging (FCM) implementation in the Goat Goat app.

## Prerequisites

1. Firebase project configured with Cloud Messaging enabled
2. `google-services.json` for Android and `GoogleService-Info.plist` for iOS
3. Supabase project with proper environment variables configured
4. Firebase service account JSON configured in Supabase Edge Functions

## Running the Tests

### 1. Run the FCM Test Script

```bash
# Navigate to the project directory
cd goat_goat

# Run the FCM test script
flutter pub get
dart test/fcm_test_script.dart
```

### 2. Manual Testing

You can also manually test FCM functionality through the admin panel:

1. Start the admin panel:
   ```bash
   flutter run -t lib/main_admin.dart
   ```

2. Navigate to the Notifications section
3. Create a new notification template
4. Send a test notification to a topic or specific user

### 3. Testing Different App States

To thoroughly test FCM, verify notifications work in all app states:

1. **Foreground**: App is open and active
2. **Background**: App is running but in the background
3. **Terminated**: App has been completely closed

For each state:
1. Send a test notification from the admin panel
2. Verify the notification is received and displayed correctly
3. Check that tapping the notification opens the app and handles deep linking

## Test Scenarios

### Basic FCM Functionality
- [ ] FCM service initializes without errors
- [ ] Notification permissions are granted
- [ ] FCM token is generated and stored
- [ ] Topic subscriptions work correctly
- [ ] Foreground notifications display properly
- [ ] Background notifications are received
- [ ] Notification tap handling works
- [ ] Deep linking functions correctly

### Admin Panel Integration
- [ ] Notification templates can be created
- [ ] Templates can be edited and deleted
- [ ] SMS notifications can be sent
- [ ] Push notifications can be sent
- [ ] Combined SMS + Push notifications work
- [ ] Notification history is tracked
- [ ] Analytics are displayed correctly

### Edge Cases
- [ ] Invalid FCM tokens are handled gracefully
- [ ] Network errors are handled properly
- [ ] Malformed notification payloads are handled
- [ ] Expired tokens are refreshed automatically
- [ ] Multiple notifications are queued correctly

## Debugging Tips

### Check FCM Token
1. Enable debug logging in the app
2. Look for "FCM Token" in the console output
3. Verify the token is being generated and stored

### Verify Firebase Configuration
1. Check that `google-services.json` and `GoogleService-Info.plist` are in the correct locations
2. Verify package/bundle IDs match Firebase project configuration
3. Confirm Firebase project has Cloud Messaging enabled

### Test Edge Function
1. Check Supabase Edge Function logs:
   ```bash
   supabase functions logs send-push-notification
   ```
2. Verify `FIREBASE_SERVICE_ACCOUNT` environment variable is set correctly
3. Test the function with curl:
   ```bash
   curl -X POST "https://YOUR_SUPABASE_URL/functions/v1/send-push-notification" \
     -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Test Notification",
       "body": "Testing FCM integration",
       "topic": "test_notifications"
     }'
   ```

## Common Issues and Solutions

### No FCM Token Generated
- Check Firebase configuration files
- Verify package/bundle IDs match Firebase project
- Ensure app has internet connectivity
- Check for Firebase initialization errors

### Notifications Not Received
- Verify Firebase Cloud Messaging is enabled in Firebase Console
- Check that the device has a stable internet connection
- Confirm notification permissions are granted
- Verify FCM token is valid and stored correctly

### Edge Function Errors
- Check `FIREBASE_SERVICE_ACCOUNT` environment variable
- Verify service account has proper permissions
- Check Firebase project ID in service account JSON
- Review Supabase Edge Function logs for detailed error messages

## Monitoring

After deployment, monitor:
- FCM token generation success rate
- Notification delivery rates
- User engagement with notifications
- Error rates in Supabase Edge Functions
- App crashes related to FCM handling

## Support

If you encounter issues:
1. Check the debugging tips above
2. Review Supabase edge function logs
3. Verify Firebase project configuration
4. Test with minimal payload first