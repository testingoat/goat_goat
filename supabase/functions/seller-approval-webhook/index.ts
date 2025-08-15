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
  id: string; // Supabase UUID (used as ref in Odoo)
  seller_name: string;
  contact_phone: string;
  seller_type: string; // meat | livestock | both
  company_type?: 'person' | 'company'; // from onboarding; default 'company'
  email?: string;
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
    const url = new URL(req.url);
    const dryRun = url.searchParams.get('dryRun') === 'true';

    const payload: SellerApprovalPayload & { payload_version?: 'v1' | 'v2' } = await req.json();
    console.log('📋 Payload received:', JSON.stringify(payload, null, 2));
    const payloadVersion = payload.payload_version || 'v1';

    // v2 gating
    const forceV2 = (Deno.env.get('FORCE_V2_WEBHOOKS') === 'true');
    if (forceV2 && payloadVersion !== 'v2') {
      return new Response(JSON.stringify({ error: 'Only v2 payloads are accepted on this endpoint' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

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
        // Map to v2 input for createSellerInOdoo
        const sellerV2: SellerData = {
          ...sellerData,
          company_type: (sellerData.company_type === 'person' || sellerData.company_type === 'company') ? sellerData.company_type : 'company',
        };
        odooSellerId = await createSellerInOdoo(sellerV2, { dryRun });
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
async function createSellerInOdoo(sellerData: SellerData, options: { dryRun?: boolean } = {}): Promise<number> {
  console.log('🔄 Creating seller in Odoo (direct JSON-RPC auth):', sellerData.seller_name);
  console.log('🧪 Options:', options);

  // Odoo connection (env with safe defaults)
  const odooUrl = Deno.env.get('ODOO_URL') || 'https://goatgoat.xyz/';
  const odooDb = Deno.env.get('ODOO_DB') || 'staging';
  const odooUsername = Deno.env.get('ODOO_USERNAME') || 'admin';
  const odooPassword = Deno.env.get('ODOO_PASSWORD') || 'admin';

  // 1) Authenticate
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
  const authJson = await authResponse.json();
  if (!authJson?.result?.uid) {
    throw new Error(`Odoo auth failed: ${JSON.stringify(authJson)}`);
  }
  const sessionCookie = authResponse.headers.get('set-cookie') || '';

  // 2) Duplicate check by ref (Supabase UUID)
  const ref = sellerData.id;
  const searchBody = {
    jsonrpc: '2.0',
    method: 'call',
    params: {
      model: 'res.partner',
      method: 'search',
      args: [[[ 'ref', '=', ref ]]],
      kwargs: {},
    },
    id: Math.random(),
  };
  const searchRes = await fetch(`${odooUrl}/web/dataset/call_kw`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
    body: JSON.stringify(searchBody),
  });
  const searchJson = await searchRes.json();
  if (Array.isArray(searchJson?.result) && searchJson.result.length > 0) {
    const existingId = searchJson.result[0];
    console.log('♻️ Seller already exists in Odoo (by ref), id:', existingId);
    return existingId;
  }

  // 3) Map to new payload shape
  const companyType: 'person' | 'company' =
    sellerData.company_type === 'person' || sellerData.company_type === 'company'
      ? sellerData.company_type
      : 'company';

  const odooSellerData: Record<string, unknown> = {
    name: sellerData.seller_name,
    company_type: companyType, // person | company
    seller_type: sellerData.seller_type,
    ref, // Supabase UUID
    supplier_rank: 1, // seller
    customer_rank: 0,
    mobile: sellerData.contact_phone || '',
    email: sellerData.email || null,
    state: 'pending',
    street: sellerData.business_address || '',
    city: sellerData.business_city || '',
    zip: sellerData.business_pincode || '',
    active: true,
  };

  console.log('📋 Odoo seller data (v2):', JSON.stringify(odooSellerData, null, 2));

  // 4) Create seller (with dry run)
  const createBody = {
    jsonrpc: '2.0',
    method: 'call',
    params: {
      model: 'res.partner',
      method: 'create',
      args: [odooSellerData],
      kwargs: {},
    },
    id: Math.random(),
  };

  if (options.dryRun) {
    console.log('🧪 DRY RUN - res.partner.create payload:', JSON.stringify(createBody));
    return 0; // mock ID
  }

  const createRes = await fetch(`${odooUrl}/web/dataset/call_kw`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
    body: JSON.stringify(createBody),
  });
  const createJson = await createRes.json();
  if (createJson?.error) {
    throw new Error(`Odoo seller creation failed: ${JSON.stringify(createJson.error)}`);
  }
  const sellerId = createJson?.result;
  if (!sellerId) throw new Error('No seller ID returned from Odoo');

  console.log('✅ Seller created in Odoo with ID:', sellerId);
  return sellerId;
}
