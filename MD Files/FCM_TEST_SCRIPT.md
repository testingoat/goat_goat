# FCM Testing Script for Goat Goat

## 🧪 **Test Current Edge Function Status**

### **Test 1: Check if FIREBASE_SERVICE_ACCOUNT is configured**

```bash
curl -X POST "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/send-push-notification" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Configuration",
    "body": "Testing if Firebase service account is configured",
    "topic": "test_notifications"
  }'
```

### **Expected Responses**

**If FIREBASE_SERVICE_ACCOUNT is NOT configured:**
```json
{
  "success": false,
  "message": "FIREBASE_SERVICE_ACCOUNT environment variable is not configured. Please set it in Supabase Dashboard → Project Settings → Edge Functions → Environment Variables",
  "error": "Missing Firebase service account credentials",
  "instructions": "Add FIREBASE_SERVICE_ACCOUNT with your complete Firebase service account JSON"
}
```

**If FIREBASE_SERVICE_ACCOUNT is configured correctly:**
```json
{
  "success": true,
  "message": "Push notification sent successfully via Firebase HTTP v1 API",
  "fcm_result": {...},
  "message_name": "projects/goat-goat-8e3da/messages/...",
  "api_version": "http_v1",
  "project_id": "goat-goat-8e3da"
}
```

## 🔧 **PowerShell Test Commands (Windows)**

### **Test Edge Function**
```powershell
$headers = @{
    "Authorization" = "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA"
    "Content-Type" = "application/json"
}

$body = @{
    title = "Test Notification"
    body = "Testing FCM configuration"
    topic = "test_notifications"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/send-push-notification" -Method POST -Headers $headers -Body $body
```

## 📊 **Current Test Results**

### ✅ **Working Features**
1. **Firebase Service Account**: ✅ Configured and working
2. **Edge Function**: ✅ Deployed and responding
3. **Topic Notifications**: ✅ Successfully sent to `test_notifications` topic
4. **Customer FCM Token Storage**: ✅ Found 1 customer with FCM token

### ❌ **Issues Found**
1. **Seller FCM Tokens**: ❌ No sellers have FCM tokens stored
2. **Targeted Notifications**: ❌ Error 500 when sending to specific user
3. **Test FCM Token**: ⚠️ Customer has test token `test_fcm_token_for_development_6362924334`

### 🔍 **Analysis**
- The customer FCM token appears to be a test/placeholder token, not a real device token
- Sellers are not registering FCM tokens (mobile app issue)
- Targeted notifications failing (edge function issue)

## 🧪 **Additional Tests**

### **Test 2: Check Real Mobile Device Registration**
```powershell
# Test if mobile app is actually running and registering real FCM tokens
# Run mobile app on Android/iOS device and check for new tokens in database
```

### **Test 3: Verify Topic Subscriptions**
```powershell
# Test different topics
$topics = @("all_users", "android_users", "ios_users", "customers", "sellers")
foreach ($topic in $topics) {
    $body = @{
        title = "Topic Test: $topic"
        body = "Testing notification delivery to topic: $topic"
        topic = $topic
    } | ConvertTo-Json

    Write-Host "Testing topic: $topic"
    try {
        $result = Invoke-RestMethod -Uri "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/send-push-notification" -Method POST -Headers $headers -Body $body
        Write-Host "✅ Success: $($result.message_name)"
    } catch {
        Write-Host "❌ Failed: $($_.Exception.Message)"
    }
}
```

## 📱 **Mobile App Testing Requirements**

### **For Real Device Testing**
1. **Install mobile app on Android/iOS device**
2. **Complete registration process**
3. **Verify FCM token is stored in database**
4. **Test notification reception**

### **Expected FCM Token Format**
Real FCM tokens should look like:
```
dGVzdF9mY21fdG9rZW5fZm9yX2Rldm...  (Android)
APA91bHun4MzP31hwk0NjBVaOSHWPiMT...  (iOS)
```

Not like: `test_fcm_token_for_development_6362924334`

## 🔧 **Enhanced Admin Panel Testing**

### **Test Retry Failed Notifications**

1. **Access admin panel**: https://goatgoat.info
2. **Navigate to Notifications section**
3. **Click "Retry Failed" button**
4. **Verify retry dialog appears with:**
   - Information about retry process
   - Maximum 3 retry attempts
   - 2-second delay between retries
   - Only SMS notifications retried
5. **Click "Retry Failed" to execute**
6. **Check results in snackbar and details dialog**

### **Test Delivery Status Report**

1. **Click "Delivery Report" button**
2. **Verify report dialog appears**
3. **Click "Generate Report"**
4. **Check report shows:**
   - Total notifications
   - Successful/failed/pending counts
   - Delivery rate percentage
   - Breakdown by method (SMS/push)
   - Breakdown by type
   - Retry attempts statistics

### **Test Enhanced Notification History**

1. **Check notification history list**
2. **Verify each notification shows:**
   - Delivery status (sent/failed/pending)
   - Delivery attempts count
   - Method (SMS/push)
   - Timestamp
   - Error messages (if failed)

## 📊 **Phase 1 Implementation Status**

### ✅ **Completed Tasks**
1. **Firebase Service Account Setup**: ✅ Already configured and working
2. **FCM Token Verification**: ✅ Customer tokens working, seller token storage fixed
3. **Admin Panel Enhancement**: ✅ Added retry mechanism and delivery tracking
4. **Seller FCM Integration**: ✅ Fixed seller token storage in login/registration flow

### 🧪 **Ready for Testing**
1. **Real device testing** with mobile app
2. **Seller registration/login** to verify FCM token storage
3. **Admin panel retry functionality**
4. **Delivery status reporting**
5. **End-to-end notification flow**