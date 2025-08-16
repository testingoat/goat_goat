import 'package:flutter/foundation.dart';
import 'package:goat_goat/services/fcm_test_service.dart';
import 'unit_tests/otp_service_test.dart';

/// Comprehensive Test Runner
/// 
/// This script runs all available tests and generates a consolidated report.
void main() async {
  if (kDebugMode) {
    print('🚀 Starting Comprehensive Test Suite');
    print('====================================');
    print('');
  }

  int totalTests = 0;
  int passedTests = 0;
  int failedTests = 0;
  final List<Map<String, dynamic>> allResults = [];

  try {
    // Test 1: FCM Test Suite
    if (kDebugMode) {
      print('📱 Running FCM Test Suite...');
      print('---------------------------');
    }
    
    final fcmTestService = FCMTestService();
    final fcmResults = await fcmTestService.runFullTestSuite();
    
    totalTests += fcmResults['total'] as int;
    passedTests += fcmResults['passed'] as int;
    failedTests += fcmResults['failed'] as int;
    allResults.add({
      'suite': 'FCM Tests',
      'results': fcmResults,
    });
    
    if (kDebugMode) {
      print('FCM Test Results: ${fcmResults['passed']}/${fcmResults['total']} passed');
      print('');
    }

    // Test 2: OTP Test Suite
    if (kDebugMode) {
      print('🔑 Running OTP Test Suite...');
      print('---------------------------');
    }
    
    final otpTestService = OTPServiceTest();
    final otpResults = await otpTestService.runFullTestSuite();
    
    totalTests += otpResults['total'] as int;
    passedTests += otpResults['passed'] as int;
    failedTests += otpResults['failed'] as int;
    allResults.add({
      'suite': 'OTP Tests',
      'results': otpResults,
    });
    
    if (kDebugMode) {
      print('OTP Test Results: ${otpResults['passed']}/${otpResults['total']} passed');
      print('');
    }

    // Generate final report
    await _generateFinalReport(totalTests, passedTests, failedTests, allResults);
    
  } catch (e) {
    if (kDebugMode) {
      print('❌ Test Suite Execution Failed: $e');
    }
  }
}

/// Generate final comprehensive report
Future<void> _generateFinalReport(
  int totalTests, 
  int passedTests, 
  int failedTests, 
  List<Map<String, dynamic>> allResults
) async {
  if (kDebugMode) {
    print('📋 FINAL TEST REPORT');
    print('====================');
    print('');
    
    // Overall Statistics
    final successRate = totalTests > 0 ? (passedTests / totalTests * 100).round() : 0;
    print('📊 OVERALL STATISTICS');
    print('--------------------');
    print('Total Tests: $totalTests');
    print('Passed: $passedTests');
    print('Failed: $failedTests');
    print('Success Rate: $successRate%');
    print('');
    
    // Test Suite Breakdown
    print('🔍 TEST SUITE BREAKDOWN');
    print('----------------------');
    for (final suiteResult in allResults) {
      final suiteName = suiteResult['suite'];
      final results = suiteResult['results'] as Map<String, dynamic>;
      final suiteTotal = results['total'] as int;
      final suitePassed = results['passed'] as int;
      final suiteFailed = results['failed'] as int;
      final suiteRate = suiteTotal > 0 ? (suitePassed / suiteTotal * 100).round() : 0;
      
      print('$suiteName: $suitePassed/$suiteTotal ($suiteRate%)');
    }
    print('');
    
    // Detailed Results
    print('📋 DETAILED RESULTS');
    print('------------------');
    for (final suiteResult in allResults) {
      final suiteName = suiteResult['suite'];
      final results = suiteResult['results'] as Map<String, dynamic>;
      final testResults = results['results'] as List<dynamic>;
      
      print('$suiteName:');
      for (final testResult in testResults) {
        final testName = testResult['test_name'];
        final passed = testResult['passed'] as bool;
        final message = testResult['message'] ?? (passed ? 'PASSED' : 'FAILED');
        final status = passed ? '✅' : '❌';
        
        print('  $status $testName: $message');
        
        if (testResult['error'] != null) {
          print('     Error: ${testResult['error']}');
        }
      }
      print('');
    }
    
    // Final Status
    print('🏁 TEST EXECUTION COMPLETED');
    print('===========================');
    if (failedTests == 0) {
      print('🎉 ALL TESTS PASSED! 🎉');
    } else if (successRate >= 80) {
      print('✅ GOOD - Most tests passed ($successRate% success rate)');
    } else {
      print('⚠️  ATTENTION - Low success rate ($successRate% success rate)');
    }
    
    print('');
    print('Generated at: ${DateTime.now()}');
  }
}
