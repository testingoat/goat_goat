import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface SellerStatusSyncPayload {
  seller_id: string;
  seller_name?: string;
  current_status?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🔄 Seller Status Sync - Processing request');

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
    const payload: SellerStatusSyncPayload = await req.json();
    console.log('📋 Payload received:', JSON.stringify(payload, null, 2));

    // Validate required fields
    if (!payload.seller_id) {
      console.log('❌ Missing required field: seller_id');
      return new Response(
        JSON.stringify({ error: 'Missing required field: seller_id' }),
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

    // Get current seller data from Supabase
    console.log('📋 Fetching seller from Supabase...');
    const { data: seller, error: sellerError } = await supabase
      .from('sellers')
      .select('*')
      .eq('id', payload.seller_id)
      .single();

    if (sellerError || !seller) {
      console.log('❌ Seller not found in Supabase:', sellerError?.message);
      return new Response(
        JSON.stringify({ error: 'Seller not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    console.log(`📋 Found seller: ${seller.seller_name} (${seller.id})`);
    console.log(`📋 Current status in Supabase: ${seller.approval_status}`);
    console.log(`📋 Odoo seller ID: ${seller.odoo_seller_id}`);

    if (!seller.odoo_seller_id) {
      console.log('⚠️ Seller not synced to Odoo yet');
      return new Response(
        JSON.stringify({ 
          success: false,
          message: 'Seller not synced to Odoo yet',
          current_status: seller.approval_status,
          sync_needed: false
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      );
    }

    // Check seller status in Odoo
    console.log('🔄 Checking seller status in Odoo...');
    const odooStatus = await checkSellerStatusInOdoo(seller.id);
    console.log(`📋 Odoo status: ${odooStatus}`);

    // Compare statuses and update if different
    const statusChanged = odooStatus !== seller.approval_status;
    console.log(`📋 Status changed: ${statusChanged} (${seller.approval_status} → ${odooStatus})`);

    if (statusChanged) {
      console.log('🔄 Updating seller status in Supabase...');
      const updateData: any = {
        approval_status: odooStatus,
        updated_at: new Date().toISOString(),
      };

      // If approved, set approved_at timestamp
      if (odooStatus === 'approved') {
        updateData.approved_at = new Date().toISOString();
      }

      const { error: updateError } = await supabase
        .from('sellers')
        .update(updateData)
        .eq('id', payload.seller_id);

      if (updateError) {
        console.error('❌ Failed to update seller status:', updateError);
        return new Response(
          JSON.stringify({ 
            error: 'Failed to update seller status',
            details: updateError.message 
          }),
          { 
            status: 500, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
          }
        );
      }

      console.log('✅ Seller status updated successfully');
    }

    // Prepare response
    const response = {
      success: true,
      message: statusChanged ? 'Seller status updated' : 'Seller status unchanged',
      seller_id: payload.seller_id,
      seller_name: seller.seller_name,
      previous_status: seller.approval_status,
      current_status: odooStatus,
      status_changed: statusChanged,
      sync_timestamp: new Date().toISOString()
    };

    console.log('✅ Seller status sync completed:', response);

    return new Response(
      JSON.stringify(response),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    );

  } catch (error) {
    console.error('❌ Seller status sync error:', error);
    
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
 * Check seller approval status in Odoo using search_read
 * Maps Odoo states to our approval status values
 */
async function checkSellerStatusInOdoo(sellerRef: string): Promise<string> {
  console.log('🔄 Checking seller status in Odoo for ref:', sellerRef);

  try {
    // Odoo connection (same as seller-sync-webhook)
    const odooUrl = 'https://goatgoat.xyz/';
    const odooDb = 'staging';
    const odooUsername = 'admin';
    const odooPassword = 'admin';

    console.log(`[Odoo] Connecting to ${odooUrl} with db=${odooDb}, user=${odooUsername}`);

    // 1) Authenticate
    console.log('[Odoo] Step 1: Authenticating...');
    const authResponse = await fetch(`${odooUrl}/web/session/authenticate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0', 
        method: 'call', 
        params: { db: odooDb, login: odooUsername, password: odooPassword }, 
        id: Math.random()
      })
    });

    console.log(`[Odoo] Auth response status: ${authResponse.status}`);
    const authJson = await authResponse.json();

    if (!authJson?.result?.uid) {
      throw new Error(`Odoo auth failed: ${JSON.stringify(authJson)}`);
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`[Odoo] Auth successful, uid=${authJson.result.uid}`);

    // 2) Search seller by ref using provided API pattern
    console.log('[Odoo] Step 2: Searching seller by ref...');
    const searchPayload = {
      jsonrpc: '2.0',
      method: 'call',
      params: {
        model: 'res.partner',
        method: 'search_read',
        args: [],
        kwargs: {
          domain: [['ref', '=', sellerRef]],
          fields: ['name', 'state'],
          limit: 1
        }
      },
      id: Math.random()
    };

    const searchRes = await fetch(`${odooUrl}/web/dataset/call_kw`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
      body: JSON.stringify(searchPayload)
    });

    console.log(`[Odoo] Search response status: ${searchRes.status}`);
    const searchJson = await searchRes.json();
    console.log(`[Odoo] Search result: ${JSON.stringify(searchJson)}`);

    if (searchJson?.error) {
      throw new Error(`Odoo search failed: ${JSON.stringify(searchJson.error)}`);
    }

    const results = searchJson?.result;
    if (!Array.isArray(results) || results.length === 0) {
      console.log('⚠️ Seller not found in Odoo');
      return 'pending'; // Default to pending if not found
    }

    const sellerData = results[0];
    const odooState = sellerData.state;
    console.log(`[Odoo] Found seller: ${sellerData.name}, state: ${odooState}`);

    // Map Odoo states to our approval status values
    const statusMapping: { [key: string]: string } = {
      'Pending for Approval': 'pending',
      'approved': 'approved',
      'Approved': 'approved', // 🚀 CRITICAL FIX: Handle capital 'A' Approved
      'rejected': 'rejected',
      'Rejected': 'rejected', // Handle capital 'R' Rejected
      'draft': 'pending',
      'Draft': 'pending',     // Handle capital 'D' Draft
      'done': 'approved',
      'Done': 'approved'      // Handle capital 'D' Done
    };

    const mappedStatus = statusMapping[odooState] || 'pending';
    console.log(`[Odoo] Mapped status: ${odooState} → ${mappedStatus}`);

    return mappedStatus;

  } catch (error) {
    console.error('[Odoo] Error checking seller status:', error);
    throw error;
  }
}
