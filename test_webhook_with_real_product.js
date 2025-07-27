// Test Webhook with Real Product from Flutter App
// This script tests the webhook with the exact product that was just created

const WEBHOOK_URL = 'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-approval-webhook';
const API_KEY = 'dev-webhook-api-key-2024-secure-odoo-integration';

async function testWebhookWithRealProduct() {
  console.log('🧪 Testing Webhook with Real Product from Flutter App...');
  
  try {
    // Use the latest payload from the Flutter app logs
    const realPayload = {
      product_id: 'b35e4feb-9261-468b-b6dc-731608a4e42b', // From latest Flutter logs
      seller_id: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',   // From Flutter logs
      product_type: 'meat',
      approval_status: 'pending',
      updated_at: '2025-07-27T02:03:09.232642',
      product_data: {
        name: 'hhuhh',
        list_price: 567.0,
        seller_id: 'Prabhu A',
        seller_uid: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
        default_code: 'GOAT_1753561988244',
        product_type: 'meat',
        state: 'pending',
        description: null
      }
    };

    console.log('📤 Sending real product payload:', JSON.stringify(realPayload, null, 2));

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

    // Analyze the response in detail
    if (response.status === 200) {
      if (responseData.odoo_product_id && responseData.odoo_product_id !== null) {
        console.log('✅ SUCCESS: Webhook and Odoo integration working!');
        console.log(`✅ Odoo Product ID: ${responseData.odoo_product_id}`);
        console.log(`✅ Odoo Sync Status: ${responseData.odoo_sync}`);
        return {
          success: true,
          odooProductId: responseData.odoo_product_id,
          message: 'Webhook and Odoo integration working correctly'
        };
      } else {
        console.log('❌ CRITICAL ISSUE: Webhook succeeded but Odoo integration still failing');
        console.log(`❌ Odoo Product ID: ${responseData.odoo_product_id}`);
        console.log(`❌ Odoo Sync Status: ${responseData.odoo_sync}`);
        console.log('❌ This means the webhook deployment or internal logic has issues');
        
        // The webhook is not using the new minimal approach or there's still an error
        return {
          success: false,
          issue: 'webhook_deployment_or_logic_issue',
          message: 'Webhook deployment failed or internal logic still has errors',
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
testWebhookWithRealProduct().then(result => {
  console.log('\n📊 Final Real Product Test Result:', result);
  
  if (result.success) {
    console.log('\n🎉 WEBHOOK FIXED AND WORKING!');
    console.log('✅ The Flutter app should now show non-null odoo_product_id');
  } else if (result.issue === 'webhook_deployment_or_logic_issue') {
    console.log('\n🔧 WEBHOOK DEPLOYMENT OR LOGIC ISSUE DETECTED');
    console.log('❌ The webhook is not using the new minimal approach');
    console.log('❌ Need to redeploy the webhook or fix the internal logic');
    console.log('❌ The webhook is still trying to use custom fields or has other errors');
  } else {
    console.log('\n❌ WEBHOOK TEST FAILED');
    console.log('❌ Basic webhook communication issue');
  }
  
  process.exit(result.success ? 0 : 1);
});
