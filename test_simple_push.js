// Simple Push Notification Test
const SUPABASE_URL = 'https://oaynfzqjielnsipttzbs.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA';

async function testSimplePush() {
  console.log('🔥 Testing Firebase Service Account...');
  
  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        title: 'Firebase Service Account Test',
        body: 'Testing if service account is working',
        target_user_id: '6362924334',
        admin_id: 'test-admin'
      }),
    });

    console.log('📊 Response Status:', response.status);
    const result = await response.json();
    console.log('📋 Response Body:', JSON.stringify(result, null, 2));

    // Check for Firebase v1 API indicators
    if (result.fcm_result?.api_version === 'v1') {
      console.log('🎉 SUCCESS: Firebase v1 API is working!');
    } else if (result.fcm_result?.test_mode) {
      console.log('🧪 Test mode: Firebase service account detected but authentication may have issues');
    } else {
      console.log('❌ Firebase service account not working properly');
    }

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

testSimplePush();
