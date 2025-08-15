// Test the updated product-approval-webhook with Odoo authentication
const supabaseUrl = 'https://oaynfzqjielnsipttzbs.supabase.co';

async function testOdooWebhookFix() {
  console.log('🧪 Testing Updated Product Approval Webhook with Odoo Auth...');
  
  try {
    // Test Odoo-style payload that simulates what the custom module will send
    const odooPayload = {
      odoo_product_id: 27, // Use a real Odoo product ID from previous tests
      product_name: 'test 7',
      approval_status: 'approved',
      state: 'approved',
      default_code: 'GOAT_1755265433771',
      updated_at: new Date().toISOString(),
      webhook_source: 'odoo_custom_module'
    };

    console.log('📤 Sending Odoo-style payload:', JSON.stringify(odooPayload, null, 2));

    const response = await fetch(`${supabaseUrl}/functions/v1/product-approval-webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-odoo-webhook-token': 'odoo-goatgoat-sync-2024'
      },
      body: JSON.stringify(odooPayload)
    });

    const responseData = await response.json();
    
    console.log('📥 Response Status:', response.status);
    console.log('📥 Response Data:', JSON.stringify(responseData, null, 2));

    if (response.status === 200) {
      console.log('🎉 SUCCESS: Odoo webhook authentication is working!');
      console.log(`✅ Product approval status updated successfully`);
      if (responseData.auto_activated) {
        console.log('🚀 BONUS: Product was auto-activated after approval!');
      }
    } else if (response.status === 404) {
      console.log('⚠️ EXPECTED: Product not found with that odoo_product_id');
      console.log('ℹ️ This means the webhook is working but needs real product data');
      console.log('ℹ️ Try creating a product in Flutter first, then test approval');
    } else if (response.status === 401) {
      console.log('❌ AUTHENTICATION FAILED: Odoo token not accepted');
    } else {
      console.log(`❌ UNEXPECTED STATUS: ${response.status}`);
    }

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

async function testFlutterWebhookStillWorks() {
  console.log('\n🧪 Testing that Flutter webhook still works...');
  
  try {
    // Test Flutter-style payload to ensure backward compatibility
    const flutterPayload = {
      payload_version: 'v2',
      product_id: '9f70ca1a-8fca-47d0-86ec-8344ea104d68',
      seller_id: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
      product_type: 'meat',
      approval_status: 'approved',
      updated_at: new Date().toISOString(),
      product_data: {
        name: 'test 7',
        list_price: 5.00,
        seller_id: 'Test Seller Name',
        seller_uid: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
        default_code: 'GOAT_TEST_FLUTTER',
        product_type: 'meat',
        state: 'pending',
        description: 'Test Flutter compatibility'
      }
    };

    console.log('📤 Sending Flutter-style payload with API key...');

    const response = await fetch(`${supabaseUrl}/functions/v1/product-approval-webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': 'dev-webhook-api-key-2024-secure-odoo-integration'
      },
      body: JSON.stringify(flutterPayload)
    });

    const responseData = await response.json();
    
    console.log('📥 Response Status:', response.status);
    console.log('📥 Response Data:', JSON.stringify(responseData, null, 2));

    if (response.status === 200) {
      console.log('✅ SUCCESS: Flutter webhook compatibility maintained!');
    } else if (response.status === 404) {
      console.log('⚠️ EXPECTED: Product not found (normal for test data)');
      console.log('✅ Flutter authentication is working correctly');
    } else {
      console.log(`❌ Flutter compatibility issue: ${response.status}`);
    }

  } catch (error) {
    console.error('❌ Flutter compatibility test failed:', error);
  }
}

// Run both tests
testOdooWebhookFix().then(() => {
  return testFlutterWebhookStillWorks();
});
