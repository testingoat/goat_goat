// Test Odoo Status Sync Webhook
// This script tests the new odoo-status-sync webhook functionality

const WEBHOOK_URL = 'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/odoo-status-sync';
const API_KEY = 'dev-webhook-api-key-2024-secure-odoo-integration';

async function testStatusSyncWebhook() {
  console.log('🧪 Testing Odoo Status Sync Webhook...');
  
  try {
    // Test with a product that should exist in Odoo
    const testPayload = {
      product_id: 'bd33ba701-4dfd-4e74-90a9-2021193b4052', // Recent product from logs
      product_name: 'test (by Prabhu A)', // Product name as it appears in Odoo
      current_status: 'pending',
    };

    console.log('📤 Sending status sync payload:', JSON.stringify(testPayload, null, 2));

    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY,
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA',
      },
      body: JSON.stringify(testPayload),
    });

    console.log(`📥 Response Status: ${response.status} ${response.statusText}`);
    
    const responseData = await response.json();
    console.log('📥 Response Data:', JSON.stringify(responseData, null, 2));

    // Analyze the response
    if (response.status === 200 && responseData.success) {
      console.log('✅ SUCCESS: Status sync webhook working!');
      console.log(`📊 Current Status: ${responseData.current_status}`);
      console.log(`📊 Odoo Status: ${responseData.odoo_status}`);
      console.log(`📊 Status Changed: ${responseData.status_changed}`);
      
      if (responseData.odoo_product_id) {
        console.log(`📊 Odoo Product ID: ${responseData.odoo_product_id}`);
      }

      return {
        success: true,
        currentStatus: responseData.current_status,
        odooStatus: responseData.odoo_status,
        statusChanged: responseData.status_changed,
        message: 'Status sync webhook working correctly'
      };
    } else {
      throw new Error(`Status sync failed: ${responseData.error || 'Unknown error'}`);
    }

  } catch (error) {
    console.error(`❌ Status sync test failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Status sync webhook test failed'
    };
  }
}

// Test with a product that doesn't exist in Odoo
async function testStatusSyncNotFound() {
  console.log('\n🧪 Testing Status Sync with Non-Existent Product...');
  
  try {
    const testPayload = {
      product_id: 'non-existent-product-id',
      product_name: 'Non Existent Product',
      current_status: 'pending',
    };

    console.log('📤 Sending non-existent product payload:', JSON.stringify(testPayload, null, 2));

    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY,
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA',
      },
      body: JSON.stringify(testPayload),
    });

    const responseData = await response.json();
    console.log('📥 Non-existent product response:', JSON.stringify(responseData, null, 2));

    if (response.status === 200 && responseData.success && !responseData.status_changed) {
      console.log('✅ SUCCESS: Correctly handled non-existent product');
      return { success: true, message: 'Non-existent product handled correctly' };
    } else {
      throw new Error(`Unexpected response for non-existent product: ${JSON.stringify(responseData)}`);
    }

  } catch (error) {
    console.error(`❌ Non-existent product test failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Non-existent product test failed'
    };
  }
}

// Run both tests
async function runAllTests() {
  console.log('🚀 Starting Odoo Status Sync Webhook Tests...\n');

  const test1 = await testStatusSyncWebhook();
  const test2 = await testStatusSyncNotFound();

  console.log('\n📊 Final Test Results:');
  console.log('Test 1 (Existing Product):', test1.success ? '✅ PASSED' : '❌ FAILED');
  console.log('Test 2 (Non-Existent Product):', test2.success ? '✅ PASSED' : '❌ FAILED');

  const allPassed = test1.success && test2.success;
  
  if (allPassed) {
    console.log('\n🎉 ALL TESTS PASSED!');
    console.log('✅ The Odoo status sync webhook is working correctly');
    console.log('✅ The Flutter app can now sync approval status from Odoo');
  } else {
    console.log('\n❌ SOME TESTS FAILED');
    console.log('❌ The status sync functionality needs debugging');
  }

  process.exit(allPassed ? 0 : 1);
}

runAllTests();
