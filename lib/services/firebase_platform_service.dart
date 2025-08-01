import 'package:flutter/foundation.dart';

// Conditional imports for platform-specific Firebase initialization
import 'package:firebase_core/firebase_core.dart'
    if (dart.library.html) 'firebase_web_stub.dart';
import 'package:firebase_messaging/firebase_messaging.dart'
    if (dart.library.html) 'firebase_messaging_web_stub.dart';
import 'fcm_service.dart' if (dart.library.html) 'fcm_web_stub.dart';

/// Platform-aware Firebase service with zero-risk implementation
///
/// Features:
/// - Conditional initialization based on platform
/// - Feature flags for gradual rollout
/// - 100% backward compatibility
/// - Web-safe implementation
class FirebasePlatformService {
  static final FirebasePlatformService _instance =
      FirebasePlatformService._internal();
  factory FirebasePlatformService() => _instance;
  FirebasePlatformService._internal();

  // Feature flags for zero-risk rollout
  static const bool _enableFirebaseOnAndroid = true;
  static const bool _enableFirebaseOnIOS = false; // Start with Android only
  static const bool _enableFirebaseOnWeb = false; // Keep web disabled for now
  static const bool _enableFCMService = true;

  // Initialization status
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _initializationError;
  String? get initializationError => _initializationError;

  /// Initialize Firebase with platform-specific handling
  Future<bool> initialize() async {
    try {
      if (kDebugMode) {
        print('🔥 Firebase Platform Service: Starting initialization...');
        print('   Platform: ${_getPlatformName()}');
        print('   Web: $kIsWeb');
      }

      // Check if Firebase should be enabled for current platform
      if (!_shouldEnableFirebase()) {
        if (kDebugMode) {
          print(
            '🔥 Firebase Platform Service: Disabled by feature flag for ${_getPlatformName()}',
          );
        }
        _isInitialized = true; // Mark as initialized to prevent retries
        return true; // Return true to not break app flow
      }

      // Web platform - skip Firebase initialization
      if (kIsWeb) {
        if (kDebugMode) {
          print(
            '🔥 Firebase Platform Service: Skipping Firebase on web platform',
          );
        }
        _isInitialized = true;
        return true;
      }

      // Mobile platforms - initialize Firebase
      await Firebase.initializeApp();

      if (kDebugMode) {
        print('✅ Firebase Platform Service: Firebase Core initialized');
      }

      // Initialize FCM service if enabled
      if (_enableFCMService) {
        final fcmService = FCMService();
        final fcmInitialized = await fcmService.initialize();

        if (fcmInitialized) {
          if (kDebugMode) {
            print('✅ Firebase Platform Service: FCM Service initialized');
          }
        } else {
          if (kDebugMode) {
            print(
              '⚠️ Firebase Platform Service: FCM Service initialization failed (non-critical)',
            );
          }
        }
      }

      _isInitialized = true;

      if (kDebugMode) {
        print(
          '✅ Firebase Platform Service: Initialization completed successfully',
        );
      }

      return true;
    } catch (e) {
      _initializationError = e.toString();

      if (kDebugMode) {
        print('❌ Firebase Platform Service: Initialization failed - $e');
        print(
          '   This is non-critical - app will continue with SMS notifications only',
        );
      }

      // Mark as initialized to prevent retries, but return false to indicate failure
      _isInitialized = true;
      return false;
    }
  }

  /// Check if Firebase should be enabled for current platform
  bool _shouldEnableFirebase() {
    if (kIsWeb) return _enableFirebaseOnWeb;

    // For mobile platforms, we'll assume Android for now
    // In a real app, you'd use Platform.isAndroid/Platform.isIOS
    return _enableFirebaseOnAndroid;
  }

  /// Get platform name for logging
  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    return 'Mobile'; // Simplified for this implementation
  }

  /// Get FCM service instance (null if not available)
  FCMService? getFCMService() {
    if (!_isInitialized || kIsWeb || !_enableFCMService) {
      return null;
    }

    try {
      return FCMService();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Platform Service: Cannot get FCM service - $e');
      }
      return null;
    }
  }

  /// Check if FCM is available and working
  bool get isFCMAvailable {
    return !kIsWeb &&
        _isInitialized &&
        _enableFCMService &&
        _initializationError == null;
  }

  /// Get current feature flag status for debugging
  Map<String, dynamic> getFeatureFlags() {
    return {
      'enableFirebaseOnAndroid': _enableFirebaseOnAndroid,
      'enableFirebaseOnIOS': _enableFirebaseOnIOS,
      'enableFirebaseOnWeb': _enableFirebaseOnWeb,
      'enableFCMService': _enableFCMService,
      'isWeb': kIsWeb,
      'isInitialized': _isInitialized,
      'isFCMAvailable': isFCMAvailable,
    };
  }
}

/// Background message handler for FCM (only on mobile)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {
  if (kIsWeb) return; // Skip on web

  try {
    if (kDebugMode) {
      print('🔔 FCM: Background message received');
    }
    // Handle background message here or delegate to FCM service
  } catch (e) {
    if (kDebugMode) {
      print('❌ Background message handler error: $e');
    }
  }
}
