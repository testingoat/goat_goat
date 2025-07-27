// Test Webhook with Real Seller Data from Flutter App
// This script tests the webhook with the exact same data that the Flutter app is sending

const WEBHOOK_URL = 'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-approval-webhook';
const API_KEY = 'dev-webhook-api-key-2024-secure-odoo-integration';

async function testRealSellerWebhook() {
  console.log('🧪 Testing Webhook with Real Seller Data...');
  
  try {
    // Use a fresh payload to test the fixed webhook
    const realPayload = {
      product_id: 'test-product-' + Date.now(),
      seller_id: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
      product_type: 'meat',
      approval_status: 'pending',
      updated_at: new Date().toISOString(),
      product_data: {
        name: 'Test Fixed Webhook - ' + Date.now(),
        list_price: 1.0,
        seller_id: 'Prabhu A',
        seller_uid: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
        default_code: 'TEST_FIXED_' + Date.now(),
        product_type: 'meat',
        state: 'pending',
        description: 'Testing fixed webhook with minimal approach'
      }
    };

    console.log('📤 Sending real payload:', JSON.stringify(realPayload, null, 2));

    const response = await fetch(WEBHOOK_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': API_KEY,
        'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA',
      },
      body: JSON.stringify(realPayload),
    });

    console.log(`📥 Response Status: ${response.status} ${response.statusText}`);
    
    const responseData = await response.json();
    console.log('📥 Response Data:', JSON.stringify(responseData, null, 2));

    // Analyze the response
    if (response.status === 200) {
      if (responseData.odoo_product_id) {
        console.log('✅ SUCCESS: Odoo integration working!');
        console.log(`✅ Odoo Product ID: ${responseData.odoo_product_id}`);
        console.log(`✅ Odoo Sync Status: ${responseData.odoo_sync}`);
        return {
          success: true,
          odooProductId: responseData.odoo_product_id,
          message: 'Webhook and Odoo integration working correctly'
        };
      } else {
        console.log('❌ ISSUE: Webhook succeeded but Odoo integration failed');
        console.log(`❌ Odoo Product ID: ${responseData.odoo_product_id}`);
        console.log(`❌ Odoo Sync Status: ${responseData.odoo_sync}`);
        console.log('❌ This indicates the createProductInOdoo function is failing internally');
        return {
          success: false,
          issue: 'odoo_integration_failure',
          message: 'Webhook works but Odoo integration fails internally',
          responseData
        };
      }
    } else {
      throw new Error(`Webhook failed with status ${response.status}: ${JSON.stringify(responseData)}`);
    }

  } catch (error) {
    console.error(`❌ Test failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Webhook test failed'
    };
  }
}

// Run the test
testRealSellerWebhook().then(result => {
  console.log('\n📊 Final Test Result:', result);
  
  if (result.success) {
    console.log('\n🎉 WEBHOOK AND ODOO INTEGRATION WORKING!');
    console.log('✅ The issue has been resolved');
  } else if (result.issue === 'odoo_integration_failure') {
    console.log('\n🔍 WEBHOOK WORKS BUT ODOO INTEGRATION FAILS');
    console.log('❌ The createProductInOdoo function is failing internally');
    console.log('❌ Need to debug the Odoo authentication, seller creation, or product creation steps');
    console.log('❌ The webhook is catching the error and continuing, which is why it returns success: true');
  } else {
    console.log('\n❌ WEBHOOK TEST FAILED');
    console.log('❌ Basic webhook communication issue');
  }
  
  process.exit(result.success ? 0 : 1);
});
