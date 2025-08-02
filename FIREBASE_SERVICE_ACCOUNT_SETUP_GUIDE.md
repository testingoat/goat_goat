# Firebase Service Account Setup Guide for Goat Goat FCM

## 🎯 **Objective**
Configure the `FIREBASE_SERVICE_ACCOUNT` environment variable in Supabase to enable push notifications from the admin panel to reach all mobile devices.

## 📋 **Prerequisites**
- Firebase project: `goat-goat-8e3da` (already configured)
- Supabase project: `oaynfzqjielnsipttzbs` (already configured)
- Admin access to both Firebase Console and Supabase Dashboard

## 🔧 **Step-by-Step Setup**

### **Step 1: Generate Firebase Service Account Key**

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Select project: `goat-goat-8e3da`

2. **Navigate to Service Accounts**
   - Click the gear icon (⚙️) → **Project Settings**
   - Go to **Service Accounts** tab
   - Select **Firebase Admin SDK**

3. **Generate New Private Key**
   - Click **Generate New Private Key**
   - Click **Generate Key** in the confirmation dialog
   - A JSON file will be downloaded (e.g., `goat-goat-8e3da-firebase-adminsdk-xxxxx.json`)

4. **Verify Service Account JSON Structure**
   The downloaded JSON should contain these fields:
   ```json
   {
     "type": "service_account",
     "project_id": "goat-goat-8e3da",
     "private_key_id": "...",
     "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
     "client_email": "firebase-adminsdk-xxxxx@goat-goat-8e3da.iam.gserviceaccount.com",
     "client_id": "...",
     "auth_uri": "https://accounts.google.com/o/oauth2/auth",
     "token_uri": "https://oauth2.googleapis.com/token",
     "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
     "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxxxx%40goat-goat-8e3da.iam.gserviceaccount.com"
   }
   ```

### **Step 2: Configure Supabase Environment Variable**

1. **Go to Supabase Dashboard**
   - Visit: https://supabase.com/dashboard
   - Select project: `GOATGOAT` (ID: oaynfzqjielnsipttzbs)

2. **Navigate to Edge Functions Settings**
   - Go to **Project Settings** (gear icon in sidebar)
   - Click **Edge Functions** in the left menu
   - Click **Environment Variables** tab

3. **Add Firebase Service Account Variable**
   - Click **Add Variable**
   - **Name**: `FIREBASE_SERVICE_ACCOUNT`
   - **Value**: Paste the entire JSON content from the downloaded file
   - **Important**: Ensure the JSON is properly formatted (no extra spaces or line breaks)
   - Click **Save**

### **Step 3: Deploy Edge Function**

1. **Deploy the Updated Function**
   ```bash
   # Navigate to project root
   cd /path/to/goat_goat

   # Deploy the edge function
   supabase functions deploy send-push-notification
   ```

2. **Verify Deployment**
   - Check Supabase Dashboard → Edge Functions
   - Confirm `send-push-notification` function is deployed
   - Check deployment logs for any errors

### **Step 4: Test Configuration**

1. **Test Edge Function Directly**
   ```bash
   curl -X POST "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/send-push-notification" \
     -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "title": "Test Notification",
       "body": "Testing Firebase service account configuration",
       "topic": "all_users"
     }'
   ```

2. **Expected Success Response**
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

3. **Test from Admin Panel**
   - Open admin panel: https://goatgoat.info
   - Navigate to Notifications section
   - Send a test push notification
   - Verify it reaches mobile devices

## 🔍 **Troubleshooting**

### **Common Issues**

1. **"FIREBASE_SERVICE_ACCOUNT not configured" Error**
   - Verify environment variable is set in Supabase
   - Check variable name is exactly `FIREBASE_SERVICE_ACCOUNT`
   - Ensure JSON is valid (use JSON validator)

2. **"Invalid service account JSON" Error**
   - Re-download service account key from Firebase
   - Verify all required fields are present
   - Check for any formatting issues

3. **"Permission denied" Error**
   - Ensure service account has Cloud Messaging Admin role
   - Verify project ID matches in service account JSON

4. **"Token not found" Error**
   - Check if FCM tokens are stored in database
   - Verify mobile app is properly registering tokens

### **Verification Checklist**

- [ ] Firebase service account JSON downloaded
- [ ] `FIREBASE_SERVICE_ACCOUNT` environment variable set in Supabase
- [ ] Edge function deployed successfully
- [ ] Test notification sent successfully
- [ ] Mobile app receives push notifications

## 🚀 **Next Steps**

Once Firebase service account is configured:
1. Proceed to FCM Token Verification & Testing
2. Test notification delivery to specific users
3. Verify bulk notification functionality
4. Implement comprehensive testing workflow