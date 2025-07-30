# Goat Goat Deployment Guidelines

## 🚨 CRITICAL: Application Types & Deployment Targets

### **Two Distinct Applications**
1. **Mobile Flutter App** (`lib/main.dart`)
   - Target: App stores (Google Play, Apple App Store)
   - Users: Customers and Sellers
   - Features: Shopping, selling, OTP authentication

2. **Web Admin Panel** (`lib/main_admin.dart`)
   - Target: https://goatgoat.info (Netlify)
   - Users: Administrators only
   - Features: Review moderation, notifications, user management

## ⚠️ DEPLOYMENT ISSUE PREVENTION

### **Root Cause of Previous Issue**
- **WRONG**: `flutter build web --release` (builds mobile app)
- **CORRECT**: `flutter build web --release --target=lib/main_admin.dart` (builds admin panel)

### **Critical Build Commands**

#### **✅ Admin Panel Web Deployment**
```bash
# CORRECT command for admin panel
flutter build web --release --target=lib/main_admin.dart

# Verify build target
echo "Building admin panel for web deployment to goatgoat.info"

# Force add build files (since build/ is in .gitignore)
git add -f build/web

# Commit with clear message
git commit -m "Deploy admin panel build - lib/main_admin.dart target"

# Push to trigger Netlify deployment
git push origin main
```

#### **❌ NEVER Use for Admin Panel**
```bash
# WRONG - This builds the mobile app
flutter build web --release

# WRONG - This is for mobile app stores
flutter build apk --release
flutter build ios --release
```

## 🔍 VERIFICATION CHECKLIST

### **Pre-Deployment Verification**
- [ ] Confirm target file: `lib/main_admin.dart` for admin panel
- [ ] Check build command includes `--target=lib/main_admin.dart`
- [ ] Verify build output shows "Compiling lib/main_admin.dart for the Web"
- [ ] Confirm build/web directory contains admin panel assets

### **Post-Deployment Verification**
- [ ] Visit https://goatgoat.info
- [ ] Verify "Goat Goat Admin Panel" title appears
- [ ] Check for admin login screen (not mobile app interface)
- [ ] Test admin authentication flow
- [ ] Verify admin panel navigation works
- [ ] Check browser console for admin-specific logs

### **Visual Verification Indicators**

#### **✅ Correct Admin Panel Deployment**
- Page title: "Goat Goat Admin Panel"
- Green admin sidebar with navigation
- Login screen with admin credentials
- Desktop-optimized layout
- Admin-specific features visible

#### **❌ Incorrect Mobile App Deployment**
- Mobile-first responsive design
- Customer/Seller portal options
- Phone number input for OTP
- Mobile-optimized navigation
- Shopping cart features

## 📁 PROJECT STRUCTURE REFERENCE

```
lib/
├── main.dart                 # 📱 MOBILE APP ENTRY POINT
├── main_admin.dart          # 🖥️  ADMIN PANEL ENTRY POINT
├── admin/                   # Admin panel specific code
│   ├── screens/
│   ├── services/
│   └── widgets/
├── screens/                 # Mobile app screens
├── services/                # Shared services
└── widgets/                 # Shared widgets

build/web/                   # Web build output (admin panel)
web/                         # Web configuration files
netlify.toml                 # Netlify deployment config
```

## 🔧 NETLIFY CONFIGURATION

### **Current Setup**
- **Publish Directory**: `build/web`
- **Build Command**: `echo 'Deploying pre-built Flutter web admin panel'`
- **Deploy Method**: Pre-built files (not building on Netlify)

### **Why Pre-built Approach**
- Flutter CLI not available in Netlify build environment
- Ensures consistent builds across environments
- Allows local testing before deployment
- Faster deployment times

## 🚀 DEPLOYMENT WORKFLOW

### **Standard Admin Panel Deployment**
1. **Make Changes** to admin panel code
2. **Test Locally** with `flutter run -d chrome --target=lib/main_admin.dart`
3. **Build for Web** with correct target
4. **Verify Build** output and target
5. **Commit & Push** with descriptive message
6. **Monitor Netlify** deployment status
7. **Verify Live Site** functionality

### **Emergency Rollback**
```bash
# If wrong deployment detected
git revert HEAD
git push origin main

# Or rebuild with correct target
flutter build web --release --target=lib/main_admin.dart
git add -f build/web
git commit -m "Fix: Redeploy correct admin panel build"
git push origin main
```

## 📝 COMMIT MESSAGE CONVENTIONS

