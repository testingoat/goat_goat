import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { DebugLogger } from '../_shared/debug-logger.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key'
};

// WORKING Odoo integration - tested and verified
async function createProductInOdoo(productData, options = { dryRun: false, dupCheck: undefined }) {
  console.log(`🚀 WORKING FIX - Starting Odoo product creation`);
  console.log(`🚀 WORKING FIX - Product data: ${JSON.stringify(productData)}`);
  console.log(`🚀 WORKING FIX - Options: ${JSON.stringify(options)}`);

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

    // Optional duplicate prevention by default_code (behind flag)
    const dupFlag = options.dupCheck ?? (Deno.env.get('ENABLE_PRODUCT_DUP_CHECK') === 'true');
    if (dupFlag && productData.default_code) {
      const searchBody = {
        jsonrpc: '2.0', method: 'call',
        params: { model: 'product.template', method: 'search', args: [[[ 'default_code', '=', productData.default_code ]]], kwargs: {} },
        id: Math.random()
      };
      const searchRes = await fetch(`${odooUrl}/web/dataset/call_kw`, {
        method: 'POST', headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie }, body: JSON.stringify(searchBody)
      });
      const searchJson = await searchRes.json();
      if (Array.isArray(searchJson?.result) && searchJson.result.length > 0) {
        const existingId = searchJson.result[0];
        console.log('♻️ Product already exists in Odoo (by default_code), id:', existingId);
        return { success: true, odoo_product_id: existingId, duplicate: true };
      }
    }

    // Step 2: Create product using v2 payload shape
    const v2ProductData = {
      name: productData.name,
      type: 'product',
      list_price: productData.list_price || 0,
      meat_type: productData.meat_type || productData.product_type, // fallback
      seller_id: productData.seller_id, // seller name as per spec
      seller_uid: productData.seller_uid, // Supabase UUID
      description: productData.description || `Seller: ${productData.seller_uid}`,
      state: 'pending',
      default_code: productData.default_code || `GOAT_${Date.now()}`,
    };

    console.log(`📦 WORKING FIX - Creating product (v2): ${JSON.stringify(v2ProductData)}`);

    const rpcBody = {
      jsonrpc: '2.0',
      method: 'call',
      params: { model: 'product.template', method: 'create', args: [v2ProductData], kwargs: {} },
      id: Math.random(),
    };

    if (options.dryRun) {
      console.log('🧪 DRY RUN - product.template.create payload:', JSON.stringify(rpcBody));
      return { success: true, odoo_product_id: 0, dryRun: true };
    }

    const createResponse = await fetch(`${odooUrl}/web/dataset/call_kw`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie }, body: JSON.stringify(rpcBody)
    });

    const createResult = await createResponse.json();
    console.log(`📦 WORKING FIX - Create response status: ${createResponse.status}`);
    console.log(`📦 WORKING FIX - Create result: ${JSON.stringify(createResult)}`);

    if (createResult.error) {
      throw new Error(`Product creation failed: ${JSON.stringify(createResult.error)}`);
    }

    const odooProductId = createResult.result;

    // Optional: attach extra images if provided (v2 extension)
    if (Array.isArray(productData.extra_images) && productData.extra_images.length > 0) {
      try {
        for (const img of productData.extra_images) {
          const attachBody = {
            jsonrpc: '2.0',
            method: 'call',
            params: {
              model: 'ir.attachment',
              method: 'create',
              args: [{
                name: `Extra Image`,
                type: 'binary',
                datas: img, // expected base64 string
                res_model: 'product.template',
                res_id: odooProductId,
                mimetype: 'image/jpeg',
              }],
              kwargs: {},
            },
            id: Math.random(),
          };
          await fetch(`${odooUrl}/web/dataset/call_kw`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
            body: JSON.stringify(attachBody),
          });
        }
      } catch (attachErr) {
        console.warn('⚠️ Attachment upload failed (non-blocking):', attachErr);
      }
    }

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
  return await DebugLogger.wrapExecution('product-sync-webhook', req, async () => {
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

    const url = new URL(req.url);
    const dryRun = url.searchParams.get('dryRun') === 'true';

    const payload = await req.json();
    console.log(`📥 WORKING FIX - Payload: ${JSON.stringify(payload)}`);

    // v2 payload compatibility
    const payloadVersion = payload.payload_version || 'v1';
    const forceV2 = (Deno.env.get('FORCE_V2_WEBHOOKS') === 'true');
    if (forceV2 && payloadVersion !== 'v2') {
      return new Response(JSON.stringify({ error: 'Only v2 payloads are accepted on this endpoint' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

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

    // Create product in Odoo if product_data is provided (v1/v2 compatible)
    let odooProductId = null;
    if (payload.product_data) {
      console.log(`🔄 WORKING FIX - Creating product in Odoo...`);
      try {
        const dataForOdoo = payloadVersion === 'v2' ? payload.product_data : {
          // v1 → v2 mapping
          name: payload.product_data.name,
          list_price: payload.product_data.list_price,
          meat_type: payload.product_data.meat_type || payload.product_data.product_type,
          seller_id: payload.product_data.seller_id, // seller name
          seller_uid: payload.product_data.seller_uid,
          description: payload.product_data.description,
          default_code: payload.product_data.default_code,
        };

        const odooResult = await createProductInOdoo(dataForOdoo, { dryRun, dupCheck: undefined });
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
    const updateData: Record<string, unknown> = {
      approval_status: payload.approval_status,
      approved_at: payload.approval_status === "approved" ? new Date().toISOString() : null,
      updated_at: new Date().toISOString()
    };

    // 🚀 CRITICAL FIX: Update odoo_product_id if product was created in Odoo
    if (odooProductId) {
      updateData.odoo_product_id = odooProductId;
      console.log(`✅ CRITICAL FIX - Adding odoo_product_id to update: ${odooProductId}`);
    }

    // Optional: auto-activate product after approval (flag or request override)
    const envAuto = ((Deno.env.get('ENABLE_AUTO_ACTIVATE_ON_APPROVAL') ?? 'true') === 'true');
    if (payload.approval_status === 'approved' && (envAuto || payload.auto_activate === true)) {
      updateData.is_active = true;
    }

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
});
