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

    const url = new URL(req.url);
    const dryRun = url.searchParams.get('dryRun') === 'true';

    // Parse request body
    const payload: SellerSyncPayload & { payload_version?: 'v1' | 'v2' } = await req.json();
    console.log('📋 Payload received:', JSON.stringify(payload, null, 2));

    const forceV2 = (Deno.env.get('FORCE_V2_WEBHOOKS') === 'true');
    const payloadVersion = payload.payload_version || 'v1';
    if (forceV2 && payloadVersion !== 'v2') {
      return new Response(JSON.stringify({ error: 'Only v2 payloads are accepted on this endpoint' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

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
    const odooSellerId = await createSellerInOdoo(payload, dryRun);
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
async function createSellerInOdoo(payload: SellerSyncPayload, dryRun?: boolean): Promise<number> {
  console.log('🔄 Creating seller in Odoo (direct auth):', payload.seller_name);
  console.log('🧪 DryRun:', !!dryRun);

  // Odoo connection
  const odooUrl = Deno.env.get('ODOO_URL') || 'https://goatgoat.xyz/';
  const odooDb = Deno.env.get('ODOO_DB') || 'staging';
  const odooUsername = Deno.env.get('ODOO_USERNAME') || 'admin';
  const odooPassword = Deno.env.get('ODOO_PASSWORD') || 'admin';

  // 1) Authenticate
  const authResponse = await fetch(`${odooUrl}/web/session/authenticate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0', method: 'call', params: { db: odooDb, login: odooUsername, password: odooPassword }, id: Math.random()
    })
  });
  const authJson = await authResponse.json();
  if (!authJson?.result?.uid) throw new Error(`Odoo auth failed: ${JSON.stringify(authJson)}`);
  const sessionCookie = authResponse.headers.get('set-cookie') || '';

  // 2) Duplicate check by ref
  const ref = payload.seller_id;
  const searchBody = { jsonrpc: '2.0', method: 'call', params: { model: 'res.partner', method: 'search', args: [[[ 'ref', '=', ref ]]], kwargs: {} }, id: Math.random() };
  const searchRes = await fetch(`${odooUrl}/web/dataset/call_kw`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie }, body: JSON.stringify(searchBody) });
  const searchJson = await searchRes.json();
  if (Array.isArray(searchJson?.result) && searchJson.result.length > 0) {
    const existingId = searchJson.result[0];
    console.log('♻️ Seller already exists in Odoo (by ref), id:', existingId);
    return existingId;
  }

  // 3) New payload shape
  const companyType: 'person' | 'company' = (payload as any).company_type === 'person' || (payload as any).company_type === 'company' ? (payload as any).company_type : 'company';
  const odooSellerData = {
    name: payload.seller_name,
    company_type: companyType,
    seller_type: payload.seller_type,
    ref,
    supplier_rank: 1,
    customer_rank: 0,
    mobile: payload.contact_phone || '',
    email: (payload as any).email || null,
    state: 'pending',
    street: payload.business_address || '',
    city: payload.business_city || '',
    zip: payload.business_pincode || '',
    active: true,
  };

  // 4) Create
  const createBody = { jsonrpc: '2.0', method: 'call', params: { model: 'res.partner', method: 'create', args: [odooSellerData], kwargs: {} }, id: Math.random() };

  if (dryRun) {
    console.log('🧪 DRY RUN - res.partner.create payload:', JSON.stringify(createBody));
    return 0;
  }

  const createRes = await fetch(`${odooUrl}/web/dataset/call_kw`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie }, body: JSON.stringify(createBody) });
  const createJson = await createRes.json();
  if (createJson?.error) throw new Error(`Odoo seller creation failed: ${JSON.stringify(createJson.error)}`);
  const sellerId = createJson?.result;
  if (!sellerId) throw new Error('No seller ID returned from Odoo');
  console.log('✅ Seller created in Odoo with ID:', sellerId);
  return sellerId;
}
