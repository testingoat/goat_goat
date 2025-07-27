// Test script for the product-approval-webhook
const testWebhook = async () => {
  const webhookUrl = 'https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-approval-webhook';
  
  // Sample payload matching what the Flutter app sends
  const testPayload = {
    product_id: 'test-product-id-123',
    seller_id: 'test-seller-id-456',
    product_type: 'meat',
    approval_status: 'pending',
    product_data: {
      name: 'Test Goat Meat',
      list_price: 500.0,
      default_code: 'MEAT_test123',
      description: 'Fresh test goat meat',
      seller_id: 'Test Seller Name',
      seller_uid: 'test-seller-id-456',
      product_type: 'meat'
    }
  };

  const headers = {
    'Content-Type': 'application/json',
    'x-api-key': 'dev-webhook-api-key-2024-secure-odoo-integration',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA'
  };

  try {
    console.log('🚀 Testing webhook endpoint...');
    console.log('📤 Payload:', JSON.stringify(testPayload, null, 2));
    
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: headers,
      body: JSON.stringify(testPayload)
    });

    console.log('📥 Response Status:', response.status);
    console.log('📥 Response Headers:', Object.fromEntries(response.headers.entries()));
    
    const responseData = await response.text();
    console.log('📥 Response Body:', responseData);
    
    if (response.ok) {
      console.log('✅ Webhook test successful!');
      try {
        const jsonData = JSON.parse(responseData);
        console.log('📊 Parsed Response:', JSON.stringify(jsonData, null, 2));
      } catch (e) {
        console.log('⚠️ Response is not valid JSON');
      }
    } else {
      console.log('❌ Webhook test failed!');
    }
    
  } catch (error) {
    console.error('❌ Error testing webhook:', error);
  }
};

// Run the test
testWebhook();