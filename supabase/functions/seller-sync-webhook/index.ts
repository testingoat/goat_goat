import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { DebugLogger } from '../_shared/debug-logger.ts';

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
  return await DebugLogger.wrapExecution('seller-sync-webhook', req, async () => {
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
    console.log(`[Debug] payload_version=${(payload as any).payload_version ?? 'undefined'}`);

    const forceV2 = (Deno.env.get('FORCE_V2_WEBHOOKS') === 'true');
    const allowV1 = (Deno.env.get('ALLOW_V1_SELLER_SYNC_WHILE_MIGRATING') === 'true');
    const payloadVersion = (payload as any).payload_version || 'v1';

    console.log(`[VersionCheck] forceV2=${forceV2} allowV1=${allowV1} payload_version=${(payload as any).payload_version ?? 'undefined'}`);

    if (forceV2 && payloadVersion !== 'v2' && !allowV1) {
      console.log(`[Reject] 400 due to version check. Received payload_version='${payloadVersion}'.`);
      return new Response(JSON.stringify({
        error: 'Only v2 payloads are accepted on this endpoint',
        details: { forceV2, allowV1, payloadVersion }
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    if (allowV1 && payloadVersion !== 'v2') {
      console.log('[Compat] ALLOW_V1_SELLER_SYNC_WHILE_MIGRATING enabled. Proceeding with V1 payload.');
    }

    // Validate required fields
    if (!payload.seller_id || !payload.seller_name || !payload.contact_phone || !payload.seller_type) {
      const missing: string[] = [];
      if (!payload.seller_id) missing.push('seller_id');
      if (!payload.seller_name) missing.push('seller_name');
      if (!payload.contact_phone) missing.push('contact_phone');
      if (!payload.seller_type) missing.push('seller_type');
      console.log(`[Reject] 400 due to missing fields: ${missing.join(', ')}`);
      return new Response(
        JSON.stringify({
          error: 'Missing required fields: seller_id, seller_name, contact_phone, seller_type',
          details: { missing }
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
    console.log('[Database] Initializing Supabase client...');
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase environment variables');
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Update seller with Odoo sync status and store odoo_seller_id
    try {
      console.log('[Database] Updating seller with odoo_seller_id...');
      const updateData = {
        updated_at: new Date().toISOString(),
        odoo_seller_id: odooSellerId, // 🚀 CRITICAL FIX: Store Odoo seller ID for approval workflow
      };

      console.log(`[Database] Update data: ${JSON.stringify(updateData)}`);
      console.log(`[Database] Updating seller: ${payload.seller_id}`);

      const { data, error } = await supabase
        .from('sellers')
        .update(updateData)
        .eq('id', payload.seller_id);

      if (error) {
        console.error('[Database] Update error:', error);
        throw error;
      }

      console.log(`✅ CRITICAL FIX - Successfully stored odoo_seller_id in database`);
      console.log(`[Database] Update result: ${JSON.stringify(data)}`);
    } catch (updateError) {
      console.error('❌ Database update failed:', updateError);
      // Don't fail the webhook if database update fails, but log it properly
      console.log('⚠️ Database update failed (non-critical):', updateError.message);
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
});

/**
 * Create seller in Odoo ERP system
 * Creates a res.partner record with supplier_rank=1 for seller approval
 */
async function createSellerInOdoo(payload: SellerSyncPayload, dryRun?: boolean): Promise<number> {
  console.log('🔄 Creating seller in Odoo (direct auth):', payload.seller_name);
  console.log('🧪 DryRun:', !!dryRun);

  try {
    // Odoo connection - using exact same values as working product-sync-webhook
    const odooUrl = 'https://goatgoat.xyz/'; // Hard-coded like working product-sync
    const odooDb = 'staging'; // Hard-coded like working product-sync
    const odooUsername = 'admin'; // Hard-coded like working product-sync
    const odooPassword = 'admin'; // Hard-coded like working product-sync

    console.log(`[Odoo] Using hard-coded values (like working product-sync): ${odooUrl} with db=${odooDb}, user=${odooUsername}`);

    // 1) Authenticate
    console.log('[Odoo] Step 1: Authenticating...');
    const authResponse = await fetch(`${odooUrl}/web/session/authenticate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0', method: 'call', params: { db: odooDb, login: odooUsername, password: odooPassword }, id: Math.random()
      })
    });

    console.log(`[Odoo] Auth response status: ${authResponse.status}`);
    const authJson = await authResponse.json();
    console.log(`[Odoo] Auth response: ${JSON.stringify(authJson)}`);

    if (!authJson?.result?.uid) {
      throw new Error(`Odoo auth failed: ${JSON.stringify(authJson)}`);
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`[Odoo] Auth successful, uid=${authJson.result.uid}, cookie=${sessionCookie ? 'present' : 'missing'}`);
    console.log(`[Odoo] Raw session cookie: ${sessionCookie}`);
    console.log(`[Odoo] Session ID from result: ${authJson.result.session_id || 'not found'}`);

    // 2) Duplicate check by ref
    console.log('[Odoo] Step 2: Checking for existing seller...');
    const ref = payload.seller_id;
    const searchBody = { jsonrpc: '2.0', method: 'call', params: { model: 'res.partner', method: 'search', args: [[[ 'ref', '=', ref ]]], kwargs: {} }, id: Math.random() };

    const searchRes = await fetch(`${odooUrl}/web/dataset/call_kw`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
      body: JSON.stringify(searchBody)
    });

    console.log(`[Odoo] Search response status: ${searchRes.status}`);
    const searchJson = await searchRes.json();
    console.log(`[Odoo] Search result: ${JSON.stringify(searchJson)}`);

    if (Array.isArray(searchJson?.result) && searchJson.result.length > 0) {
      const existingId = searchJson.result[0];
      console.log('♻️ Seller already exists in Odoo (by ref), id:', existingId);
      return existingId;
    }

    // 3) Prepare seller data
    console.log('[Odoo] Step 3: Preparing seller data...');

    // 🚀 COMPREHENSIVE FIX: Proper company_type validation
    const companyType: 'person' | 'company' = (payload as any).company_type === 'person' || (payload as any).company_type === 'company' ? (payload as any).company_type : 'company';

    // 🚀 COMPREHENSIVE FIX: Proper seller_type validation (custom module IS installed)
    const sellerType = payload.seller_type?.toLowerCase();
    const validSellerTypes = ['meat', 'livestock', 'both'];
    const finalSellerType = validSellerTypes.includes(sellerType) ? sellerType : 'meat';

    console.log(`[Odoo] Validated company_type: ${companyType}, seller_type: ${finalSellerType}`);

    // 🚀 COMPREHENSIVE FIX: Complete payload with custom module fields
    const odooSellerData = {
      name: payload.seller_name,
      company_type: companyType, // "person" or "company"
      seller_type: finalSellerType, // 🚀 RESTORED: Custom module field exists
      ref,
      supplier_rank: 1,
      customer_rank: 0,
      mobile: payload.contact_phone || '',
      email: (payload as any).email || null,
      state: 'Pending for Approval', // 🚀 CRITICAL FIX: Correct state value
      street: payload.business_address || '',
      city: payload.business_city || '',
      zip: payload.business_pincode || '',
      active: true,
      comment: `Created via GoatGoat App | Awaiting Admin Approval`,
    };

    console.log(`[Odoo] Seller data prepared: ${JSON.stringify(odooSellerData, null, 2)}`);

    // 4) Create seller
    console.log('[Odoo] Step 4: Creating seller...');
    const createBody = { jsonrpc: '2.0', method: 'call', params: { model: 'res.partner', method: 'create', args: [odooSellerData], kwargs: {} }, id: Math.random() };

    if (dryRun) {
      console.log('🧪 DRY RUN - res.partner.create payload:', JSON.stringify(createBody));
      return 0;
    }

    const createRes = await fetch(`${odooUrl}/web/dataset/call_kw`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
      body: JSON.stringify(createBody)
    });

    console.log(`[Odoo] Create response status: ${createRes.status}`);
    const createJson = await createRes.json();
    console.log(`[Odoo] Create result: ${JSON.stringify(createJson)}`);

    if (createJson?.error) {
      throw new Error(`Odoo seller creation failed: ${JSON.stringify(createJson.error)}`);
    }

    const sellerId = createJson?.result;
    if (!sellerId) {
      throw new Error('No seller ID returned from Odoo');
    }

    console.log('✅ Seller created in Odoo with ID:', sellerId);
    return sellerId;

  } catch (error) {
    console.error('[Odoo] Error in createSellerInOdoo:', error);
    throw error;
  }
}