### **Admin Panel Deployments**
```
Deploy admin panel build - [feature/fix description]

- Built with target: lib/main_admin.dart
- [Specific changes made]
- Verified admin panel functionality
```

### **Mobile App Changes**
```
Update mobile app - [feature/fix description]

- Target: lib/main.dart (mobile app)
- [Specific changes made]
- No web deployment needed
```

## 🔐 SECURITY CONSIDERATIONS

### **Admin Panel Specific**
- Admin authentication required
- Desktop-optimized security headers
- CSP policies for web environment
- HTTPS enforcement

### **Mobile App Specific**
- OTP-based authentication
- Mobile-specific security measures
- App store compliance

## 📊 MONITORING & ALERTS

### **Deployment Success Indicators**
- Netlify build status: ✅ Published
- Site loads without errors
- Admin login accessible
- Console shows admin-specific initialization

### **Deployment Failure Indicators**
- Mobile app interface on web
- Authentication errors
- Missing admin features
- Console errors related to admin services

## 🎯 NEXT STEPS

After resolving deployment issues:
1. Implement Firebase FCM integration (Phase 1.3B)
2. Enhanced admin panel features
3. Mobile app store deployment (separate process)
4. Continuous integration setup

---

## 🔔 FCM PUSH NOTIFICATIONS TESTING

### **Testing Checklist**

#### **Phase 1: Basic Integration Testing**
- [ ] FCM service initializes without errors
- [ ] Notification permissions are requested and granted
- [ ] FCM token is generated and stored
- [ ] Topic subscriptions work correctly
- [ ] Local notifications display in foreground

#### **Phase 2: Cross-Platform Testing**

**Android Testing:**
- [ ] Test on physical Android device (API 21+)
- [ ] Verify notification icon and color display correctly
- [ ] Test foreground notifications with local notification overlay
- [ ] Test background notifications when app is minimized
- [ ] Test notification tap handling and deep linking
- [ ] Verify notification channel creation

**iOS Testing:**
- [ ] Test on physical iOS device (simulator doesn't support push)
- [ ] Verify notification permissions dialog
- [ ] Test foreground notifications with banner display
- [ ] Test background notifications when app is backgrounded
- [ ] Test notification tap handling and deep linking
- [ ] Verify background app refresh settings

**Web Testing:**
- [ ] Test in Chrome/Firefox with service worker support
- [ ] Verify service worker registration
- [ ] Test background notifications when tab is inactive
- [ ] Test notification permissions in browser
- [ ] Test notification tap handling and focus

#### **Phase 3: Admin Panel Testing**
- [ ] Push notification options appear in template editor
- [ ] Topic notifications can be sent from admin panel
- [ ] Targeted notifications work for specific users
- [ ] Combined SMS + Push notifications function
- [ ] Deep linking URLs work correctly
- [ ] Notification logs appear in admin action logs

#### **Phase 4: Integration Testing**
- [ ] FCM works alongside existing SMS notifications
- [ ] Feature flags properly enable/disable functionality
- [ ] Error handling works for failed notifications
- [ ] Supabase edge function processes requests correctly
- [ ] Database logging captures notification events

### **Testing Commands**

```dart
// Run FCM test suite in Flutter app
import 'package:goat_goat/services/fcm_test_service.dart';

final testService = FCMTestService();
final results = await testService.runFullTestSuite();
print('Test Results: ${results['passed']}/${results['total']} passed');

// Send test notification
final testResult = await testService.sendTestNotification();
print('Test notification sent: ${testResult['success']}');
```

### **Manual Testing Steps**

1. **Install and Launch App**
   ```bash
   flutter run -d chrome --target=lib/main.dart  # Web testing
   flutter run -d android --target=lib/main.dart # Android testing
   flutter run -d ios --target=lib/main.dart     # iOS testing
   ```

2. **Verify FCM Initialization**
   - Check console logs for FCM initialization messages
   - Verify FCM token is generated and logged
   - Confirm topic subscriptions are successful

3. **Test Notification Permissions**
   - Verify permission dialog appears on first launch
   - Test granting and denying permissions
   - Check notification settings in device/browser

4. **Test Admin Panel Integration**
   ```bash
   flutter run -d chrome --target=lib/main_admin.dart
   ```
   - Navigate to Notifications panel
   - Create new notification template with push options
   - Send test notifications to topics and specific users

5. **Verify Cross-Platform Functionality**
   - Test on multiple devices and browsers
   - Verify notifications appear correctly on each platform
   - Test deep linking and notification tap handling

---

**Remember**: Always verify the target application matches the deployment destination!
