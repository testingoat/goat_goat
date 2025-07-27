// Test Direct Odoo Integration with Minimal Approach
// This verifies the exact logic used in the webhook works

async function testDirectOdooMinimal() {
  console.log('🧪 Testing Direct Odoo Integration with Minimal Approach...');
  
  const productData = {
    name: 'FINAL TEST',
    list_price: 99.0,
    seller_id: 'Prabhu A',
    seller_uid: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
    default_code: 'FINAL_TEST_' + Date.now(),
    product_type: 'meat',
    state: 'pending',
    description: 'Final test to verify webhook logic'
  };

  try {
    console.log(`🚀 FINAL TEST - Starting Odoo product creation`);
    console.log(`🚀 FINAL TEST - Product data: ${JSON.stringify(productData)}`);
    
    // Hard-coded values that we know work (same as webhook)
    const odooUrl = "https://goatgoat.xyz/";
    const odooDb = "staging";
    const odooUsername = "admin";
    const odooPassword = "admin";

    console.log(`🔐 FINAL TEST - Authenticating with Odoo...`);
    
    // Step 1: Authenticate
    const authResponse = await fetch(`${odooUrl}/web/session/authenticate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: { db: odooDb, login: odooUsername, password: odooPassword },
        id: Math.random(),
      }),
    });

    const authResult = await authResponse.json();
    console.log(`🔐 FINAL TEST - Auth status: ${authResponse.status}`);
    
    if (!authResult.result || !authResult.result.uid) {
      throw new Error(`Authentication failed: ${JSON.stringify(authResult)}`);
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`🔐 FINAL TEST - Auth successful, cookie: ${sessionCookie ? 'Present' : 'Missing'}`);

    // Step 2: Create product with minimal data (EXACT SAME AS WEBHOOK)
    const minimalProductData = {
      name: `${productData.name} (by ${productData.seller_id})`,
      list_price: productData.list_price || 0,
      default_code: productData.default_code || `GOAT_${Date.now()}`,
      description: `Seller: ${productData.seller_id} (${productData.seller_uid})`,
      categ_id: 1,
      type: 'product',
    };

    console.log(`📦 FINAL TEST - Creating product: ${JSON.stringify(minimalProductData)}`);

    const createResponse = await fetch(`${odooUrl}/web/dataset/call_kw`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'product.template',
          method: 'create',
          args: [minimalProductData],
          kwargs: {},
        },
        id: Math.random(),
      }),
    });

    const createResult = await createResponse.json();
    console.log(`📦 FINAL TEST - Create response status: ${createResponse.status}`);
    console.log(`📦 FINAL TEST - Create result: ${JSON.stringify(createResult)}`);

    if (createResult.error) {
      throw new Error(`Product creation failed: ${JSON.stringify(createResult.error)}`);
    }

    const odooProductId = createResult.result;
    console.log(`✅ FINAL TEST - SUCCESS! Product created with ID: ${odooProductId}`);

    return {
      success: true,
      odoo_product_id: odooProductId,
      message: 'Direct Odoo integration working perfectly'
    };

  } catch (error) {
    console.error(`❌ FINAL TEST - ERROR: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Direct Odoo integration failed'
    };
  }
}

// Run the test
testDirectOdooMinimal().then(result => {
  console.log('\n📊 Final Direct Odoo Test Result:', result);
  
  if (result.success) {
    console.log('\n🎉 DIRECT ODOO INTEGRATION WORKING!');
    console.log(`✅ Product created in Odoo with ID: ${result.odoo_product_id}`);
    console.log('✅ The webhook should use this exact same logic');
    console.log('✅ If webhook still fails, there might be environment variable issues');
  } else {
    console.log('\n❌ DIRECT ODOO INTEGRATION FAILED');
    console.log(`❌ Error: ${result.error}`);
    console.log('❌ This explains why the webhook is also failing');
  }
  
  process.exit(result.success ? 0 : 1);
});
