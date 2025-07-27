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

    console.log(`🔗 Creating product in Odoo: ${productData.name}`);

    // First, authenticate with Odoo
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

    // Create product in Odoo
    const createResponse = await fetch(`${odooUrl}/web/dataset/call_kw`, {
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
          args: [{
            name: productData.name,
            list_price: productData.list_price,
            default_code: productData.default_code,
            description: productData.description,
            categ_id: 1, // Default category
            type: 'product',
            // Add custom fields for meat products
            seller_name: productData.seller_id, // This is the seller name from Flutter
            seller_uid: productData.seller_uid,
            product_type: productData.product_type,
            state: 'pending', // For approval workflow
          }],
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
    console.error(`❌ Odoo product creation failed: ${error.message}`);
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
    if (payload.product_data) {
      console.log(`🔄 Creating product in Odoo with data: ${JSON.stringify(payload.product_data)}`);
      const odooResult = await createProductInOdoo(payload.product_data);
      
      if (odooResult.success) {
        odooProductId = odooResult.odoo_product_id;
        console.log(`✅ Product created in Odoo with ID: ${odooProductId}`);
      } else {
        console.error(`❌ Failed to create product in Odoo: ${odooResult.error}`);
        // Continue with local update even if Odoo fails
      }
    }

    // Update product approval status in Supabase
    const updateData = {
      approval_status: payload.approval_status,
      approved_at: payload.approval_status === "approved" ? new Date().toISOString() : null,
      updated_at: new Date().toISOString()
    };

    // Add Odoo product ID if created successfully
    if (odooProductId) {
      updateData.odoo_product_id = odooProductId;
    }

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