import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface SellerApprovalPayload {
  seller_id: string;
  is_approved: boolean;
  rejection_reason?: string;
  updated_at: string;
}

interface SellerData {
  id: string;
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
  created_at: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🔄 Seller Approval Webhook - Processing request');

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
    const payload: SellerApprovalPayload = await req.json();
    console.log('📋 Payload received:', JSON.stringify(payload, null, 2));

    // Validate required fields
    if (!payload.seller_id || typeof payload.is_approved !== 'boolean') {
      console.log('❌ Missing required fields in payload');
      return new Response(
        JSON.stringify({ 
          error: 'Missing required fields: seller_id, is_approved' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    console.log('🔍 Fetching seller data for ID:', payload.seller_id);

    // Fetch seller data from database
    const { data: sellerData, error: fetchError } = await supabase
      .from('sellers')
      .select('*')
      .eq('id', payload.seller_id)
      .single();

    if (fetchError || !sellerData) {
      console.log('❌ Seller not found:', fetchError?.message || 'No data');
      return new Response(
        JSON.stringify({ 
          error: 'Seller not found',
          seller_id: payload.seller_id 
        }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    console.log('✅ Seller data fetched:', sellerData.seller_name);

    // Determine approval status
    const approvalStatus = payload.is_approved ? 'approved' : 'rejected';
    
    // Update seller approval status in database
    const updateData = {
      approval_status: approvalStatus,
      approved_at: payload.is_approved ? new Date().toISOString() : null,
      rejected_at: !payload.is_approved ? new Date().toISOString() : null,
      rejection_reason: payload.rejection_reason || null,
      updated_at: new Date().toISOString()
    };

    console.log('💾 Updating seller approval status:', updateData);

    const { error: updateError } = await supabase
      .from('sellers')
      .update(updateData)
      .eq('id', payload.seller_id);

    if (updateError) {
      console.log('❌ Database update failed:', updateError.message);
      throw updateError;
    }

    console.log('✅ Seller approval status updated successfully');

    // Create Odoo seller record if approved
    let odooSellerId = null;
    if (payload.is_approved) {
      try {
        console.log('🔄 Creating seller in Odoo...');
        odooSellerId = await createSellerInOdoo(sellerData);
        console.log('✅ Seller created in Odoo with ID:', odooSellerId);
      } catch (odooError) {
        console.log('⚠️ Odoo seller creation failed:', odooError.message);
        // Don't fail the webhook if Odoo creation fails
        // The seller is still approved in Supabase
      }
    }

    // Prepare response
    const response = {
      success: true,
      message: `Seller ${approvalStatus} successfully`,
      seller_id: payload.seller_id,
      seller_name: sellerData.seller_name,
      approval_status: approvalStatus,
      odoo_seller_id: odooSellerId,
      updated_at: updateData.updated_at
    };

    console.log('✅ Webhook completed successfully:', response);

    return new Response(
      JSON.stringify(response),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ Webhook error:', error);
    
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
 * Following the same pattern as product creation
 */
async function createSellerInOdoo(sellerData: SellerData): Promise<number> {
  console.log('🔄 Creating seller in Odoo:', sellerData.seller_name);

  // Prepare Odoo seller data
  const odooSellerData = {
    name: sellerData.seller_name,
    phone: sellerData.contact_phone,
    email: null, // Email not required for sellers
    is_company: true, // Sellers are businesses
    supplier_rank: 1, // Mark as supplier
    customer_rank: 0, // Not a customer
    category_id: [[6, false, [1]]], // Default category
    street: sellerData.business_address || '',
    city: sellerData.business_city || '',
    zip: sellerData.business_pincode || '',
    country_id: 104, // India country ID in Odoo
    vat: sellerData.gstin || '', // GST number
    // Custom fields for seller-specific data
    x_seller_type: sellerData.seller_type,
    x_fssai_license: sellerData.fssai_license || '',
    x_bank_account: sellerData.bank_account_number || '',
    x_ifsc_code: sellerData.ifsc_code || '',
    x_account_holder: sellerData.account_holder_name || '',
    x_aadhaar: sellerData.aadhaar_number || '',
    x_goat_seller_id: sellerData.id, // Link back to Supabase
  };

  console.log('📋 Odoo seller data prepared:', JSON.stringify(odooSellerData, null, 2));

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
  console.log('📋 Odoo API response:', JSON.stringify(odooResult, null, 2));

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
