// Test Firebase v1 API Integration
// This script tests the Firebase service account integration

const SUPABASE_URL = 'https://oaynfzqjielnsipttzbs.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA';

async function testFirebaseV1API() {
  console.log('🔥 Testing Firebase v1 API Integration...');
  console.log('==========================================');

  try {
    // Test with a realistic FCM token format (not test token)
    console.log('\n🔥 Test 1: Firebase v1 API with Real Token Format');
    console.log('--------------------------------------------------');

    const realTokenTestPayload = {
      title: 'Firebase v1 API Test',
      body: 'Testing Firebase service account integration with realistic token',
      target_user_id: 'dGVzdF9mY21fdG9rZW5fZm9yX3YxX2FwaV90ZXN0aW5nXzEyMzQ1Njc4OTA', // Base64 encoded realistic token
      target_user_type: 'customer',
      admin_id: 'firebase-test-admin'
    };

    console.log('📤 Sending request with realistic FCM token format');

    const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(realTokenTestPayload),
    });

    console.log('📊 Response Status:', response.status);
    const result = await response.json();
    console.log('📋 Response Body:', JSON.stringify(result, null, 2));

    if (response.status === 200 && result.success) {
      console.log('✅ Firebase v1 API test: PASSED');
      if (result.fcm_result?.api_version === 'v1') {
        console.log('🎉 Successfully using Firebase v1 API!');
      } else if (result.fcm_result?.test_mode) {
        console.log('🧪 Running in test mode (Firebase service account may need verification)');
      }
    } else {
      console.log('❌ Firebase v1 API test: FAILED');
      console.log('Error:', result.message || result.error);
    }

    // Test 2: Topic notification with v1 API
    console.log('\n📢 Test 2: Topic Notification with v1 API');
    console.log('-------------------------------------------');

    const topicTestPayload = {
      title: 'Firebase v1 Topic Test',
      body: 'Testing topic notifications with Firebase v1 API',
      topic: 'all_users',
      admin_id: 'firebase-test-admin'
    };

    console.log('📤 Sending topic notification request');

    const topicResponse = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(topicTestPayload),
    });

    console.log('📊 Response Status:', topicResponse.status);
    const topicResult = await topicResponse.json();
    console.log('📋 Response Body:', JSON.stringify(topicResult, null, 2));

    if (topicResponse.status === 200 && topicResult.success) {
      console.log('✅ Topic notification test: PASSED');
      if (topicResult.fcm_result?.api_version === 'v1') {
        console.log('🎉 Successfully using Firebase v1 API for topics!');
      }
    } else {
      console.log('❌ Topic notification test: FAILED');
      console.log('Error:', topicResult.message || topicResult.error);
    }

    // Test 3: Check service account detection
    console.log('\n🔍 Test 3: Service Account Detection');
    console.log('------------------------------------');

    const detectionTestPayload = {
      title: 'Service Account Detection Test',
      body: 'Testing if Firebase service account is properly detected',
      target_user_id: '6362924334', // Phone number
      admin_id: 'detection-test-admin'
    };

    console.log('📤 Sending service account detection test');

    const detectionResponse = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(detectionTestPayload),
    });

    console.log('📊 Response Status:', detectionResponse.status);
    const detectionResult = await detectionResponse.json();
    console.log('📋 Response Body:', JSON.stringify(detectionResult, null, 2));

    // Summary
    console.log('\n🎯 Firebase v1 API Test Summary');
    console.log('===============================');

    if (result.fcm_result?.api_version === 'v1' || topicResult.fcm_result?.api_version === 'v1') {
      console.log('✅ Firebase v1 API is working correctly!');
      console.log('✅ Service account authentication successful');
      console.log('✅ Ready for real device push notifications');
    } else if (result.fcm_result?.test_mode || topicResult.fcm_result?.test_mode) {
      console.log('🧪 System is running in test mode');
      console.log('⚠️ Firebase service account may need verification');
      console.log('💡 Check Supabase edge function logs for more details');
    } else {
      console.log('❌ Firebase v1 API integration needs attention');
      console.log('🔧 Check Firebase service account configuration');
    }

    console.log('\n🚀 Firebase v1 API integration test completed!');

  } catch (error) {
    console.error('❌ Test failed with error:', error);
  }
}

// Run the test
testFirebaseV1API();