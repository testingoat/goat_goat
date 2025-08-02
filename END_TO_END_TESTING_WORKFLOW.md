# End-to-End FCM Testing Workflow - Goat Goat

## 🎯 **Objective**
Verify that push notifications sent from the admin panel successfully reach all mobile applications (Android and iOS) with 100% reliability.

## 📋 **Prerequisites**
- ✅ Firebase Service Account configured
- ✅ Edge function deployed and working
- ✅ Admin panel accessible at https://goatgoat.info
- ✅ Mobile app with FCM integration
- ✅ Enhanced retry and tracking features implemented

## 🧪 **Testing Workflow**

### **Phase 1: Infrastructure Verification**

#### **Test 1.1: Edge Function Status**
```powershell
# Test edge function is working
$headers = @{
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA"
    "Content-Type" = "application/json"
}

$body = @{
    title = "Infrastructure Test"
    body = "Testing edge function connectivity"
    topic = "test_notifications"
} | ConvertTo-Json

$result = Invoke-RestMethod -Uri "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/send-push-notification" -Method POST -Headers $headers -Body $body
Write-Host "✅ Edge Function Test: $($result.success)"
```

**Expected Result**: `success: true` with Firebase message name

#### **Test 1.2: Database Token Verification**
```sql
-- Check customer FCM tokens
SELECT COUNT(*) as customer_tokens FROM customers WHERE fcm_token IS NOT NULL;

-- Check seller FCM tokens
SELECT COUNT(*) as seller_tokens FROM sellers WHERE fcm_token IS NOT NULL;

-- Check recent notification logs
SELECT COUNT(*) as recent_notifications FROM notification_logs
WHERE created_at > NOW() - INTERVAL '24 hours';
```

**Expected Result**: At least 1 customer token, seller tokens after mobile testing

### **Phase 2: Mobile App Testing**

#### **Test 2.1: Customer Registration & FCM Token**
1. **Install mobile app** on Android/iOS device
2. **Register as new customer** using phone number
3. **Complete OTP verification**
4. **Check debug logs** for FCM token registration:
   ```
   🔑 FCM Token: [actual_device_token]
   ✅ FCM: Token stored for customer
   ✅ FCM: Subscribed to topic - all_users
   ```
5. **Verify in database**:
   ```sql
   SELECT phone_number, fcm_token FROM customers
   WHERE fcm_token IS NOT NULL
   ORDER BY created_at DESC LIMIT 5;
   ```

#### **Test 2.2: Seller Registration & FCM Token**
1. **Register as new seller** using different phone number
2. **Complete seller registration flow**
3. **Check debug logs** for FCM token storage:
   ```
   ✅ FCM: Token stored for seller: [seller_id]
   ```
4. **Verify in database**:
   ```sql
   SELECT contact_phone, fcm_token FROM sellers
   WHERE fcm_token IS NOT NULL
   ORDER BY created_at DESC LIMIT 5;
   ```

### **Phase 3: Admin Panel Testing**

#### **Test 3.1: Topic-Based Notifications**
1. **Access admin panel**: https://goatgoat.info
2. **Navigate to Notifications section**
3. **Send notification to "all_users" topic**:
   - Title: "Test Topic Notification"
   - Message: "Testing topic-based push notifications"
   - Type: Push Notification
4. **Verify notification appears on mobile devices**
5. **Check notification logs** in admin panel

#### **Test 3.2: User-Specific Notifications**
1. **Send notification to specific customer**:
   - Select customer from database
   - Title: "Personal Test Notification"
   - Message: "Testing user-specific notifications"
2. **Send notification to specific seller**:
   - Select seller from database
   - Title: "Seller Test Notification"
   - Message: "Testing seller notifications"
3. **Verify notifications reach correct devices only**

#### **Test 3.3: Bulk Notifications**
1. **Use bulk notification feature**
2. **Send to multiple users simultaneously**
3. **Monitor delivery status**
4. **Check for any failures**

### **Phase 4: Enhanced Features Testing**

#### **Test 4.1: Retry Failed Notifications**
1. **Create a failed notification** (temporarily disable internet on device)
2. **Check notification logs** for failed status
3. **Use "Retry Failed" button** in admin panel
4. **Verify retry process works**
5. **Check updated delivery status**

#### **Test 4.2: Delivery Status Report**
1. **Click "Delivery Report" button**
2. **Generate report for last 7 days**
3. **Verify report shows**:
   - Total notifications sent
   - Success/failure rates
   - Breakdown by method (SMS/Push)
   - Retry statistics
4. **Export or save report data**

### **Phase 5: Cross-Platform Testing**

#### **Test 5.1: Android Device Testing**
1. **Install app on Android device**
2. **Complete registration as customer and seller**
3. **Test all notification scenarios**:
   - App in foreground
   - App in background
   - App terminated
4. **Verify notification appearance and behavior**

#### **Test 5.2: iOS Device Testing**
1. **Install app on iOS device**
2. **Complete registration as customer and seller**
3. **Test all notification scenarios**:
   - App in foreground
   - App in background
   - App terminated
4. **Verify notification appearance and behavior**

## ✅ **Success Criteria**

### **Infrastructure**
- [ ] Edge function responds successfully
- [ ] Firebase service account configured
- [ ] Database stores FCM tokens correctly

### **Mobile App**
- [ ] Customer registration stores FCM token
- [ ] Seller registration stores FCM token
- [ ] App subscribes to topics correctly
- [ ] Real device tokens (not test tokens)

### **Admin Panel**
- [ ] Topic notifications reach all devices
- [ ] User-specific notifications work
- [ ] Bulk notifications function correctly
- [ ] Retry mechanism works for failed notifications
- [ ] Delivery reports generate accurately

### **Cross-Platform**
- [ ] Android notifications work in all app states
- [ ] iOS notifications work in all app states
- [ ] Consistent behavior across platforms

## 🔍 **Troubleshooting Guide**

### **Common Issues**

#### **No Notifications Received**
1. Check FCM token is stored in database
2. Verify Firebase service account configuration
3. Check device notification permissions
4. Test with topic notifications first

#### **Seller Tokens Not Stored**
1. Verify seller registration completes successfully
2. Check FCM service initialization
3. Look for error logs in seller login flow

#### **Admin Panel Errors**
1. Check Supabase edge function logs
2. Verify admin authentication
3. Test with simple topic notification first

#### **Cross-Platform Issues**
1. Check Firebase configuration files
2. Verify platform-specific permissions
3. Test on different devices/OS versions