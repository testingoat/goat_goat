// Check Existing Sellers in Odoo
// This script checks what sellers exist in the Odoo system

const ODOO_URL = "https://goatgoat.xyz/";
const ODOO_DB = "staging";
const ODOO_USERNAME = "admin";
const ODOO_PASSWORD = "admin";

async function checkOdooSellers() {
  console.log('🔍 Checking Odoo Sellers...');
  
  try {
    // Step 1: Authenticate
    console.log('\n🔐 Step 1: Authenticating...');
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
    if (!authResult.result || !authResult.result.uid) {
      throw new Error('Authentication failed');
    }
    console.log(`✅ Authenticated as User ID: ${authResult.result.uid}`);
    
    // Step 2: Check for seller-related models
    console.log('\n📋 Step 2: Checking available models...');
    const modelsResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': authResponse.headers.get('set-cookie') || '',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'ir.model',
          method: 'search_read',
          args: [
            [['model', 'ilike', 'seller']],
            ['model', 'name']
          ],
          kwargs: {},
        },
        id: Math.random(),
      }),
    });
    
    const modelsResult = await modelsResponse.json();
    console.log('📋 Seller-related models:', JSON.stringify(modelsResult.result, null, 2));
    
    // Step 3: Check res.partner (users/sellers)
    console.log('\n👥 Step 3: Checking res.partner records...');
    const partnersResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': authResponse.headers.get('set-cookie') || '',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'res.partner',
          method: 'search_read',
          args: [
            [],
            ['id', 'name', 'email', 'is_company', 'supplier_rank', 'customer_rank']
          ],
          kwargs: { limit: 10 },
        },
        id: Math.random(),
      }),
    });
    
    const partnersResult = await partnersResponse.json();
    console.log('👥 Partners/Users:', JSON.stringify(partnersResult.result, null, 2));
    
    // Step 4: Try to find the specific seller validation model
    console.log('\n🔍 Step 4: Checking for custom seller models...');
    const customModelsResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': authResponse.headers.get('set-cookie') || '',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'ir.model',
          method: 'search_read',
          args: [
            [['model', 'ilike', 'vendor']],
            ['model', 'name']
          ],
          kwargs: {},
        },
        id: Math.random(),
      }),
    });
    
    const customModelsResult = await customModelsResponse.json();
    console.log('🔍 Vendor-related models:', JSON.stringify(customModelsResult.result, null, 2));
    
    return {
      success: true,
      message: 'Seller check completed'
    };
    
  } catch (error) {
    console.error(`❌ Seller check failed: ${error.message}`);
    return {
      success: false,
      error: error.message
    };
  }
}

// Run the check
checkOdooSellers().then(result => {
  console.log('\n📊 Final Result:', result);
  process.exit(result.success ? 0 : 1);
});
