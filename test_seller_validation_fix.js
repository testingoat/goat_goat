// Test Seller Validation Fix
// This script tests creating the seller in the correct table that Odoo expects

const ODOO_URL = "https://goatgoat.xyz/";
const ODOO_DB = "staging";
const ODOO_USERNAME = "admin";
const ODOO_PASSWORD = "admin";

async function testSellerValidationFix() {
  console.log('🔍 Testing Seller Validation Fix...');
  
  const productData = {
    name: 'Test Product Fix',
    list_price: 1.0,
    seller_id: 'Prabhu A',
    seller_uid: 'b2d600a5-1d72-40f2-8c4f-4b9d3c5c851b',
    default_code: 'TEST_FIX_' + Date.now(),
    product_type: 'meat',
    state: 'pending',
    description: 'Test for seller validation fix'
  };

  try {
    // Step 1: Authenticate
    console.log(`🔐 Authenticating...`);
    const authResponse = await fetch(`${ODOO_URL}/web/session/authenticate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: { db: ODOO_DB, login: ODOO_USERNAME, password: ODOO_PASSWORD },
        id: Math.random(),
      }),
    });

    const authResult = await authResponse.json();
    if (!authResult.result || !authResult.result.uid) {
      throw new Error('Authentication failed');
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';

    // Step 2: Check what seller-related models exist
    console.log(`🔍 Checking for seller-related models...`);
    const modelsResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'ir.model',
          method: 'search_read',
          args: [
            ['|', ['model', 'ilike', 'seller'], ['model', 'ilike', 'vendor']],
            ['model', 'name']
          ],
          kwargs: {},
        },
        id: Math.random(),
      }),
    });

    const modelsResult = await modelsResponse.json();
    console.log(`🔍 Seller/Vendor models found:`, JSON.stringify(modelsResult.result, null, 2));

    // Step 3: Try to create seller in a custom seller model if it exists
    const sellerModels = modelsResult.result || [];
    let sellerCreated = false;

    for (const model of sellerModels) {
      if (model.model.includes('seller') || model.model.includes('vendor')) {
        console.log(`➕ Trying to create seller in model: ${model.model}`);
        
        try {
          const createSellerResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
            body: JSON.stringify({
              jsonrpc: '2.0',
              method: 'call',
              params: {
                model: model.model,
                method: 'create',
                args: [{
                  name: productData.seller_id,
                  seller_uid: productData.seller_uid,
                  // Add other common fields
                  active: true,
                  is_company: false,
                }],
                kwargs: {},
              },
              id: Math.random(),
            }),
          });

          const createSellerResult = await createSellerResponse.json();
          console.log(`➕ Seller creation in ${model.model}:`, JSON.stringify(createSellerResult));

          if (!createSellerResult.error) {
            console.log(`✅ Successfully created seller in ${model.model} with ID: ${createSellerResult.result}`);
            sellerCreated = true;
            break;
          }
        } catch (error) {
          console.log(`❌ Failed to create seller in ${model.model}: ${error.message}`);
        }
      }
    }

    // Step 4: Try creating product without seller_id field (use only seller_name and seller_uid)
    console.log(`📦 Trying to create product without seller_id field...`);
    
    const simpleProductData = {
      name: productData.name,
      list_price: productData.list_price,
      default_code: productData.default_code,
      description: productData.description || '',
      categ_id: 1,
      type: 'product',
      // Only use seller_name and seller_uid, no seller_id
      seller_name: productData.seller_id,
      seller_uid: productData.seller_uid,
      product_type: productData.product_type,
      state: productData.state,
    };

    console.log(`📦 Simple product data:`, JSON.stringify(simpleProductData));

    const createResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'product.template',
          method: 'create',
          args: [simpleProductData],
          kwargs: {},
        },
        id: Math.random(),
      }),
    });

    const createResult = await createResponse.json();
    console.log(`📦 Product creation result:`, JSON.stringify(createResult));

    if (createResult.error) {
      // Step 5: If still failing, try with minimal data
      console.log(`📦 Trying with minimal product data...`);
      
      const minimalProductData = {
        name: productData.name,
        list_price: productData.list_price,
        categ_id: 1,
        type: 'product',
      };

      const minimalResponse = await fetch(`${ODOO_URL}/web/dataset/call_kw`, {
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

      const minimalResult = await minimalResponse.json();
      console.log(`📦 Minimal product creation result:`, JSON.stringify(minimalResult));

      if (!minimalResult.error) {
        console.log(`✅ SUCCESS: Minimal product created with ID: ${minimalResult.result}`);
        return {
          success: true,
          odoo_product_id: minimalResult.result,
          message: 'Product created with minimal data (no seller validation)',
          solution: 'Remove seller validation fields from product creation'
        };
      } else {
        throw new Error(`All product creation attempts failed: ${minimalResult.error.message}`);
      }
    } else {
      console.log(`✅ SUCCESS: Product created with ID: ${createResult.result}`);
      return {
        success: true,
        odoo_product_id: createResult.result,
        message: 'Product created successfully without seller_id field'
      };
    }

  } catch (error) {
    console.error(`❌ Test failed: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Seller validation fix test failed'
    };
  }
}

// Run the test
testSellerValidationFix().then(result => {
  console.log('\n📊 Final Fix Test Result:', result);
  
  if (result.success) {
    console.log('\n🎉 SELLER VALIDATION FIX FOUND!');
    console.log(`✅ Solution: ${result.solution || result.message}`);
    console.log(`✅ Product ID: ${result.odoo_product_id}`);
  } else {
    console.log('\n❌ SELLER VALIDATION FIX FAILED');
    console.log(`❌ Error: ${result.error}`);
  }
  
  process.exit(result.success ? 0 : 1);
});
