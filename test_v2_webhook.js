// Test V2 webhook payload to verify the fix
const supabaseUrl = 'https://oaynfzqjielnsipttzbs.supabase.co';

async function testV2Webhook() {
  console.log('🧪 Testing V2 webhook payload...');
  
  try {
    // V2 payload format (matches what Flutter app now sends)
    const v2Payload = {
      payload_version: 'v2', // 🚀 CRITICAL: This should fix the 400 error
      product_id: '9f70ca1a-8fca-47d0-86ec-8344ea104d68', // Use the actual product ID from user's example
      seller_id: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
      product_type: 'meat',
      approval_status: 'pending',
      updated_at: new Date().toISOString(),
      product_data: {
        name: 'test 7',
        list_price: 5.00,
        seller_id: 'Test Seller Name', // This should be the seller name, not UUID
        seller_uid: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b', // This is the UUID
        default_code: `GOAT_${Date.now()}`,
        product_type: 'meat',
        state: 'pending',
        description: 'Test product for V2 webhook'
      }
    };

    console.log('📤 Sending V2 payload:', JSON.stringify(v2Payload, null, 2));

    const response = await fetch(`${supabaseUrl}/functions/v1/product-sync-webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': 'dev-webhook-api-key-2024-secure-odoo-integration'
      },
      body: JSON.stringify(v2Payload)
    });

    const responseData = await response.json();
    
    console.log('📥 Response Status:', response.status);
    console.log('📥 Response Data:', JSON.stringify(responseData, null, 2));

    if (response.status === 200) {
      console.log('✅ SUCCESS: V2 webhook accepted the payload!');
      if (responseData.odoo_product_id) {
        console.log(`🎉 ODOO SUCCESS: Product created with ID: ${responseData.odoo_product_id}`);
      } else {
        console.log('⚠️ WARNING: Webhook succeeded but no odoo_product_id returned');
      }
    } else if (response.status === 400) {
      console.log('❌ STILL FAILING: HTTP 400 error');
      console.log('Error details:', responseData.error);
    } else {
      console.log(`❌ UNEXPECTED STATUS: ${response.status}`);
    }

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

testV2Webhook();
