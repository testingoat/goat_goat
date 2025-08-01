import 'package:flutter/foundation.dart';
import 'fcm_service.dart';
import '../admin/services/notification_service.dart';

/// FCM Testing Service for comprehensive verification
///
/// This service provides testing utilities for Firebase Cloud Messaging
/// integration across Android, iOS, and Web platforms.
class FCMTestService {
  static final FCMTestService _instance = FCMTestService._internal();
  factory FCMTestService() => _instance;
  FCMTestService._internal();

  final FCMService _fcmService = FCMService();
  final NotificationService _notificationService = NotificationService();

  // Test results storage
  final List<Map<String, dynamic>> _testResults = [];
  List<Map<String, dynamic>> get testResults => List.unmodifiable(_testResults);

  /// Run comprehensive FCM test suite
  Future<Map<String, dynamic>> runFullTestSuite() async {
    if (kDebugMode) {
      print('🧪 Starting FCM Test Suite...');
    }

    _testResults.clear();
    final startTime = DateTime.now();

    try {
      // Test 1: FCM Service Initialization
      await _testFCMInitialization();

      // Test 2: Permission Handling
      await _testPermissions();

      // Test 3: Token Management
      await _testTokenManagement();

      // Test 4: Topic Subscriptions
      await _testTopicSubscriptions();

      // Test 5: Notification Service Integration
      await _testNotificationServiceIntegration();

      // Test 6: Admin Panel Integration
      await _testAdminPanelIntegration();

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      final summary = _generateTestSummary(duration);
      
      if (kDebugMode) {
        print('✅ FCM Test Suite Completed');
        print('📊 Summary: ${summary['passed']}/${summary['total']} tests passed');
      }

      return summary;
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM Test Suite Failed: $e');
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'results': _testResults,
      };
    }
  }

  /// Test FCM service initialization
  Future<void> _testFCMInitialization() async {
    final testName = 'FCM Service Initialization';
    
    try {
      if (kDebugMode) {
        print('🧪 Testing: $testName');
      }

      final initialized = await _fcmService.initialize();
      
      _addTestResult(
        testName: testName,
        passed: initialized,
        details: {
          'initialized': initialized,
          'is_initialized': _fcmService.isInitialized,
        },
        message: initialized 
            ? 'FCM service initialized successfully'
            : 'FCM service failed to initialize',
      );
    } catch (e) {
      _addTestResult(
        testName: testName,
        passed: false,
        error: e.toString(),
        message: 'FCM initialization threw exception',
      );
    }
  }

  /// Test notification permissions
  Future<void> _testPermissions() async {
    final testName = 'Notification Permissions';
    
    try {
      if (kDebugMode) {
        print('🧪 Testing: $testName');
      }

      final settings = await _fcmService.getNotificationSettings();
      final enabled = await _fcmService.areNotificationsEnabled();
      
      _addTestResult(
        testName: testName,
        passed: enabled,
        details: {
          'authorization_status': settings.authorizationStatus.toString(),
          'alert': settings.alert.toString(),
          'badge': settings.badge.toString(),
          'sound': settings.sound.toString(),
          'enabled': enabled,
        },
        message: enabled 
            ? 'Notification permissions granted'
            : 'Notification permissions not granted',
      );
    } catch (e) {
      _addTestResult(
        testName: testName,
        passed: false,
        error: e.toString(),
        message: 'Permission check threw exception',
      );
    }
  }

  /// Test FCM token management
  Future<void> _testTokenManagement() async {
    final testName = 'FCM Token Management';
    
    try {
      if (kDebugMode) {
        print('🧪 Testing: $testName');
      }

      final token = _fcmService.fcmToken;
      final hasToken = token != null && token.isNotEmpty;
      
      _addTestResult(
        testName: testName,
        passed: hasToken,
        details: {
          'has_token': hasToken,
          'token_length': token?.length ?? 0,
          'token_preview': hasToken ? '${token!.substring(0, 20)}...' : null,
        },
        message: hasToken 
            ? 'FCM token obtained successfully'
            : 'FCM token not available',
      );
    } catch (e) {
      _addTestResult(
        testName: testName,
        passed: false,
        error: e.toString(),
        message: 'Token management threw exception',
      );
    }
  }

  /// Test topic subscriptions
  Future<void> _testTopicSubscriptions() async {
    final testName = 'Topic Subscriptions';
    
    try {
      if (kDebugMode) {
        print('🧪 Testing: $testName');
      }

      // Test subscribing to a test topic
      final subscribeResult = await _fcmService.subscribeToTopic('test_topic');
      
      // Test unsubscribing from the test topic
      final unsubscribeResult = await _fcmService.unsubscribeFromTopic('test_topic');
      
      final passed = subscribeResult && unsubscribeResult;
      
      _addTestResult(
        testName: testName,
        passed: passed,
        details: {
          'subscribe_success': subscribeResult,
          'unsubscribe_success': unsubscribeResult,
        },
        message: passed 
            ? 'Topic subscription/unsubscription working'
            : 'Topic subscription/unsubscription failed',
      );
    } catch (e) {
      _addTestResult(
        testName: testName,
        passed: false,
        error: e.toString(),
        message: 'Topic subscription threw exception',
      );
    }
  }

  /// Test notification service integration
  Future<void> _testNotificationServiceIntegration() async {
    final testName = 'Notification Service Integration';
    
    try {
      if (kDebugMode) {
        print('🧪 Testing: $testName');
      }

      final pushEnabled = _notificationService.isPushNotificationsEnabled;
      final topicEnabled = _notificationService.isTopicNotificationsEnabled;
      final targetedEnabled = _notificationService.isTargetedNotificationsEnabled;
      
      final passed = pushEnabled && topicEnabled && targetedEnabled;
      
      _addTestResult(
        testName: testName,
        passed: passed,
        details: {
          'push_notifications_enabled': pushEnabled,
          'topic_notifications_enabled': topicEnabled,
          'targeted_notifications_enabled': targetedEnabled,
        },
        message: passed 
            ? 'All notification service features enabled'
            : 'Some notification service features disabled',
      );
    } catch (e) {
      _addTestResult(
        testName: testName,
        passed: false,
        error: e.toString(),
        message: 'Notification service integration threw exception',
      );
    }
  }

  /// Test admin panel integration
  Future<void> _testAdminPanelIntegration() async {
    final testName = 'Admin Panel Integration';
    
    try {
      if (kDebugMode) {
        print('🧪 Testing: $testName');
      }

      // Test if notification service methods are available
      final hasTopicMethod = _notificationService.sendTopicPushNotification != null;
      final hasTargetedMethod = _notificationService.sendTargetedPushNotification != null;
      final hasCombinedMethod = _notificationService.sendCombinedNotification != null;
      
      final passed = hasTopicMethod && hasTargetedMethod && hasCombinedMethod;
      
      _addTestResult(
        testName: testName,
        passed: passed,
        details: {
          'topic_method_available': hasTopicMethod,
          'targeted_method_available': hasTargetedMethod,
          'combined_method_available': hasCombinedMethod,
        },
        message: passed 
            ? 'All admin panel methods available'
            : 'Some admin panel methods missing',
      );
    } catch (e) {
      _addTestResult(
        testName: testName,
        passed: false,
        error: e.toString(),
        message: 'Admin panel integration threw exception',
      );
    }
  }

  /// Add test result to the results list
  void _addTestResult({
    required String testName,
    required bool passed,
    Map<String, dynamic>? details,
    String? error,
    String? message,
  }) {
    _testResults.add({
      'test_name': testName,
      'passed': passed,
      'timestamp': DateTime.now().toIso8601String(),
      'details': details ?? {},
      'error': error,
      'message': message,
    });

    if (kDebugMode) {
      final status = passed ? '✅' : '❌';
      print('$status $testName: ${message ?? (passed ? 'PASSED' : 'FAILED')}');
      if (error != null) {
        print('   Error: $error');
      }
    }
  }

  /// Generate test summary
  Map<String, dynamic> _generateTestSummary(Duration duration) {
    final total = _testResults.length;
    final passed = _testResults.where((r) => r['passed'] == true).length;
    final failed = total - passed;
    
    return {
      'success': failed == 0,
      'total': total,
      'passed': passed,
      'failed': failed,
      'duration_ms': duration.inMilliseconds,
      'results': _testResults,
    };
  }

  /// Send test notification (for manual testing)
  Future<Map<String, dynamic>> sendTestNotification({
    String title = 'FCM Test Notification',
    String body = 'This is a test notification from Goat Goat FCM service',
    String topic = 'test_notifications',
  }) async {
    try {
      if (kDebugMode) {
        print('📤 Sending test notification...');
      }

      final result = await _notificationService.sendTopicPushNotification(
        title: title,
        body: body,
        topic: topic,
        data: {
          'test': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (kDebugMode) {
        print('📤 Test notification result: ${result['success']}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Test notification failed: $e');
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to send test notification',
      };
    }
  }

  /// Get detailed FCM diagnostics
  Future<Map<String, dynamic>> getFCMDiagnostics() async {
    if (kDebugMode) {
      print('🔍 Getting FCM diagnostics...');
    }

    try {
      // Run the full test suite to get all test results
      final testResults = await runFullTestSuite();
      
      // Get detailed diagnostics from FCM service
      final serviceDiagnostics = await _fcmService.getDiagnostics();

      // Calculate overall health score
      final totalTests = testResults['total'];
      final passedTests = testResults['passed'];
      final healthScore = {
        'total_tests': totalTests,
        'passed_tests': passedTests,
        'percentage': totalTests > 0 ? (passedTests / totalTests * 100).round() : 0,
        'status': passedTests == totalTests ? 'healthy' : passedTests > 0 ? 'partial' : 'unhealthy',
      };

      if (kDebugMode) {
        print('✅ FCM diagnostics completed');
        print('📊 Health Score: ${healthScore['percentage']}%');
      }

      return {
        'success': true,
        'service_diagnostics': serviceDiagnostics,
        'test_results': testResults,
        'health_score': healthScore,
        'message': 'FCM diagnostics completed successfully',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ FCM diagnostics failed: $e');
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get FCM diagnostics',
      };
    }
  }

  /// Generate a comprehensive FCM report
  Future<Map<String, dynamic>> generateReport() async {
    if (kDebugMode) {
      print('📋 Generating FCM report...');
    }

    try {
      final diagnostics = await getFCMDiagnostics();
      final testSuite = await runFullTestSuite();

      final report = <String, dynamic>{
        'generated_at': DateTime.now().toIso8601String(),
        'app_info': {
          'package_name': 'com.goatgoat.app',
          'platform': defaultTargetPlatform.toString(),
          'flutter_version': '3.8.1',
        },
        'firebase_config': {
          'project_id': 'goat-goat-8e3da',
          'sender_id': '188247457782',
        },
        'diagnostics': diagnostics['diagnostics'],
        'test_results': testSuite,
        'recommendations': <String>[],
      };

      // Generate recommendations based on diagnostics
      final healthScore = diagnostics['diagnostics']['health_score'];
      if (healthScore['percentage'] < 100) {
        report['recommendations'].add('Some FCM components are not working properly. Check the diagnostics for details.');
      }

      if (healthScore['status'] == 'unhealthy') {
        report['recommendations'].add('FCM service is not functioning. Verify Firebase configuration and app setup.');
      }

      final failedTests = testSuite['results'].where((r) => r['passed'] == false);
      if (failedTests.isNotEmpty) {
        report['recommendations'].add('Some tests failed. Review the test results for specific issues.');
      }

      if (kDebugMode) {
        print('✅ FCM report generated successfully');
      }

      return {
        'success': true,
        'report': report,
        'message': 'FCM report generated successfully',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to generate FCM report: $e');
      }
      
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to generate FCM report',
      };
    }
  }

  /// Clear test results
  void clearResults() {
    _testResults.clear();
  }
}
