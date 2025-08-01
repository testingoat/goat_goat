/**
 * Test Script for Firebase FCM Service Account Authentication
 * Tests the upgraded Supabase edge function with Firebase HTTP v1 API
 */

const SUPABASE_URL = 'https://oaynfzqjielnsipttzbs.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA'

/**
 * Test the FCM edge function with various scenarios
 */
async function testFCMServiceAccount() {
  console.log('🧪 Testing Firebase FCM Service Account Authentication')
  console.log('=' .repeat(60))

  const tests = [
    {
      name: 'Test 1: Basic Topic Notification',
      payload: {
        title: 'Test Notification',
        body: 'Testing Firebase HTTP v1 API with service account',
        topic: 'all_users',
        admin_id: 'test-admin-001'
      }
    },
    {
      name: 'Test 2: Notification with Custom Data',
      payload: {
        title: 'Custom Data Test',
        body: 'Testing with additional data fields',
        topic: 'test_topic',
        data: {
          action: 'test_action',
          category: 'system_test',
          priority: 'high'
        },
        deep_link_url: 'goatgoat://test',
        admin_id: 'test-admin-002'
      }
    },
    {
      name: 'Test 3: Minimal Payload',
      payload: {
        title: 'Minimal Test',
        topic: 'all_users'
      }
    },
    {
      name: 'Test 4: Invalid Payload (should fail gracefully)',
      payload: {
        // Missing title and body
        topic: 'all_users'
      }
    },
    {
      name: 'Test 5: User-Specific Notification (will fail without valid user)',
      payload: {
        title: 'User Test',
        body: 'Testing user-specific notification',
        target_user_id: 'test-user-123',
        target_user_type: 'customer',
        admin_id: 'test-admin-003'
      }
    }
  ]

  for (const test of tests) {
    console.log(`\n🔬 ${test.name}`)
    console.log('-'.repeat(40))
    
    try {
      const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(test.payload)
      })

      const result = await response.json()
      
      console.log(`Status: ${response.status}`)
      console.log(`Success: ${result.success}`)
      
      if (result.success) {
        console.log(`✅ PASS: ${result.message}`)
        console.log(`API Version: ${result.api_version}`)
        console.log(`Project ID: ${result.project_id}`)
        if (result.message_name) {
          console.log(`Message Name: ${result.message_name}`)
        }
      } else {
        console.log(`❌ FAIL: ${result.error}`)
        if (result.error_type) {
          console.log(`Error Type: ${result.error_type}`)
        }
        if (result.troubleshooting) {
          console.log(`Troubleshooting: ${result.troubleshooting}`)
        }
      }
      
    } catch (error) {
      console.log(`💥 ERROR: ${error.message}`)
    }
  }

  console.log('\n' + '='.repeat(60))
  console.log('🏁 FCM Service Account Testing Complete')
  console.log('\n📋 Next Steps:')
  console.log('1. If tests fail with authentication errors, configure FIREBASE_SERVICE_ACCOUNT')
  console.log('2. If tests pass, try sending notifications from the admin panel')
  console.log('3. Check Supabase edge function logs for detailed information')
  console.log('4. Monitor admin_action_logs table for audit trail')
}

/**
 * Test environment variable configuration
 */
async function testEnvironmentConfig() {
  console.log('\n🔧 Testing Environment Configuration')
  console.log('-'.repeat(40))
  
  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/send-push-notification`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({}) // Empty payload to trigger validation
    })

    const result = await response.json()
    
    if (result.error && result.error.includes('FIREBASE_SERVICE_ACCOUNT')) {
      console.log('⚠️  FIREBASE_SERVICE_ACCOUNT not configured')
      console.log('📝 Please configure the environment variable in Supabase Dashboard')
      return false
    } else if (result.error && result.error.includes('Missing required fields')) {
      console.log('✅ FIREBASE_SERVICE_ACCOUNT is configured')
      console.log('✅ Edge function is responding correctly')
      return true
    } else {
      console.log('🤔 Unexpected response:', result)
      return false
    }
    
  } catch (error) {
    console.log(`💥 Configuration test failed: ${error.message}`)
    return false
  }
}

/**
 * Main test runner
 */
async function main() {
  console.log('🚀 Firebase FCM Service Account Test Suite')
  console.log('🎯 Testing upgraded edge function implementation')
  console.log('')
  
  // Test environment configuration first
  const configOk = await testEnvironmentConfig()
  
  if (configOk) {
    // Run comprehensive tests
    await testFCMServiceAccount()
  } else {
    console.log('\n❌ Environment configuration issues detected')
    console.log('Please configure FIREBASE_SERVICE_ACCOUNT before running full tests')
  }
}

// Run tests if this script is executed directly
if (typeof window === 'undefined') {
  main().catch(console.error)
}

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { testFCMServiceAccount, testEnvironmentConfig }
}
