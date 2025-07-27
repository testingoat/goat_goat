// Test Minimal Webhook Approach
// This script tests the exact minimal approach that should work

const ODOO_URL = "https://goatgoat.xyz/";
const ODOO_DB = "staging";
const ODOO_USERNAME = "admin";
const ODOO_PASSWORD = "admin";

async function testMinimalWebhookApproach() {
  console.log('🧪 Testing Minimal Webhook Approach...');
  
  const productData = {
    name: 'gggg',
    list_price: 1.0,
    seller_id: 'Prabhu A',
    seller_uid: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
    default_code: 'GOAT_1753559859391',
    product_type: 'meat',
    state: 'pending',
    description: null
  };

  try {
    console.log(`🔗 ODOO DEBUG - Creating product in Odoo: ${productData.name}`);
    console.log(`🔍 ODOO DEBUG - Product data: ${JSON.stringify(productData)}`);
    console.log(`🔍 ODOO DEBUG - Odoo URL: ${ODOO_URL}`);
    console.log(`🔍 ODOO DEBUG - Odoo DB: ${ODOO_DB}`);
    console.log(`🔍 ODOO DEBUG - Odoo Username: ${ODOO_USERNAME}`);

    // Step 1: Authenticate with Odoo
    console.log(`🔐 ODOO DEBUG - Starting authentication...`);
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
    console.log(`🔐 ODOO DEBUG - Auth response status: ${authResponse.status}`);
    console.log(`🔐 ODOO DEBUG - Auth result: ${JSON.stringify(authResult)}`);

    if (!authResult.result || !authResult.result.uid) {
      throw new Error('Odoo authentication failed');
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`🔐 ODOO DEBUG - Session cookie: ${sessionCookie ? 'Present' : 'Missing'}`);

    // Step 2: Create product with minimal data (FIXED APPROACH)
    console.log(`📦 ODOO DEBUG - Creating product with minimal data approach`);
    
    // Use minimal product data that works (no custom seller fields)
    const odooProductData = {
      name: `${productData.name} (by ${productData.seller_id})`, // Include seller in name
      list_price: productData.list_price || 0,
      default_code: productData.default_code,
      description: `${productData.description || ''}\n\nSeller: ${productData.seller_id} (${productData.seller_uid})`,
      categ_id: 1, // Default category
      type: 'product',
      // Remove all custom seller fields that don't exist in the model
    };

    console.log(`📦 ODOO DEBUG - Minimal product data: ${JSON.stringify(odooProductData)}`);

    const createResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'product.template',
          method: 'create',
          args: [odooProductData],
          kwargs: {},
        },
        id: Math.random(),
      }),
    });

    const createResult = await createResponse.json();
    console.log(`📦 ODOO DEBUG - Product creation response status: ${createResponse.status}`);
    console.log(`📦 ODOO DEBUG - Product creation result: ${JSON.stringify(createResult)}`);

    if (createResult.error) {
      throw new Error(`Product creation failed: ${createResult.error.message}`);
    }

    const odooProductId = createResult.result;
    console.log(`✅ ODOO SUCCESS - Product created with ID: ${odooProductId}`);

    return {
      success: true,
      odoo_product_id: odooProductId,
      message: 'Product created successfully with minimal approach'
    };

  } catch (error) {
    console.error(`❌ ODOO ERROR - Minimal approach failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Minimal approach failed'
    };
  }
}

// Run the test
testMinimalWebhookApproach().then(result => {
  console.log('\n📊 Final Minimal Approach Test Result:', result);
  
  if (result.success) {
    console.log('\n🎉 MINIMAL APPROACH WORKING!');
    console.log(`✅ Product created in Odoo with ID: ${result.odoo_product_id}`);
    console.log('✅ This approach should work in the webhook');
    console.log('✅ The webhook can now be updated to use this exact logic');
  } else {
    console.log('\n❌ MINIMAL APPROACH FAILED');
    console.log(`❌ Error: ${result.error}`);
    console.log('❌ Need to investigate further');
  }
  
  process.exit(result.success ? 0 : 1);
});
