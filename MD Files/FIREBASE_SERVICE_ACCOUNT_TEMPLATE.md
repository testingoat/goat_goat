# 🔑 Firebase Service Account JSON Template

## 📋 **Required JSON Format**

Your Firebase service account JSON must contain these **exact fields** with the correct data types:

```json
{
  "type": "service_account",
  "project_id": "goat-goat-8e3da",
  "private_key_id": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@goat-goat-8e3da.iam.gserviceaccount.com",
  "client_id": "123456789012345678901",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-xxxxx%40goat-goat-8e3da.iam.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
```

## 🔍 **Field Descriptions**

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `type` | string | Must be exactly `"service_account"` | `"service_account"` |
| `project_id` | string | Your Firebase project ID | `"goat-goat-8e3da"` |
| `private_key_id` | string | Unique identifier for the private key | `"a1b2c3d4e5f6..."` |
| `private_key` | string | RSA private key in PEM format with `\n` newlines | `"-----BEGIN PRIVATE KEY-----\n..."` |
| `client_email` | string | Service account email address | `"firebase-adminsdk-xxxxx@goat-goat-8e3da.iam.gserviceaccount.com"` |
| `client_id` | string | Numeric client ID | `"123456789012345678901"` |
| `auth_uri` | string | Google OAuth2 authorization URI | `"https://accounts.google.com/o/oauth2/auth"` |
| `token_uri` | string | Google OAuth2 token URI | `"https://oauth2.googleapis.com/token"` |
| `auth_provider_x509_cert_url` | string | Google certificates URL | `"https://www.googleapis.com/oauth2/v1/certs"` |
| `client_x509_cert_url` | string | Service account certificate URL | `"https://www.googleapis.com/robot/v1/metadata/x509/..."` |
| `universe_domain` | string | Google Cloud universe domain | `"googleapis.com"` |

## 🚀 **How to Obtain This JSON**

### **Step 1: Access Firebase Console**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **`goat-goat-8e3da`**

### **Step 2: Navigate to Service Accounts**
1. Click the **⚙️ Settings** gear icon (top left)
2. Select **Project Settings**
3. Go to the **Service Accounts** tab

### **Step 3: Generate New Private Key**
1. Scroll down to **Firebase Admin SDK**
2. Select **Node.js** (the language doesn't matter for the JSON format)
3. Click **Generate new private key**
4. Click **Generate key** in the confirmation dialog
5. A JSON file will be downloaded automatically

### **Step 4: Verify the Downloaded JSON**
The downloaded file should be named something like:
```
goat-goat-8e3da-firebase-adminsdk-xxxxx-xxxxxxxxxx.json
```

Open it and verify it contains all the required fields listed above.

## 🔧 **Configuration in Supabase**

### **Step 1: Format for Environment Variable**
The JSON must be **minified** (single line, no spaces) for the environment variable:

```bash
# ❌ DON'T use pretty-formatted JSON
{
  "type": "service_account",
  "project_id": "goat-goat-8e3da",
  ...
}

# ✅ DO use minified JSON (single line)
{"type":"service_account","project_id":"goat-goat-8e3da","private_key_id":"...","private_key":"-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"...","universe_domain":"googleapis.com"}
```

### **Step 2: Add to Supabase Environment Variables**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard/project/oaynfzqjielnsipttzbs)
2. Navigate to **Settings** → **Edge Functions** → **Environment Variables**
3. Click **Add new variable**
4. Set:
   - **Name**: `FIREBASE_SERVICE_ACCOUNT`
   - **Value**: The minified JSON from Step 1
5. Click **Save**

## ✅ **Validation Checklist**

Before configuring in Supabase, verify your JSON:

- [ ] Contains exactly 11 fields (as listed above)
- [ ] `type` field is exactly `"service_account"`
- [ ] `project_id` field is exactly `"goat-goat-8e3da"`
- [ ] `private_key` starts with `"-----BEGIN PRIVATE KEY-----\n"`
- [ ] `private_key` ends with `"\n-----END PRIVATE KEY-----\n"`
- [ ] `client_email` contains `@goat-goat-8e3da.iam.gserviceaccount.com`
- [ ] All URLs use `https://` protocol
- [ ] JSON is valid (no syntax errors)

## 🧪 **Testing After Configuration**

After adding the environment variable to Supabase:

```bash
# Run the test script
node test_fcm_service_account.js
```

**Expected Success Output:**
```
✅ FIREBASE_SERVICE_ACCOUNT is configured
✅ Edge function is responding correctly
✅ PASS: Push notification sent successfully via Firebase HTTP v1 API
```

## 🚨 **Security Notes**

- **Never commit** this JSON file to Git
- **Store only** in Supabase environment variables
- **Delete** the downloaded JSON file after configuration
- **Rotate keys** periodically for security

## 🔧 **Troubleshooting**

### **Common Issues:**

1. **"Invalid private key format"**
   - Ensure private key has proper PEM headers and `\n` newlines

2. **"Invalid service account: missing fields"**
   - Verify all 11 required fields are present

3. **"JWT creation failed"**
   - Check that private key is not corrupted or truncated

4. **"OAuth2 authentication failed"**
   - Verify the service account has Firebase Cloud Messaging permissions

---

**This template is specifically designed for your Firebase project `goat-goat-8e3da` and Supabase project `oaynfzqjielnsipttzbs`.** ✅
