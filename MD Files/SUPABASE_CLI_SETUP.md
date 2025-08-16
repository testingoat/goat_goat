# Supabase CLI Installation & Setup Guide

## 🎯 **Current Status: FULLY FUNCTIONAL**

The Supabase CLI is now properly installed and configured for the Goat Goat project.

## ✅ **Installation Method Used**

**PowerShell Function Wrapper** (Recommended approach)
- Uses `npx supabase` under the hood (most reliable method)
- Creates a global `supabase` command that works from any directory
- No need for global npm installation (which is not supported)
- Automatically uses the latest version via npx

## 🔧 **Setup Details**

### **PowerShell Profile Configuration**
```powershell
# Location: $PROFILE (C:\Users\prabh\OneDrive\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1)
function supabase { npx supabase @args }
```

### **Verification Commands**
```bash
# Check version
supabase --version
# Output: 2.33.7

# List projects
supabase projects list
# Shows: GOATGOAT project (oaynfzqjielnsipttzbs)

# List functions
supabase functions list
# Shows: All deployed edge functions including send-push-notification

# List secrets
supabase secrets list
# Shows: All environment variables including FCM_SERVER_KEY
```

## 🚀 **Available Commands**

All standard Supabase CLI commands work without `npx` prefix:

```bash
# Authentication
supabase login
supabase logout

# Project management
supabase projects list
supabase link --project-ref oaynfzqjielnsipttzbs

# Edge Functions
supabase functions list
supabase functions deploy <function-name>
supabase functions logs <function-name>

# Secrets management
supabase secrets list
supabase secrets set KEY=value

# Database operations
supabase db reset
supabase db push
supabase db pull
```

## 📊 **Current Project Status**

### **Project Information**
- **Project ID**: oaynfzqjielnsipttzbs
- **Project Name**: GOATGOAT
- **Region**: South Asia (Mumbai)
- **Status**: ✅ Linked and Active

### **Deployed Edge Functions**
- ✅ `send-push-notification` (v5) - FCM push notifications
- ✅ `fast2sms-custom` (v4) - SMS notifications
- ✅ `product-approval-webhook` - Product approval workflow
- ✅ `seller-approval-webhook` - Seller approval workflow
- ✅ `odoo-api-proxy` - Odoo integration
- ✅ All other project functions active

### **Environment Variables**
- ✅ `FCM_SERVER_KEY` - Firebase Cloud Messaging server key
- ✅ `FAST2SMS_API_KEY` - SMS service API key
- ✅ `GOOGLE_MAPS_API_KEY` - Location services
- ✅ `ODOO_*` - Odoo ERP integration credentials
- ✅ `SUPABASE_*` - Database and service credentials

## 🔍 **Why This Method Was Chosen**

### **Failed Installation Methods**
1. **npm global install** - Not supported by Supabase CLI
2. **winget** - Package not available
3. **chocolatey** - Package not available
4. **scoop** - Not installed on system
5. **Direct download** - Network connectivity issues

### **Successful Method Benefits**
- ✅ **Reliable**: Uses npx which always works
- ✅ **Up-to-date**: Always uses latest version
- ✅ **No conflicts**: No global installation issues
- ✅ **Persistent**: PowerShell profile loads automatically
- ✅ **Familiar**: Standard `supabase` command syntax

## 🛠️ **Troubleshooting**

### **If `supabase` command not found**
```powershell
# Reload PowerShell profile
. $PROFILE

# Or restart PowerShell terminal
```

### **If npx is slow**
```bash
# Use npx directly for faster execution
npx supabase <command>
```

### **To update CLI version**
```bash
# npx automatically uses latest version
# No manual update needed
```

## 📝 **Future Maintenance**

- **No manual updates required** - npx handles versioning
- **Profile persists** - Function available in all new PowerShell sessions
- **Cross-project compatible** - Works from any directory
- **Backup profile** - PowerShell profile is backed up with Windows user profile

## 🎯 **Ready for Production Use**

The Supabase CLI is now fully functional and ready for:
- ✅ Edge function deployment and management
- ✅ Database schema management
- ✅ Environment variable configuration
- ✅ Project administration
- ✅ Development workflow automation

---

**Installation completed on**: July 31, 2025  
**CLI Version**: 2.33.7  
**Method**: PowerShell Function Wrapper with npx  
**Status**: ✅ Fully Operational
