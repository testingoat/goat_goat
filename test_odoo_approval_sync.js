// Test the new Odoo approval sync webhook
const supabaseUrl = 'https://oaynfzqjielnsipttzbs.supabase.co';

async function testOdooApprovalSync() {
  console.log('🧪 Testing Odoo Approval Sync Webhook...');
  
  try {
    // Test payload that simulates what Odoo custom module will send
    const testPayload = {
      odoo_product_id: 25, // Use a real Odoo product ID
      product_name: 'Test Product Approval',
      approval_status: 'approved',
      state: 'approved',
      default_code: 'GOAT_1755265433771',
      updated_at: new Date().toISOString(),
      webhook_source: 'odoo_test'
    };

    console.log('📤 Sending test payload:', JSON.stringify(testPayload, null, 2));

    const response = await fetch(`${supabaseUrl}/functions/v1/odoo-approval-sync?token=odoo-goatgoat-sync-2024`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-odoo-webhook-token': 'odoo-goatgoat-sync-2024'
      },
      body: JSON.stringify(testPayload)
    });

    const responseData = await response.json();
    
    console.log('📥 Response Status:', response.status);
    console.log('📥 Response Data:', JSON.stringify(responseData, null, 2));

    if (response.status === 200) {
      console.log('✅ SUCCESS: Odoo approval sync webhook is working!');
      if (responseData.auto_activated) {
        console.log('🎉 BONUS: Product was auto-activated after approval!');
      }
    } else if (response.status === 404) {
      console.log('⚠️ EXPECTED: Product not found (this is normal for test data)');
      console.log('ℹ️ The webhook is working correctly, just needs real product data');
    } else if (response.status === 401) {
      console.log('❌ AUTHENTICATION FAILED: Check the webhook token');
    } else {
      console.log(`❌ UNEXPECTED STATUS: ${response.status}`);
    }

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

async function testWithRealProduct() {
  console.log('\n🧪 Testing with real product data...');
  
  try {
    // Use the actual product ID from the user's example
    const realPayload = {
      odoo_product_id: 27, // This should be a real Odoo product ID
      product_name: 'test 7',
      approval_status: 'approved',
      state: 'approved', 
      default_code: 'GOAT_1755265433771',
      updated_at: new Date().toISOString(),
      webhook_source: 'manual_test'
    };

    console.log('📤 Sending real product payload:', JSON.stringify(realPayload, null, 2));

    const response = await fetch(`${supabaseUrl}/functions/v1/odoo-approval-sync?token=odoo-goatgoat-sync-2024`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-odoo-webhook-token': 'odoo-goatgoat-sync-2024'
      },
      body: JSON.stringify(realPayload)
    });

    const responseData = await response.json();
    
    console.log('📥 Response Status:', response.status);
    console.log('📥 Response Data:', JSON.stringify(responseData, null, 2));

    if (response.status === 200) {
      console.log('🎉 SUCCESS: Real product approval sync worked!');
      console.log(`✅ Product "${responseData.product_name}" status updated to: ${responseData.status}`);
    } else {
      console.log(`❌ Failed with status: ${response.status}`);
    }

  } catch (error) {
    console.error('❌ Real product test failed:', error);
  }
}

// Run both tests
testOdooApprovalSync().then(() => {
  return testWithRealProduct();
});
