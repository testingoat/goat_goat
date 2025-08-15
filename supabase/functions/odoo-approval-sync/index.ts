import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-odoo-webhook-token',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE'
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log(`🚀 ODOO APPROVAL SYNC - New request from Odoo: ${req.method}`);
    
    // Special authentication for Odoo webhook calls
    // Try both header and URL parameter authentication
    const url = new URL(req.url);
    const odooTokenHeader = req.headers.get("x-odoo-webhook-token");
    const odooTokenParam = url.searchParams.get("token");
    const odooToken = odooTokenHeader || odooTokenParam;
    const expectedToken = Deno.env.get("ODOO_WEBHOOK_TOKEN") || "odoo-goatgoat-sync-2024";

    if (!odooToken || odooToken !== expectedToken) {
      console.log(`❌ ODOO SYNC - Unauthorized: ${odooToken} vs ${expectedToken}`);
      console.log(`❌ ODOO SYNC - Header token: ${odooTokenHeader}, Param token: ${odooTokenParam}`);
      return new Response(JSON.stringify({
        error: "Unauthorized - Invalid Odoo token",
        expected_token_hint: expectedToken.substring(0, 10) + "...",
        received_token: odooToken ? odooToken.substring(0, 10) + "..." : "none"
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401
      });
    }

    console.log(`✅ ODOO SYNC - Authentication successful`);

    const payload = await req.json();
    console.log(`📥 ODOO SYNC - Payload: ${JSON.stringify(payload)}`);

    // Validate required fields for Odoo approval sync
    if (!payload.odoo_product_id || !payload.approval_status) {
      return new Response(JSON.stringify({
        error: "Missing required fields: odoo_product_id, approval_status"
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Create Supabase client
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      {
        auth: {
          persistSession: false
        }
      }
    );

    // Find the product in Supabase by odoo_product_id
    const { data: product, error: productError } = await supabase
      .from('meat_products')
      .select('*')
      .eq('odoo_product_id', payload.odoo_product_id)
      .single();

    if (productError || !product) {
      console.error(`❌ ODOO SYNC - Product not found with odoo_product_id: ${payload.odoo_product_id}`);
      return new Response(JSON.stringify({
        error: `Product not found with odoo_product_id: ${payload.odoo_product_id}`
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 404
      });
    }

    console.log(`✅ ODOO SYNC - Found product: ${product.name} (${product.id})`);

    // Update product approval status in Supabase
    const updateData: Record<string, unknown> = {
      approval_status: payload.approval_status,
      approved_at: payload.approval_status === "approved" ? new Date().toISOString() : null,
      rejected_at: payload.approval_status === "rejected" ? new Date().toISOString() : null,
      updated_at: new Date().toISOString()
    };

    // Optional: auto-activate product after approval
    const envAuto = ((Deno.env.get('ENABLE_AUTO_ACTIVATE_ON_APPROVAL') ?? 'true') === 'true');
    if (payload.approval_status === 'approved' && envAuto) {
      updateData.is_active = true;
    }

    const { error: updateError } = await supabase
      .from('meat_products')
      .update(updateData)
      .eq('id', product.id);

    if (updateError) {
      console.error(`❌ ODOO SYNC - Update error: ${updateError.message}`);
      throw updateError;
    }

    console.log(`✅ ODOO SYNC - Product ${product.name} status updated to: ${payload.approval_status}`);

    return new Response(JSON.stringify({
      success: true,
      message: `Product approval status synced successfully`,
      product_id: product.id,
      product_name: product.name,
      odoo_product_id: payload.odoo_product_id,
      status: payload.approval_status,
      auto_activated: payload.approval_status === 'approved' && envAuto
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    console.error("❌ ODOO SYNC - Error:", error);
    return new Response(JSON.stringify({ 
      error: "Internal server error",
      details: error.message 
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500
    });
  }
});
