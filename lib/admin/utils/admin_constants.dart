import 'package:flutter/foundation.dart';

/// Admin Panel Configuration Constants
///
/// This class manages environment-specific configuration for the admin panel,
/// supporting both local development and production deployment.
class AdminConstants {
  // Environment detection - prioritize custom environment variable
  static bool get isProduction {
    const customEnv = String.fromEnvironment(
      'ADMIN_ENVIRONMENT',
      defaultValue: '',
    );
    if (customEnv.isNotEmpty) {
      return customEnv == 'production';
    }
    return kReleaseMode;
  }

  static bool get isDevelopment {
    const customEnv = String.fromEnvironment(
      'ADMIN_ENVIRONMENT',
      defaultValue: '',
    );
    if (customEnv.isNotEmpty) {
      return customEnv == 'development';
    }

    // For admin panel deployment, allow development credentials
    // Check if we're running as the admin panel (main_admin.dart)
    if (kIsWeb) {
      // In web deployment, allow development mode for admin panel
      // This enables admin@goatgoat.com / admin123 credentials
      return true;
    }

    return kDebugMode;
  }

  // Supabase Configuration
  static String get supabaseUrl {
    if (isProduction) {
      return const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://oaynfzqjielnsipttzbs.supabase.co',
      );
    } else {
      // Local development - use same Supabase instance
      return 'https://oaynfzqjielnsipttzbs.supabase.co';
    }
  }

  static String get supabaseAnonKey {
    if (isProduction) {
      return const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA',
      );
    } else {
      // Local development - use same key
      return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA';
    }
  }

  // Admin Panel Configuration
  static String get adminPanelTitle => 'Goat Goat Admin Panel';
  static String get adminPanelVersion => '1.0.0';

  // Local Development Configuration
  static String get localDevUrl => 'http://localhost:8080';
  static int get localDevPort => 8080;

  // Production Configuration
  static String get productionUrl {
    if (isProduction) {
      return const String.fromEnvironment(
        'ADMIN_URL',
        defaultValue: 'https://admin.goatgoat.info',
      );
    } else {
      return localDevUrl;
    }
  }

  // API Configuration
  static String get apiBaseUrl => supabaseUrl;
  static Duration get apiTimeout => const Duration(seconds: 30);

  // Session Configuration
  static Duration get sessionTimeout => const Duration(hours: 8);
  static Duration get sessionRefreshInterval => const Duration(minutes: 30);

  // Security Configuration
  static bool get enableMFA => isProduction;
  static int get maxLoginAttempts => 5;
  static Duration get lockoutDuration => const Duration(minutes: 30);

  // UI Configuration
  static int get defaultPageSize => 25;
  static Duration get autoRefreshInterval => const Duration(seconds: 30);
  static bool get enableKeyboardShortcuts => true;

  // Feature Flags for Admin Panel
  static bool get enableReviewModeration => true;
  static bool get enableNotificationManagement => true;
  static bool get enableUserManagement => true;
  static bool get enableAnalytics => true;
  static bool get enableSystemAdmin => true;

  // Logging Configuration
  static bool get enableLogging => true;
  static bool get enableVerboseLogging => isDevelopment;

  // Performance Configuration
  static int get maxConcurrentRequests => 10;
  static Duration get cacheExpiration => const Duration(minutes: 5);

  // Development Helpers
  static void logConfig() {
    if (isDevelopment) {
      print('🔧 Admin Panel Configuration:');
      print('   Environment: ${isProduction ? 'Production' : 'Development'}');
      print('   Supabase URL: $supabaseUrl');
      print('   Admin URL: $productionUrl');
      print('   MFA Enabled: $enableMFA');
      print('   Session Timeout: ${sessionTimeout.inHours}h');
    }
  }

  // Environment validation
  static bool validateEnvironment() {
    try {
      // Check required configuration
      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        print('❌ Missing required Supabase configuration');
        return false;
      }

      if (isProduction && productionUrl.isEmpty) {
        print('❌ Missing production URL configuration');
        return false;
      }

      print('✅ Environment configuration validated');
      return true;
    } catch (e) {
      print('❌ Environment validation failed: $e');
      return false;
    }
  }
}
