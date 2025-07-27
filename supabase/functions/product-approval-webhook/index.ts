import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key'
};

// Odoo API helper function
async function createProductInOdoo(productData) {
  try {
    const odooUrl = Deno.env.get("ODOO_URL") || "https://goatgoat.xyz/";
    const odooDb = Deno.env.get("ODOO_DB") || "staging";
    const odooUsername = Deno.env.get("ODOO_USERNAME") || "admin";
    const odooPassword = Deno.env.get("ODOO_PASSWORD") || "admin";

    console.log(`🔗 ODOO DEBUG - Creating product in Odoo: ${productData.name}`);
    console.log(`🔍 ODOO DEBUG - Product data: ${JSON.stringify(productData)}`);
    console.log(`🔍 ODOO DEBUG - Odoo URL: ${odooUrl}`);
    console.log(`🔍 ODOO DEBUG - Odoo DB: ${odooDb}`);
    console.log(`🔍 ODOO DEBUG - Odoo Username: ${odooUsername}`);

    // First, authenticate with Odoo
    console.log(`🔐 ODOO DEBUG - Starting authentication...`);
    const authResponse = await fetch(`${odooUrl}/web/session/authenticate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: {
          db: odooDb,
          login: odooUsername,
          password: odooPassword,
        },
        id: Math.random(),
      }),
    });

    const authResult = await authResponse.json();
    console.log(`🔐 Odoo auth result: ${JSON.stringify(authResult)}`);

    if (!authResult.result || !authResult.result.uid) {
      throw new Error('Odoo authentication failed');
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`🔐 ODOO DEBUG - Session cookie: ${sessionCookie ? 'Present' : 'Missing'}`);

    // Skip seller creation - not needed for minimal approach
    console.log(`📦 ODOO DEBUG - Skipping seller creation, using minimal product approach`);

    // Step 3: Create product in Odoo with minimal data (FIXED APPROACH)
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

    const createResponse = await fetch(`${odooUrl}/web/dataset/call_kw`, {
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
    console.log(`📦 Odoo product creation result: ${JSON.stringify(createResult)}`);

    if (createResult.error) {
      throw new Error(`Odoo product creation failed: ${createResult.error.message}`);
    }

    return {
      success: true,
      odoo_product_id: createResult.result,
    };
  } catch (error) {
    console.error(`❌ ODOO ERROR - Product creation failed: ${error.message}`);
    console.error(`❌ ODOO ERROR - Full error: ${JSON.stringify(error)}`);
    console.error(`❌ ODOO ERROR - Stack trace: ${error.stack}`);
    return {
      success: false,
      error: error.message,
      details: error.stack,
    };
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // API Key authentication
    const apiKey = req.headers.get("x-api-key");
    const expectedApiKey = Deno.env.get("WEBHOOK_API_KEY");
    
    if (!apiKey || apiKey !== expectedApiKey) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401
      });
    }

    const payload = await req.json();
    console.log(`📥 Webhook payload received: ${JSON.stringify(payload)}`);

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
      return new Response(JSON.stringify({ error: "Seller not found" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404
      });
    }

    let productTable = payload.product_type === 'meat' ? 'meat_products' : 'livestock_listings';
    let approvalTable = payload.product_type === 'meat' ? 'product_approvals' : 'livestock_approvals';

    // Find product
    const { data: product, error: productError } = await supabase
      .from(productTable)
      .select("*")
      .eq("id", payload.product_id)
      .eq("seller_id", payload.seller_id)
      .single();

    if (productError || !product) {
      return new Response(JSON.stringify({
        error: "Product not found or doesn't belong to seller"
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404
      });
    }

    // 🚀 NEW: Create product in Odoo if product_data is provided
    let odooProductId = null;
    console.log(`🔄 WEBHOOK DEBUG - Checking if product_data exists: ${!!payload.product_data}`);

    if (payload.product_data) {
      console.log(`🔄 WEBHOOK DEBUG - Creating product in Odoo with data: ${JSON.stringify(payload.product_data)}`);
      console.log(`🔄 WEBHOOK DEBUG - Starting createProductInOdoo function call`);

      try {
        const odooResult = await createProductInOdoo(payload.product_data);

        console.log(`🔄 WEBHOOK DEBUG - createProductInOdoo result: ${JSON.stringify(odooResult)}`);

        if (odooResult && odooResult.success) {
          odooProductId = odooResult.odoo_product_id;
          console.log(`✅ WEBHOOK SUCCESS - Product created in Odoo with ID: ${odooProductId}`);
        } else {
          console.error(`❌ WEBHOOK ERROR - Failed to create product in Odoo: ${odooResult?.error || 'Unknown error'}`);
          console.error(`❌ WEBHOOK ERROR - Full error details: ${JSON.stringify(odooResult)}`);
          // Continue with local update even if Odoo fails
        }
      } catch (webhookError) {
        console.error(`❌ WEBHOOK EXCEPTION - Error calling createProductInOdoo: ${webhookError.message}`);
        console.error(`❌ WEBHOOK EXCEPTION - Stack trace: ${webhookError.stack}`);
        // Continue with local update even if Odoo fails
      }
    } else {
      console.log(`⚠️ WEBHOOK WARNING - No product_data provided, skipping Odoo creation`);
    }

    // Update product approval status in Supabase
    const updateData = {
      approval_status: payload.approval_status,
      approved_at: payload.approval_status === "approved" ? new Date().toISOString() : null,
      updated_at: new Date().toISOString()
    };

    // Note: Not storing odoo_product_id in database as column doesn't exist
    // The Odoo product ID is returned in the response for the Flutter app

    const { error: updateError } = await supabase
      .from(productTable)
      .update(updateData)
      .eq("id", payload.product_id);

    if (updateError) {
      throw updateError;
    }

    // Update approval table
    const approvalData = {
      approval_status: payload.approval_status,
      approved_at: payload.approval_status === "approved" ? new Date().toISOString() : null,
      rejected_at: payload.approval_status === "rejected" ? new Date().toISOString() : null,
      rejection_reason: payload.rejection_reason || null,
      updated_at: new Date().toISOString()
    };

    if (payload.product_type === 'meat') {
      await supabase.from(approvalTable).upsert({
        ...approvalData,
        meat_product_id: payload.product_id
      });
    } else {
      await supabase.from(approvalTable).upsert({
        ...approvalData,
        livestock_listing_id: payload.product_id
      });
    }

    console.log(`${payload.product_type} product ${payload.product_id} approval status updated to: ${payload.approval_status}`);
    
    if (odooProductId) {
      console.log(`✅ Product synced to Odoo with ID: ${odooProductId}`);
    }

    return new Response(JSON.stringify({
      success: true,
      message: `Product approval status updated successfully`,
      product_id: payload.product_id,
      product_type: payload.product_type,
      status: payload.approval_status,
      odoo_product_id: odooProductId, // 🚀 NEW: Return Odoo product ID
      odoo_sync: odooProductId ? true : false // 🚀 NEW: Indicate sync status
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    console.error("Error in product approval webhook:", error);
    return new Response(JSON.stringify({ error: "Internal server error" }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500
    });
  }
});