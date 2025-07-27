// Test Exact Odoo Integration with Real Data
// This script replicates the exact createProductInOdoo function logic

const ODOO_URL = "https://goatgoat.xyz/";
const ODOO_DB = "staging";
const ODOO_USERNAME = "admin";
const ODOO_PASSWORD = "admin";

async function testExactOdooIntegration() {
  console.log('🔍 Testing Exact Odoo Integration with Real Data...');
  
  // Use the exact same product data from the Flutter app
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

    // Step 2: Check if seller exists, create if not
    console.log(`👤 ODOO DEBUG - Checking if seller exists: ${productData.seller_id} (${productData.seller_uid})`);
    
    const searchSellerResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie,
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'res.partner',
          method: 'search_read',
          args: [
            [['name', '=', productData.seller_id]],
            ['id', 'name']
          ],
          kwargs: { limit: 1 },
        },
        id: Math.random(),
      }),
    });

    const searchSellerResult = await searchSellerResponse.json();
    console.log(`🔍 ODOO DEBUG - Seller search response status: ${searchSellerResponse.status}`);
    console.log(`🔍 ODOO DEBUG - Seller search result: ${JSON.stringify(searchSellerResult)}`);

    let sellerId;
    if (searchSellerResult.result && searchSellerResult.result.length > 0) {
      // Seller exists
      sellerId = searchSellerResult.result[0].id;
      console.log(`✅ ODOO DEBUG - Found existing seller with ID: ${sellerId}`);
    } else {
      // Create new seller
      console.log(`➕ ODOO DEBUG - Creating new seller: ${productData.seller_id}`);
      const createSellerResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Cookie': sessionCookie,
        },
        body: JSON.stringify({
          jsonrpc: '2.0',
          method: 'call',
          params: {
            model: 'res.partner',
            method: 'create',
            args: [{
              name: productData.seller_id,
              supplier_rank: 1,
              is_company: false,
              ref: productData.seller_uid,
            }],
            kwargs: {},
          },
          id: Math.random(),
        }),
      });

      const createSellerResult = await createSellerResponse.json();
      console.log(`➕ ODOO DEBUG - Seller creation response status: ${createSellerResponse.status}`);
      console.log(`➕ ODOO DEBUG - Seller creation result: ${JSON.stringify(createSellerResult)}`);

      if (createSellerResult.error) {
        throw new Error(`Failed to create seller: ${createSellerResult.error.message}`);
      }

      sellerId = createSellerResult.result;
      console.log(`✅ ODOO DEBUG - Created new seller with ID: ${sellerId}`);
    }

    // Step 3: Create product in Odoo with valid seller ID
    console.log(`📦 ODOO DEBUG - Creating product with seller ID: ${sellerId}`);
    
    const odooProductData = {
      name: productData.name,
      list_price: productData.list_price || 0,
      default_code: productData.default_code,
      description: productData.description || '',
      categ_id: 1,
      type: 'product',
      seller_name: productData.seller_id,
      seller_uid: productData.seller_uid,
      seller_id: sellerId,
      product_type: productData.product_type || 'meat',
      state: 'pending',
    };

    console.log(`📦 ODOO DEBUG - Final product data: ${JSON.stringify(odooProductData)}`);

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
      message: 'Product created successfully in Odoo'
    };

  } catch (error) {
    console.error(`❌ ODOO ERROR - Integration failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Odoo integration failed'
    };
  }
}

// Run the test
testExactOdooIntegration().then(result => {
  console.log('\n📊 Final Integration Test Result:', result);
  
  if (result.success) {
    console.log('\n🎉 ODOO INTEGRATION WORKING!');
    console.log(`✅ Product created in Odoo with ID: ${result.odoo_product_id}`);
    console.log('✅ The webhook should work with this exact logic');
  } else {
    console.log('\n❌ ODOO INTEGRATION FAILED');
    console.log(`❌ Error: ${result.error}`);
    console.log('❌ This explains why the webhook returns null odoo_product_id');
  }
  
  process.exit(result.success ? 0 : 1);
});
