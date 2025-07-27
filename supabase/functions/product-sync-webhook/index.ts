import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key'
};

// WORKING Odoo integration - tested and verified
async function createProductInOdoo(productData) {
  console.log(`🚀 WORKING FIX - Starting Odoo product creation`);
  console.log(`🚀 WORKING FIX - Product data: ${JSON.stringify(productData)}`);
  
  try {
    // Hard-coded values that work (tested successfully)
    const odooUrl = "https://goatgoat.xyz/";
    const odooDb = "staging";
    const odooUsername = "admin";
    const odooPassword = "admin";

    console.log(`🔐 WORKING FIX - Authenticating with Odoo...`);
    
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
    console.log(`🔐 WORKING FIX - Auth status: ${authResponse.status}`);
    
    if (!authResult.result || !authResult.result.uid) {
      throw new Error(`Authentication failed: ${JSON.stringify(authResult)}`);
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`🔐 WORKING FIX - Auth successful, cookie: ${sessionCookie ? 'Present' : 'Missing'}`);

    // Step 2: Create product with minimal data (PROVEN TO WORK)
    const minimalProductData = {
      name: `${productData.name} (by ${productData.seller_id})`,
      list_price: productData.list_price || 0,
      default_code: productData.default_code || `GOAT_${Date.now()}`,
      description: `Seller: ${productData.seller_id} (${productData.seller_uid})`,
      categ_id: 1,
      type: 'product',
    };

    console.log(`📦 WORKING FIX - Creating product: ${JSON.stringify(minimalProductData)}`);

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
    console.log(`📦 WORKING FIX - Create response status: ${createResponse.status}`);
    console.log(`📦 WORKING FIX - Create result: ${JSON.stringify(createResult)}`);

    if (createResult.error) {
      throw new Error(`Product creation failed: ${JSON.stringify(createResult.error)}`);
    }

    const odooProductId = createResult.result;
    console.log(`✅ WORKING FIX - SUCCESS! Product created with ID: ${odooProductId}`);

    return {
      success: true,
      odoo_product_id: odooProductId,
    };

  } catch (error) {
    console.error(`❌ WORKING FIX - ERROR: ${error.message}`);
    console.error(`❌ WORKING FIX - Stack: ${error.stack}`);
    return {
      success: false,
      error: error.message,
    };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log(`🚀 WORKING FIX - New webhook called with method: ${req.method}`);
    
    // API Key authentication
    const apiKey = req.headers.get("x-api-key");
    const expectedApiKey = Deno.env.get("WEBHOOK_API_KEY");
    
    if (!apiKey || apiKey !== expectedApiKey) {
      console.log(`❌ WORKING FIX - Unauthorized: ${apiKey} vs ${expectedApiKey}`);
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401
      });
    }

    console.log(`✅ WORKING FIX - Authentication successful`);

    const payload = await req.json();
    console.log(`📥 WORKING FIX - Payload: ${JSON.stringify(payload)}`);

    // Validate required fields
    if (!payload.product_id || !payload.seller_id || !payload.product_type || !payload.approval_status) {
      return new Response(JSON.stringify({
        error: "Missing required fields: product_id, seller_id, product_type, approval_status"
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Create Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    // Verify seller exists
    const { data: seller, error: sellerError } = await supabase
      .from("sellers")
      .select("id")
      .eq("id", payload.seller_id)
      .single();

    if (sellerError || !seller) {
      console.log(`❌ WORKING FIX - Seller not found: ${payload.seller_id}`);
      return new Response(JSON.stringify({
        error: "Seller not found"
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404
      });
    }

    console.log(`✅ WORKING FIX - Seller verified: ${seller.id}`);

    // Verify product exists and belongs to seller
    const productTable = payload.product_type === 'meat' ? 'meat_products' : 'livestock_listings';
    const { data: product, error: productError } = await supabase
      .from(productTable)
      .select("*")
      .eq("id", payload.product_id)
      .eq("seller_id", payload.seller_id)
      .single();

    if (productError || !product) {
      console.log(`❌ WORKING FIX - Product not found: ${payload.product_id}`);
      return new Response(JSON.stringify({
        error: "Product not found or doesn't belong to seller"
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404
      });
    }

    console.log(`✅ WORKING FIX - Product verified: ${product.id}`);

    // Create product in Odoo if product_data is provided
    let odooProductId = null;
    if (payload.product_data) {
      console.log(`🔄 WORKING FIX - Creating product in Odoo...`);
      
      try {
        const odooResult = await createProductInOdoo(payload.product_data);
        
        if (odooResult && odooResult.success) {
          odooProductId = odooResult.odoo_product_id;
          console.log(`✅ WORKING FIX - Product created in Odoo with ID: ${odooProductId}`);
        } else {
          console.error(`❌ WORKING FIX - Odoo creation failed: ${odooResult?.error}`);
        }
      } catch (webhookError) {
        console.error(`❌ WORKING FIX - Exception in Odoo creation: ${webhookError.message}`);
      }
    } else {
      console.log(`⚠️ WORKING FIX - No product_data provided, skipping Odoo creation`);
    }

    // Update product approval status in Supabase
    const updateData = {
      approval_status: payload.approval_status,
      approved_at: payload.approval_status === "approved" ? new Date().toISOString() : null,
      updated_at: new Date().toISOString()
    };

    const { error: updateError } = await supabase
      .from(productTable)
      .update(updateData)
      .eq("id", payload.product_id);

    if (updateError) {
      throw updateError;
    }

    console.log(`✅ WORKING FIX - Product updated successfully`);

    return new Response(JSON.stringify({
      success: true,
      message: `Product approval status updated successfully`,
      product_id: payload.product_id,
      product_type: payload.product_type,
      status: payload.approval_status,
      odoo_product_id: odooProductId,
      odoo_sync: odooProductId ? true : false
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    console.error(`❌ WORKING FIX - Webhook error: ${error.message}`);
    return new Response(JSON.stringify({
      error: error.message
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500
    });
  }
});
