// Test Updated Webhook with Seller Creation
// This script tests the updated webhook that creates sellers in Odoo

const WEBHOOK_URL = 'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-approval-webhook';
const API_KEY = 'dev-webhook-api-key-2024-secure-odoo-integration';

async function testUpdatedWebhook() {
  console.log('🧪 Testing Updated Webhook with Seller Creation...');
  
  try {
    const testPayload = {
      product_id: 'test-product-' + Date.now(),
      seller_id: 'test-seller-uuid-' + Date.now(),
      product_type: 'meat',
      approval_status: 'pending',
      updated_at: new Date().toISOString(),
      product_data: {
        name: 'Test Product - ' + new Date().toISOString(),
        list_price: 15.0,
        seller_id: 'Test Seller - ' + Date.now(), // This is the seller name
        seller_uid: 'test-seller-uuid-' + Date.now(), // This is the UUID
        default_code: 'TEST_' + Date.now(),
        product_type: 'meat',
        state: 'pending',
        description: 'Test product for updated webhook verification'
      }
    };

    console.log('📤 Sending payload:', JSON.stringify(testPayload, null, 2));

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

    if (response.status === 200) {
      if (responseData.odoo_product_id) {
        console.log('✅ SUCCESS: Product created in Odoo with ID:', responseData.odoo_product_id);
        console.log('✅ SUCCESS: Odoo sync status:', responseData.odoo_sync);
        return {
          success: true,
          odooProductId: responseData.odoo_product_id,
          odooSync: responseData.odoo_sync,
          message: 'Webhook test successful - Odoo integration working'
        };
      } else {
        console.log('⚠️ WARNING: Webhook succeeded but no Odoo product ID returned');
        console.log('⚠️ This might indicate Odoo integration is still failing');
        return {
          success: false,
          message: 'Webhook succeeded but Odoo integration failed',
          responseData
        };
      }
    } else {
      throw new Error(`Webhook failed with status ${response.status}: ${JSON.stringify(responseData)}`);
    }

  } catch (error) {
    console.error(`❌ Webhook test failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Webhook test failed'
    };
  }
}

// Run the test
testUpdatedWebhook().then(result => {
  console.log('\n📊 Final Test Result:', result);
  
  if (result.success) {
    console.log('\n🎉 WEBHOOK UPDATE SUCCESSFUL!');
    console.log('✅ Seller creation and product creation in Odoo is now working');
    console.log('✅ The Flutter app should now successfully sync products to Odoo');
  } else {
    console.log('\n❌ WEBHOOK UPDATE FAILED');
    console.log('❌ Further investigation needed for Odoo integration');
  }
  
  process.exit(result.success ? 0 : 1);
});
