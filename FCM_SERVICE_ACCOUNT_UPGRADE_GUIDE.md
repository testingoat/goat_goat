# 🔥 Firebase FCM Service Account Upgrade Guide

## 📋 **Overview**

This guide documents the upgrade from legacy FCM Server Key authentication to modern Firebase Service Account authentication for the Goat Goat admin panel push notifications.

## 🔄 **What Changed**

### **Before (Legacy FCM HTTP API)**
- Used `FCM_SERVER_KEY` environment variable
- Legacy endpoint: `https://fcm.googleapis.com/fcm/send`
- Simple API key authentication
- Payload format: `{ to: "token", notification: {...}, data: {...} }`

### **After (Modern Firebase HTTP v1 API)**
- Uses `FIREBASE_SERVICE_ACCOUNT` environment variable (JSON)
- Modern endpoint: `https://fcm.googleapis.com/v1/projects/{project-id}/messages:send`
- OAuth2 authentication with JWT
- Payload format: `{ message: { token: "token", notification: {...}, data: {...} } }`

## 🛠️ **Implementation Details**

### **Key Features Added**
1. **OAuth2 Authentication**: JWT-based authentication using service account credentials
2. **Comprehensive Validation**: Input validation and service account credential verification
3. **Enhanced Error Handling**: Detailed error messages with troubleshooting guidance
4. **Zero-Risk Pattern**: Maintains backward compatibility and comprehensive logging

### **New Dependencies**
- `https://deno.land/x/djwt@v2.8/mod.ts` - JWT creation and signing

### **Environment Variable Change**
```bash
# OLD (remove this)
FCM_SERVER_KEY=AAAA1234567890abcdef...

# NEW (add this)
FIREBASE_SERVICE_ACCOUNT={"type":"service_account","project_id":"goat-goat-8e3da",...}
```

## 🚀 **Deployment Steps**

### **Step 1: Obtain Firebase Service Account Credentials**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `goat-goat-8e3da`
3. Go to **Project Settings** → **Service Accounts**
4. Click **Generate New Private Key**
5. Download the JSON file (contains all required credentials)

### **Step 2: Configure Supabase Environment Variable**

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select project: `oaynfzqjielnsipttzbs`
3. Go to **Settings** → **Edge Functions** → **Environment Variables**
4. Add new variable:
   - **Name**: `FIREBASE_SERVICE_ACCOUNT`
   - **Value**: Complete JSON content from Step 1 (as single line)

### **Step 3: Deploy Updated Edge Function**

```bash
# Navigate to project directory
cd /path/to/goat_goat

# Deploy the updated edge function
supabase functions deploy send-push-notification

# Verify deployment
supabase functions list
```

### **Step 4: Test the Implementation**

```bash
# Test with curl (replace with actual values)
curl -X POST "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/send-push-notification" \
  -H "Authorization: Bearer YOUR_SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Notification",
    "body": "Testing Firebase HTTP v1 API",
    "topic": "all_users",
    "admin_id": "test-admin"
  }'
```

## 🔍 **Validation Checklist**

### **Pre-Deployment Validation**
- [ ] Firebase service account JSON contains all required fields
- [ ] Service account has Firebase Cloud Messaging permissions
- [ ] Supabase environment variable is properly configured
- [ ] Edge function deploys without errors

### **Post-Deployment Testing**
- [ ] Admin panel can send notifications without errors
- [ ] Notifications appear on target devices
- [ ] Error messages are clear and helpful
- [ ] Admin action logs are created properly

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. "Invalid service account" Error**
```json
{
  "success": false,
  "error": "Invalid service account: missing private_key or client_email"
}
```
**Solution**: Ensure the complete Firebase service account JSON is in the environment variable.

#### **2. "OAuth2 authentication failed" Error**
```json
{
  "success": false,
  "error": "OAuth2 authentication failed: JWT creation failed"
}
```
**Solution**: Check that the private key is in proper PEM format with headers.

#### **3. "FCM HTTP v1 API request failed" Error**
```json
{
  "success": false,
  "error": "FCM HTTP v1 API request failed: Invalid argument"
}
```
**Solution**: Verify the Firebase project ID and ensure FCM is enabled.

### **Debug Steps**

1. **Check Supabase Logs**:
   ```bash
   supabase functions logs send-push-notification
   ```

2. **Validate Service Account JSON**:
   - Ensure it's valid JSON
   - Check all required fields are present
   - Verify project_id matches Firebase project

3. **Test OAuth2 Token Generation**:
   - Check console logs for JWT creation messages
   - Verify Google OAuth2 token exchange

## 🔐 **Security Considerations**

### **Service Account Permissions**
- Service account should have minimal required permissions
- Only Firebase Cloud Messaging permissions needed
- Regularly rotate service account keys

### **Environment Variable Security**
- Never commit service account JSON to Git
- Use Supabase secrets for production
- Consider using separate service accounts for dev/prod

## 📊 **Monitoring and Logging**

### **Success Indicators**
- Console log: `✅ FCM HTTP v1 API Success`
- Response includes `message_name` field
- Admin action logs created with `api_version: 'http_v1'`

### **Error Indicators**
- Console log: `❌ FCM HTTP v1 API Function Error`
- Response includes `error_type` and `troubleshooting` fields
- HTTP status 400/500 responses

## 🎯 **Next Steps**

1. **Deploy the updated edge function**
2. **Configure Firebase service account credentials**
3. **Test push notifications from admin panel**
4. **Monitor logs for any issues**
5. **Update documentation if needed**

---

## 📞 **Support**

If you encounter issues:
1. Check the troubleshooting section above
2. Review Supabase edge function logs
3. Verify Firebase project configuration
4. Test with minimal payload first

**Implementation completed following zero-risk pattern with comprehensive error handling and backward compatibility.** ✅
