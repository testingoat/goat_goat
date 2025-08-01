import 'package:flutter/foundation.dart';
import 'package:goat_goat/services/fcm_service.dart';
import 'package:goat_goat/services/fcm_test_service.dart';

/// FCM End-to-End Test Script
/// 
/// This script provides a comprehensive test of the FCM implementation
/// to verify that all components are working correctly.
void main() async {
  if (kDebugMode) {
    print('🧪 Starting FCM End-to-End Test');
    print('==============================');
  }

  try {
    // Initialize FCM Service
    final fcmService = FCMService();
    final testService = FCMTestService();
    
    if (kDebugMode) {
      print('🔧 Initializing FCM Service...');
    }
    
    final initResult = await fcmService.initialize();
    if (!initResult) {
      print('❌ FCM Service initialization failed');
      return;
    }
    
    if (kDebugMode) {
      print('✅ FCM Service initialized successfully');
      print('');
    }
    
    // Run comprehensive test suite
    if (kDebugMode) {
      print('📋 Running FCM Test Suite...');
    }
    
    final testResults = await testService.runFullTestSuite();
    
    if (kDebugMode) {
      print('');
      print('📊 Test Results:');
      print('================');
      print('Total Tests: ${testResults['total']}');
      print('Passed Tests: ${testResults['passed']}');
      print('Failed Tests: ${testResults['failed']}');
      print('Success Rate: ${testResults['passed']}/${testResults['total']}');
      print('');
    }
    
    // Display individual test results
    if (testResults['results'] != null) {
      for (final result in testResults['results']) {
        final status = result['passed'] ? '✅' : '❌';
        final testName = result['test_name'];
        final message = result['message'] ?? (result['passed'] ? 'PASSED' : 'FAILED');
        
        if (kDebugMode) {
          print('$status $testName: $message');
        }
        
        if (result['error'] != null && kDebugMode) {
          print('   Error: ${result['error']}');
        }
      }
    }
    
    if (kDebugMode) {
      print('');
    }
    
    // Get detailed diagnostics
    if (kDebugMode) {
      print('🔍 Getting FCM Diagnostics...');
    }
    
    final diagnostics = await testService.getFCMDiagnostics();
    
    if (kDebugMode) {
      print('');
      print('📋 FCM Diagnostics:');
      print('====================');
      
      if (diagnostics['success'] == true) {
        final healthScore = diagnostics['health_score'];
        print('Health Score: ${healthScore['percentage']}% (${healthScore['status']})');
        
        final serviceDiagnostics = diagnostics['service_diagnostics'];
        if (serviceDiagnostics != null) {
          print('');
          print('Service Diagnostics:');
          print('  Initialized: ${serviceDiagnostics['is_initialized']}');
          print('  Has Token: ${serviceDiagnostics['has_token']}');
          print('  Platform: ${serviceDiagnostics['platform']}');
          
          if (serviceDiagnostics['notification_settings'] != null) {
            final settings = serviceDiagnostics['notification_settings'];
            print('  Notification Settings:');
            print('    Authorization Status: ${settings['authorization_status']}');
            print('    Alert: ${settings['alert']}');
            print('    Badge: ${settings['badge']}');
            print('    Sound: ${settings['sound']}');
          }
        }
      } else {
        print('❌ Failed to get diagnostics: ${diagnostics['error']}');
      }
    }
    
    if (kDebugMode) {
      print('');
    }
    
    // Send test notification
    if (kDebugMode) {
      print('📤 Sending Test Notification...');
    }
    
    final testNotificationResult = await testService.sendTestNotification(
      title: 'FCM Test Notification',
      body: 'This is a test notification sent at ${DateTime.now()}',
      topic: 'test_notifications',
    );
    
    if (kDebugMode) {
      if (testNotificationResult['success'] == true) {
        print('✅ Test notification sent successfully');
        print('   Message Name: ${testNotificationResult['fcm_result']?['name']}');
      } else {
        print('❌ Failed to send test notification: ${testNotificationResult['error']}');
      }
      
      print('');
      print('🏁 FCM End-to-End Test Completed');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ FCM End-to-End Test Failed: $e');
    }
  }
}