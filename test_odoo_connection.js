// Test Odoo Connection Script
// This script tests the direct connection to Odoo to identify integration issues

const ODOO_URL = "https://goatgoat.xyz/";
const ODOO_DB = "staging";
const ODOO_USERNAME = "admin";
const ODOO_PASSWORD = "admin";

async function testOdooConnection() {
  console.log('🔍 Testing Odoo Connection...');
  console.log(`📍 URL: ${ODOO_URL}`);
  console.log(`📍 Database: ${ODOO_DB}`);
  console.log(`📍 Username: ${ODOO_USERNAME}`);
  
  try {
    // Step 1: Test basic connectivity
    console.log('\n🌐 Step 1: Testing basic connectivity...');
    const pingResponse = await fetch(ODOO_URL);
    console.log(`✅ Basic connectivity: ${pingResponse.status} ${pingResponse.statusText}`);
    
    // Step 2: Test authentication
    console.log('\n🔐 Step 2: Testing authentication...');
    const authResponse = await fetch(`${ODOO_URL}/web/session/authenticate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          db: ODOO_DB,
          login: ODOO_USERNAME,
          password: ODOO_PASSWORD,
        },
        id: Math.random(),
      }),
    });
    
    const authResult = await authResponse.json();
    console.log(`📥 Auth Response Status: ${authResponse.status}`);
    console.log(`📥 Auth Response: ${JSON.stringify(authResult, null, 2)}`);
    
    if (!authResult.result || !authResult.result.uid) {
      throw new Error('❌ Authentication failed - Invalid credentials or database');
    }
    
    console.log(`✅ Authentication successful - User ID: ${authResult.result.uid}`);
    
    // Step 3: Test product creation
    console.log('\n📦 Step 3: Testing product creation...');
    const testProductData = {
      name: 'Test Product - ' + new Date().toISOString(),
      list_price: 10.0,
      seller_id: 'Test Seller',
      seller_uid: 'test-uuid-123',
      default_code: 'TEST_' + Date.now(),
      product_type: 'meat',
      state: 'pending',
      description: 'Test product for connection verification'
    };
    
    const createResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': authResponse.headers.get('set-cookie') || '',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'product.template',
          method: 'create',
          args: [testProductData],
          kwargs: {},
        },
        id: Math.random(),
      }),
    });
    
    const createResult = await createResponse.json();
    console.log(`📥 Create Response Status: ${createResponse.status}`);
    console.log(`📥 Create Response: ${JSON.stringify(createResult, null, 2)}`);
    
    if (createResult.error) {
      throw new Error(`❌ Product creation failed: ${createResult.error.message}`);
    }
    
    console.log(`✅ Product created successfully - ID: ${createResult.result}`);
    console.log('\n🎉 All tests passed! Odoo integration is working correctly.');
    
    return {
      success: true,
      productId: createResult.result,
      message: 'Odoo connection test successful'
    };
    
  } catch (error) {
    console.error(`❌ Odoo connection test failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Odoo connection test failed'
    };
  }
}

// Run the test
testOdooConnection().then(result => {
  console.log('\n📊 Final Result:', result);
  process.exit(result.success ? 0 : 1);
});
