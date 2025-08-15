import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    const { odoo_endpoint, data, session_id, config } = await req.json();
    console.log('Proxy request:', {
      odoo_endpoint,
      data,
      session_id,
      config: config ? 'Config provided' : 'No config'
    });
    // Use config from request if provided, otherwise fall back to environment variables
    const ODOO_URL = config?.serverUrl || Deno.env.get('ODOO_URL');
    const ODOO_DB = config?.database || Deno.env.get('ODOO_DB');
    const ODOO_USERNAME = config?.username || Deno.env.get('ODOO_USERNAME');
    const ODOO_PASSWORD = config?.password || Deno.env.get('ODOO_PASSWORD');
    console.log('Using config:', {
      url: ODOO_URL,
      database: ODOO_DB,
      username: ODOO_USERNAME,
      password: ODOO_PASSWORD ? '***' : 'Not set',
      source: config ? 'client' : 'environment'
    });
    if (!ODOO_URL) {
      throw new Error('ODOO_URL not configured. Please provide it in the request config or set in Supabase secrets.');
    }
    if (!ODOO_DB || !ODOO_USERNAME || !ODOO_PASSWORD) {
      throw new Error('Odoo credentials (database, username, password) not configured. Please provide them in the request config or set in Supabase secrets.');
    }
    // Handle different authentication endpoints
    if (odoo_endpoint === '/web/session/authenticate') {
      console.log('Handling web session authentication');
      if (data && data.params) {
        data.params.db = ODOO_DB;
        data.params.login = ODOO_USERNAME;
        data.params.password = ODOO_PASSWORD;
      }
    } else if (odoo_endpoint === '/xmlrpc/2/common') {
      console.log('Handling XML-RPC common authentication');
      if (data && data.params && data.params.args) {
        data.params.args[0] = ODOO_DB;
        data.params.args[1] = ODOO_USERNAME;
        data.params.args[2] = ODOO_PASSWORD;
      }
    }
    // Validate required endpoint parameter
    if (!odoo_endpoint) {
      throw new Error('odoo_endpoint is required');
    }
    // Construct the full Odoo URL
    let odooUrl = ODOO_URL;
    if (!odooUrl.endsWith('/')) {
      odooUrl += '/';
    }
    odooUrl += odoo_endpoint.startsWith('/') ? odoo_endpoint.substring(1) : odoo_endpoint;
    console.log('Making request to:', odooUrl);
    const headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Lovable-Odoo-Integration/1.0'
    };
    // Add session cookie if available
    if (session_id && session_id !== 'authenticated') {
      headers['Cookie'] = `session_id=${session_id}`;
    }
    const requestOptions = {
      method: 'POST',
      headers,
      body: JSON.stringify(data)
    };
    console.log('Request options:', requestOptions);
    const odooResponse = await fetch(odooUrl, requestOptions);
    console.log('Odoo response status:', odooResponse.status);
    let odooResponseData;
    try {
      odooResponseData = await odooResponse.json();
    } catch (parseError) {
      console.error('Failed to parse Odoo response as JSON:', parseError);
      const textResponse = await odooResponse.text();
      console.log('Raw response:', textResponse);
      throw new Error(`Invalid JSON response from Odoo: ${textResponse.substring(0, 200)}`);
    }
    console.log('Odoo response data:', odooResponseData);
    // Check for Odoo errors
    if (odooResponseData.error) {
      console.error(`Odoo API Error for endpoint ${odoo_endpoint}:`, odooResponseData.error);
    // Don't throw here, let the client handle the error
    }
    // Extract session cookies from response headers if present
    const setCookieHeader = odooResponse.headers.get('set-cookie');
    if (setCookieHeader) {
      console.log('Set-Cookie header:', setCookieHeader);
      const sessionMatch = setCookieHeader.match(/session_id=([^;]+)/);
      if (sessionMatch) {
        // Only add session_id to result if result is an object, not a primitive
        if (odooResponseData.result && typeof odooResponseData.result === 'object' && !Array.isArray(odooResponseData.result)) {
          odooResponseData.result.session_id = sessionMatch[1];
        } else {
          // For primitive results (like customer creation returning just an ID), 
          // wrap the result in an object with session info
          if (odoo_endpoint === '/web/session/authenticate') {
            // Only for authentication endpoints, preserve the session_id in result
            if (typeof odooResponseData.result === 'object') {
              odooResponseData.result.session_id = sessionMatch[1];
            }
          }
        // For other endpoints like customer creation, don't modify the result
        // The session_id will be available for subsequent requests via the stored sessionId
        }
      }
    }
    return new Response(JSON.stringify(odooResponseData), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: odooResponse.status
    });
  } catch (error) {
    console.error('Proxy Error:', error);
    return new Response(JSON.stringify({
      error: {
        message: error.message,
        type: 'proxy_error',
        details: error.toString()
      }
    }), {
      status: 500,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  }
});
