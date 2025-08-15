import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key'
};
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  // Authenticate using API key
  const apiKey = req.headers.get('x-api-key');
  if (apiKey !== Deno.env.get('WEBHOOK_API_KEY')) {
    return new Response(JSON.stringify({
      error: 'Unauthorized'
    }), {
      status: 401,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
  try {
    // Validate request body
    const body = await req.json();
    const { name, list_price, seller_id, seller_uid, default_code, product_type, config } = body;
    console.log('Received product creation request:', {
      name,
      list_price,
      seller_id,
      seller_uid,
      default_code,
      product_type,
      config: config ? 'Config provided' : 'No config'
    });
    if (!name || !seller_id || !product_type || !default_code) {
      console.error('Missing required fields in product creation');
      return new Response(JSON.stringify({
        error: 'Missing required fields'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Log incoming configuration
    console.log('Received config:', config ? 'Config provided' : 'No config provided');
    // Verify product_type is valid
    if (product_type !== 'meat' && product_type !== 'livestock') {
      return new Response(JSON.stringify({
        error: 'Invalid product_type. Must be "meat" or "livestock"'
      }), {
        status: 400,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Initialize Supabase client
    const supabase = createClient(Deno.env.get('SUPABASE_URL') || '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '', {
      auth: {
        persistSession: false
      }
    });
    // Call Odoo API via proxy
    const { data, error } = await supabase.functions.invoke('odoo-api-proxy', {
      body: {
        endpoint: 'create_product',
        method: 'POST',
        payload: {
          name,
          list_price: list_price || 0,
          seller_id,
          state: 'pending',
          seller_uid,
          default_code,
          product_type
        },
        config: config || {
          serverUrl: 'https://goatgoat.xyz/',
          database: 'staging',
          username: 'admin',
          password: 'admin'
        }
      }
    });
    console.log('Odoo API Proxy Response:', {
      data: data ? 'Data received' : 'No data',
      error: error ? error.message : 'No error'
    });
    if (error) {
      console.error('Error calling Odoo API:', error);
      return new Response(JSON.stringify({
        error: error.message
      }), {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    // Return success response
    return new Response(JSON.stringify({
      success: true,
      id: data?.id,
      data: data
    }), {
      status: 200,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Unexpected error:', error);
    return new Response(JSON.stringify({
      error: 'Internal server error'
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
