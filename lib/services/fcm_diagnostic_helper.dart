import 'package:flutter/foundation.dart';
import 'fcm_service.dart';

/// FCM Diagnostic Helper for validating notification fixes
/// 
/// This helper provides comprehensive diagnostics to validate that
/// the FCM notification channel mismatch and other issues are resolved.
class FCMDiagnosticHelper {
  static final FCMService _fcmService = FCMService();

  /// Run comprehensive FCM diagnostics
  static Future<void> runDiagnostics() async {
    if (kDebugMode) {
      print('🔍 ===== FCM DIAGNOSTIC REPORT =====');
      
      try {
        final diagnostics = await _fcmService.getDiagnostics();
        
        print('📱 Platform: ${diagnostics['platform']}');
        print('🔧 FCM Enabled: ${diagnostics['fcm_enabled']}');
        print('✅ Initialized: ${diagnostics['is_initialized']}');
        print('🎯 Has Token: ${diagnostics['has_token']}');
        
        // CRITICAL: Channel ID validation
        print('');
        print('🔔 NOTIFICATION CHANNEL VALIDATION:');
        print('   Channel ID: ${diagnostics['notification_channel_id']}');
        print('   Manifest Channel: ${diagnostics['android_manifest_channel']}');
        print('   Status: ${diagnostics['channel_match_status']}');
        
        // Permission status
        if (diagnostics['is_initialized'] == true) {
          print('');
          print('🔐 PERMISSION STATUS:');
          print('   FCM Status: ${diagnostics['notification_status']}');
          print('   Notifications Enabled: ${diagnostics['notifications_enabled']}');
          
          if (diagnostics.containsKey('android_notification_permission')) {
            print('   Android 13+ Permission: ${diagnostics['android_notification_permission']}');
            print('   Android Permission Granted: ${diagnostics['android_permission_granted']}');
          }
        }
        
        // Token information
        if (diagnostics['has_token'] == true) {
          print('');
          print('🎫 TOKEN INFORMATION:');
          print('   Token Length: ${diagnostics['token_length']} characters');
          print('   Token Storage: ${diagnostics['token_storage_enabled']}');
        }
        
        print('');
        print('🔍 ===== END DIAGNOSTIC REPORT =====');
        
      } catch (e) {
        print('❌ FCM Diagnostic Error: $e');
      }
    }
  }

  /// Test local notification with correct channel
  static Future<void> testLocalNotification() async {
    if (kDebugMode) {
      print('🧪 Testing local notification with fixed channel...');
      
      try {
        await _fcmService.showLocalNotification(
          title: 'FCM Test Notification',
          body: 'This notification uses the correct channel ID: goat_goat_notifications',
          payload: '{"test": true, "timestamp": "${DateTime.now().toIso8601String()}"}',
        );
        
        print('✅ Test notification sent successfully');
        print('📱 Channel: goat_goat_notifications (matches AndroidManifest.xml)');
        
      } catch (e) {
        print('❌ Test notification failed: $e');
      }
    }
  }

  /// Validate notification channel consistency
  static Future<bool> validateChannelConsistency() async {
    try {
      final diagnostics = await _fcmService.getDiagnostics();
      
      final channelId = diagnostics['notification_channel_id'] as String?;
      final manifestChannel = diagnostics['android_manifest_channel'] as String?;
      
      final isConsistent = channelId == manifestChannel && 
                          channelId == 'goat_goat_notifications';
      
      if (kDebugMode) {
        if (isConsistent) {
          print('✅ Channel consistency validated: $channelId');
        } else {
          print('❌ Channel mismatch detected!');
          print('   Code Channel: $channelId');
          print('   Manifest Channel: $manifestChannel');
        }
      }
      
      return isConsistent;
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Channel validation error: $e');
      }
      return false;
    }
  }

  /// Check if all critical fixes are applied
  static Future<Map<String, bool>> validateFixes() async {
    final results = <String, bool>{};
    
    try {
      // Check channel consistency
      results['channel_consistency'] = await validateChannelConsistency();
      
      // Check FCM initialization
      final diagnostics = await _fcmService.getDiagnostics();
      results['fcm_initialized'] = diagnostics['is_initialized'] == true;
      results['has_token'] = diagnostics['has_token'] == true;
      results['notifications_enabled'] = diagnostics['notifications_enabled'] == true;
      
      // Check Android 13+ permissions if applicable
      if (diagnostics.containsKey('android_permission_granted')) {
        results['android_permission'] = diagnostics['android_permission_granted'] == true;
      }
      
      if (kDebugMode) {
        print('🔍 FIX VALIDATION RESULTS:');
        results.forEach((key, value) {
          final status = value ? '✅' : '❌';
          print('   $status $key: $value');
        });
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Fix validation error: $e');
      }
    }
    
    return results;
  }
}
