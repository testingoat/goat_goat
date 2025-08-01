# FCM Monitoring Guide

This guide provides instructions for monitoring and maintaining the Firebase Cloud Messaging (FCM) implementation in the Goat Goat app.

## Monitoring Dashboard

### Supabase Analytics
Set up monitoring in your Supabase project to track:

1. **Notification Logs Table**
   - Track delivery status (sent, failed, pending)
   - Monitor delivery rates over time
   - Identify failed notifications and error patterns

2. **Admin Action Logs**
   - Track notification sending activity
   - Monitor user engagement with notifications
   - Identify peak usage times

### Firebase Console
Monitor the following in the Firebase Console:

1. **Cloud Messaging Reports**
   - Message delivery rates
   - Token acceptance rates
   - Notification open rates
   - Error rates and types

2. **Device Statistics**
   - Active device counts
   - Platform distribution (Android/iOS)
   - App version adoption

## Key Metrics to Monitor

### Token Management
- FCM token generation success rate
- Token refresh frequency
- Invalid token detection and handling

### Notification Performance
- Delivery success rate
- Time to delivery
- Notification open rates
- User engagement metrics

### Error Tracking
- Failed notification attempts
- Common error types and codes
- Retry success rates
- Network-related issues

## Maintenance Tasks

### Regular Maintenance
1. **Weekly**
   - Review notification delivery reports
   - Check for unusual error patterns
   - Verify Firebase service account validity

2. **Monthly**
   - Update Firebase dependencies
   - Review and rotate service account keys
   - Audit notification templates
   - Clean up old notification logs

3. **Quarterly**
   - Review and update FCM implementation
   - Test compatibility with new OS versions
   - Update privacy policies if needed
   - Review data retention policies

### Emergency Maintenance
1. **Service Account Issues**
   - Regenerate Firebase service account keys
   - Update `FIREBASE_SERVICE_ACCOUNT` environment variable
   - Redeploy Supabase Edge Function

2. **Notification Delivery Failures**
   - Check Firebase project configuration
   - Verify Cloud Messaging is enabled
   - Review app signing certificates
   - Check for platform-specific issues

## Alerting System

Set up alerts for critical issues:

### Critical Alerts
- FCM service initialization failures
- Notification delivery rate drops below 90%
- High error rates in Edge Functions
- Service account authentication failures

### Warning Alerts
- Token generation failures
- Notification delivery delays
- Unusual error patterns
- Low notification open rates

## Troubleshooting Guide

### Common Issues

#### 1. FCM Token Not Generated
**Symptoms**: No token in logs, notifications not received
**Solutions**:
- Verify Firebase configuration files
- Check package/bundle IDs match Firebase project
- Ensure app has internet connectivity
- Review Firebase initialization code

#### 2. Notifications Not Delivered
**Symptoms**: Token exists but notifications not received
**Solutions**:
- Check Firebase Cloud Messaging is enabled
- Verify device has stable internet connection
- Confirm notification permissions are granted
- Check for app-specific notification settings

#### 3. Edge Function Errors
**Symptoms**: Admin panel shows errors when sending notifications
**Solutions**:
- Check `FIREBASE_SERVICE_ACCOUNT` environment variable
- Verify service account has proper permissions
- Review Supabase Edge Function logs
- Test with minimal payload

### Diagnostic Commands

#### Check Supabase Edge Function Logs
```bash
supabase functions logs send-push-notification
```

#### Test Edge Function Directly
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

#### Run FCM Diagnostics
```bash
flutter pub get
dart test/fcm_test_script.dart
```

## Version Updates

### Firebase SDK Updates
1. Check for new Firebase SDK versions monthly
2. Test updates in staging environment first
3. Update `pubspec.yaml` with new versions
4. Run full test suite after updates

### Platform Updates
1. Monitor Android and iOS release notes
2. Test FCM compatibility with new OS versions
3. Update platform-specific configurations as needed
4. Verify background execution limits

## Security Considerations

### Service Account Management
- Rotate service account keys annually
- Limit service account permissions to minimum required
- Store service account JSON securely
- Monitor service account usage

### Data Privacy
- Comply with data retention policies
- Handle user data deletion requests
- Review privacy policies regularly
- Implement data encryption where appropriate

## Backup and Recovery

### Configuration Backup
- Store Firebase configuration files securely
- Document Firebase project settings
- Keep service account JSON backups
- Maintain version history of configurations

### Recovery Procedures
1. **Firebase Project Issues**
   - Restore from Firebase project backup
   - Recreate configuration files
   - Reconfigure Cloud Messaging settings

2. **Supabase Issues**
   - Restore from Supabase backups
   - Redeploy Edge Functions
   - Reconfigure environment variables

## Performance Optimization

### Token Management
- Implement efficient token storage
- Handle token refresh events properly
- Clean up invalid tokens periodically

### Notification Delivery
- Batch notifications when possible
- Optimize notification payload size
- Use topics for broadcast notifications
- Implement rate limiting for high-volume sends

## Documentation Updates

Keep documentation current with:
- Changes to FCM implementation
- Updates to monitoring procedures
- New troubleshooting steps
- Platform-specific considerations
- Security best practices

## Support Resources

### Firebase Documentation
- [Firebase Cloud Messaging Guide](https://firebase.google.com/docs/cloud-messaging)
- [FCM Error Codes](https://firebase.google.com/docs/cloud-messaging/http-server-ref#error-codes)
- [Firebase Console Documentation](https://firebase.google.com/docs/console)

### Supabase Documentation
- [Supabase Edge Functions Guide](https://supabase.com/docs/guidelines-and-limitations)
- [Supabase Realtime Documentation](https://supabase.com/docs/guides/realtime)

### Community Support
- Firebase Community Slack
- Supabase GitHub Discussions
- Stack Overflow FCM and Supabase tags