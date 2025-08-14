import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface SellerSyncPayload {
  seller_id: string;
  seller_name: string;
  contact_phone: string;
  seller_type: string;
  business_city?: string;
  business_address?: string;
  business_pincode?: string;
  gstin?: string;
  fssai_license?: string;
  bank_account_number?: string;
  ifsc_code?: string;
  account_holder_name?: string;
  aadhaar_number?: string;
  action: string;
  created_at: string;
  updated_at: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🔄 Seller Sync Webhook - Processing request');

    // Validate request method
    if (req.method !== 'POST') {
      console.log('❌ Invalid request method:', req.method);
      return new Response(
        JSON.stringify({ error: 'Method not allowed' }),
        { 
          status: 405, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Validate API key
    const apiKey = req.headers.get('x-api-key');
    const expectedApiKey = Deno.env.get('WEBHOOK_API_KEY');
    
    if (!apiKey || apiKey !== expectedApiKey) {
      console.log('❌ Invalid or missing API key');
      return new Response(
        JSON.stringify({ error: 'Unauthorized - Invalid API key' }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Parse request body
    const payload: SellerSyncPayload = await req.json();
    console.log('📋 Payload received:', JSON.stringify(payload, null, 2));

    // Validate required fields
    if (!payload.seller_id || !payload.seller_name || !payload.contact_phone || !payload.seller_type) {
      console.log('❌ Missing required fields in payload');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: seller_id, seller_name, contact_phone, seller_type' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Create seller in Odoo
    console.log('🔄 Creating seller in Odoo...');
    const odooSellerId = await createSellerInOdoo(payload);
    console.log('✅ Seller created in Odoo with ID:', odooSellerId);

    // Initialize Supabase client for any database updates if needed
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Update seller with Odoo sync status (optional)
    try {
      await supabase
        .from('sellers')
        .update({ 
          updated_at: new Date().toISOString(),
          // Note: We don't store odoo_seller_id in database as column doesn't exist
          // The Odoo seller ID is returned in the response for the Flutter app
        })
        .eq('id', payload.seller_id);
    } catch (updateError) {
      console.log('⚠️ Database update failed (non-critical):', updateError.message);
      // Don't fail the webhook if database update fails
    }

    // Prepare response
    const response = {
      success: true,
      message: 'Seller created in Odoo successfully',
      seller_id: payload.seller_id,
      seller_name: payload.seller_name,
      odoo_seller_id: odooSellerId,
      sync_status: 'completed',
      created_at: new Date().toISOString()
    };

    console.log('✅ Seller sync completed successfully:', response);

    return new Response(
      JSON.stringify(response),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ Seller sync error:', error);
    
    return new Response(
      JSON.stringify({ 
        error: 'Internal server error',
        message: error.message 
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );
  }
});

/**
 * Create seller in Odoo ERP system
 * Creates a res.partner record with supplier_rank=1 for seller approval
 */
async function createSellerInOdoo(payload: SellerSyncPayload): Promise<number> {
  console.log('🔄 Creating seller in Odoo:', payload.seller_name);

  // Prepare Odoo seller data (res.partner model)
  const odooSellerData = {
    name: payload.seller_name,
    phone: payload.contact_phone,
    email: null, // Email not required for sellers
    is_company: true, // Sellers are businesses
    supplier_rank: 1, // Mark as supplier (this puts them in supplier approval queue)
    customer_rank: 0, // Not a customer
    category_id: [[6, false, [1]]], // Default category
    street: payload.business_address || '',
    city: payload.business_city || '',
    zip: payload.business_pincode || '',
    country_id: 104, // India country ID in Odoo
    state_id: false, // Will be set based on city if needed
    vat: payload.gstin || '', // GST number
    // Custom fields for seller-specific data (these need to be created in Odoo)
    x_seller_type: payload.seller_type,
    x_fssai_license: payload.fssai_license || '',
    x_bank_account: payload.bank_account_number || '',
    x_ifsc_code: payload.ifsc_code || '',
    x_account_holder: payload.account_holder_name || '',
    x_aadhaar: payload.aadhaar_number || '',
    x_goat_seller_id: payload.seller_id, // Link back to Supabase
    x_approval_status: 'pending', // Custom field for approval tracking
    active: true, // Active record
    comment: `Seller registered via GoatGoat app on ${payload.created_at}`,
  };

  console.log('📋 Odoo seller data prepared');

  // Call Odoo API proxy to create seller
  const odooResponse = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/odoo-api-proxy`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': Deno.env.get('WEBHOOK_API_KEY')!,
    },
    body: JSON.stringify({
      odoo_endpoint: '/web/dataset/call_kw/res.partner/create',
      data: {
        model: 'res.partner',
        method: 'create',
        args: [odooSellerData],
        kwargs: {}
      }
    })
  });

  if (!odooResponse.ok) {
    const errorText = await odooResponse.text();
    console.log('❌ Odoo API proxy error:', errorText);
    throw new Error(`Odoo API proxy failed: ${odooResponse.status} - ${errorText}`);
  }

  const odooResult = await odooResponse.json();
  console.log('📋 Odoo API response received');

  if (odooResult.error) {
    console.log('❌ Odoo seller creation error:', odooResult.error);
    throw new Error(`Odoo seller creation failed: ${odooResult.error}`);
  }

  // Extract seller ID from response
  const sellerId = odooResult.result || odooResult.data?.result;
  if (!sellerId) {
    console.log('❌ No seller ID returned from Odoo');
    throw new Error('No seller ID returned from Odoo');
  }

  console.log('✅ Seller created in Odoo with ID:', sellerId);
  return sellerId;
}
