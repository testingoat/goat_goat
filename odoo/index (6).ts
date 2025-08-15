const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key'
};
// Function to check product approval status in Odoo
async function checkProductStatusInOdoo(productName) {
  console.log(`🔍 ODOO STATUS CHECK - Checking status for: ${productName}`);
  try {
    // Hard-coded Odoo credentials (same as working webhook)
    const odooUrl = "https://goatgoat.xyz/";
    const odooDb = "staging";
    const odooUsername = "admin";
    const odooPassword = "admin";
    console.log(`🔐 ODOO STATUS CHECK - Authenticating with Odoo...`);
    // Step 1: Authenticate with Odoo
    const authResponse = await fetch(`${odooUrl}/web/session/authenticate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          db: odooDb,
          login: odooUsername,
          password: odooPassword
        },
        id: Math.random()
      })
    });
    const authResult = await authResponse.json();
    console.log(`🔐 ODOO STATUS CHECK - Auth status: ${authResponse.status}`);
    if (!authResult.result || !authResult.result.uid) {
      throw new Error(`Authentication failed: ${JSON.stringify(authResult)}`);
    }
    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`🔐 ODOO STATUS CHECK - Auth successful`);
    // Step 2: Search for product by name in Odoo
    console.log(`🔍 ODOO STATUS CHECK - Searching for product: ${productName}`);
    const searchResponse = await fetch(`${odooUrl}/web/dataset/call_kw`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': sessionCookie
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          model: 'product.template',
          method: 'search_read',
          args: [
            [
              [
                'name',
                'ilike',
                productName
              ]
            ],
            [
              'id',
              'name',
              'state',
              'active'
            ] // Fields to retrieve
          ],
          kwargs: {
            limit: 1
          }
        },
        id: Math.random()
      })
    });
    const searchResult = await searchResponse.json();
    console.log(`🔍 ODOO STATUS CHECK - Search response: ${searchResponse.status}`);
    console.log(`🔍 ODOO STATUS CHECK - Search result: ${JSON.stringify(searchResult)}`);
    if (searchResult.error) {
      throw new Error(`Product search failed: ${JSON.stringify(searchResult.error)}`);
    }
    if (!searchResult.result || searchResult.result.length === 0) {
      console.log(`⚠️ ODOO STATUS CHECK - Product not found in Odoo: ${productName}`);
      return {
        success: true,
        found: false,
        status: 'not_found',
        message: 'Product not found in Odoo'
      };
    }
    const odooProduct = searchResult.result[0];
    console.log(`✅ ODOO STATUS CHECK - Product found: ${JSON.stringify(odooProduct)}`);
    // Map Odoo state to our approval status
    let approvalStatus = 'pending';
    if (odooProduct.state === 'approved' || odooProduct.active === true) {
      approvalStatus = 'approved';
    } else if (odooProduct.state === 'rejected' || odooProduct.active === false) {
      approvalStatus = 'rejected';
    }
    console.log(`📊 ODOO STATUS CHECK - Status mapping: ${odooProduct.state} → ${approvalStatus}`);
    return {
      success: true,
      found: true,
      status: approvalStatus,
      odoo_product_id: odooProduct.id,
      odoo_state: odooProduct.state,
      odoo_active: odooProduct.active,
      message: 'Product status retrieved successfully'
    };
  } catch (error) {
    console.error(`❌ ODOO STATUS CHECK - Error: ${error.message}`);
    return {
      success: false,
      error: error.message,
      message: 'Failed to check product status in Odoo'
    };
  }
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    console.log(`🚀 ODOO STATUS SYNC - Webhook called with method: ${req.method}`);
    // API Key authentication
    const apiKey = req.headers.get("x-api-key");
    const expectedApiKey = Deno.env.get("WEBHOOK_API_KEY");
    if (!apiKey || apiKey !== expectedApiKey) {
      console.log(`❌ ODOO STATUS SYNC - Unauthorized: ${apiKey} vs ${expectedApiKey}`);
      return new Response(JSON.stringify({
        error: "Unauthorized"
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        },
        status: 401
      });
    }
    console.log(`✅ ODOO STATUS SYNC - Authentication successful`);
    const payload = await req.json();
    console.log(`📥 ODOO STATUS SYNC - Payload: ${JSON.stringify(payload)}`);
    // Validate required fields
    if (!payload.product_id || !payload.product_name || !payload.current_status) {
      return new Response(JSON.stringify({
        error: "Missing required fields: product_id, product_name, current_status"
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        },
        status: 400
      });
    }
    // Check product status in Odoo
    const odooStatusResult = await checkProductStatusInOdoo(payload.product_name);
    if (!odooStatusResult.success) {
      return new Response(JSON.stringify({
        success: false,
        error: odooStatusResult.error,
        message: 'Failed to check Odoo status'
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        },
        status: 500
      });
    }
    if (!odooStatusResult.found) {
      // Product not found in Odoo, return current status
      return new Response(JSON.stringify({
        success: true,
        odoo_status: payload.current_status,
        status_changed: false,
        message: 'Product not found in Odoo, keeping current status'
      }), {
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        },
        status: 200
      });
    }
    // Compare statuses
    const odooStatus = odooStatusResult.status;
    const currentStatus = payload.current_status;
    const statusChanged = odooStatus !== currentStatus;
    console.log(`📊 ODOO STATUS SYNC - Status comparison:`);
    console.log(`   • Current: ${currentStatus}`);
    console.log(`   • Odoo: ${odooStatus}`);
    console.log(`   • Changed: ${statusChanged}`);
    return new Response(JSON.stringify({
      success: true,
      odoo_status: odooStatus,
      current_status: currentStatus,
      status_changed: statusChanged,
      odoo_product_id: odooStatusResult.odoo_product_id,
      odoo_state: odooStatusResult.odoo_state,
      odoo_active: odooStatusResult.odoo_active,
      message: statusChanged ? `Status changed from ${currentStatus} to ${odooStatus}` : `Status unchanged: ${currentStatus}`
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      },
      status: 200
    });
  } catch (error) {
    console.error(`❌ ODOO STATUS SYNC - Webhook error: ${error.message}`);
    return new Response(JSON.stringify({
      success: false,
      error: error.message,
      message: 'Internal server error'
    }), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      },
      status: 500
    });
  }
});
