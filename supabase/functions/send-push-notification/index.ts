import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Firebase HTTP v1 API configuration
const FIREBASE_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token'

/**
 * Base64 URL encode
 */
function base64UrlEncode(str: string): string {
  return btoa(str)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

/**
 * Create JWT manually using Web Crypto API
 */
async function createJWT(header: any, payload: any, privateKey: string): Promise<string> {
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const data = `${encodedHeader}.${encodedPayload}`;

  // Convert PEM to binary
  const pemHeader = "-----BEGIN PRIVATE KEY-----";
  const pemFooter = "-----END PRIVATE KEY-----";
  const pemContents = privateKey.replace(pemHeader, "").replace(pemFooter, "").replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  // Import the key
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  // Sign the data
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(data)
  );

  // Encode signature
  const encodedSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));

  return `${data}.${encodedSignature}`;
}

/**
 * Generate OAuth2 access token using Firebase service account credentials
 * Implements comprehensive error handling and validation
 */
async function getAccessToken(serviceAccount: any): Promise<string> {
  try {
    // Validate service account structure
    if (!serviceAccount.private_key || !serviceAccount.client_email) {
      throw new Error('Invalid service account: missing private_key or client_email')
    }

    // Ensure private key is properly formatted
    let privateKey = serviceAccount.private_key
    if (!privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
      throw new Error('Invalid private key format: must be PEM format with headers')
    }

    // Create JWT assertion for OAuth2
    const now = Math.floor(Date.now() / 1000)
    const header = {
      alg: "RS256",
      typ: "JWT"
    }
    const payload = {
      iss: serviceAccount.client_email,
      scope: FIREBASE_SCOPE,
      aud: GOOGLE_TOKEN_URL,
      iat: now,
      exp: now + 3600, // 1 hour expiration
    }

    console.log('🔐 Creating JWT for service account:', serviceAccount.client_email)

    // Create and sign JWT with error handling
    let jwt
    try {
      console.log('🔐 Private key length:', privateKey.length)
      console.log('🔐 Private key starts with:', privateKey.substring(0, 50))

      jwt = await createJWT(header, payload, privateKey)

      console.log('✅ JWT created successfully')
    } catch (jwtError) {
      console.error('❌ JWT creation failed:', jwtError)
      console.error('❌ Error details:', JSON.stringify(jwtError, null, 2))
      throw new Error(`JWT creation failed: ${jwtError.message}. Check private key format.`)
    }

    // Exchange JWT for access token
    const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text()
      console.error('❌ Token exchange failed:', {
        status: tokenResponse.status,
        statusText: tokenResponse.statusText,
        error: errorText
      })
      throw new Error(`Failed to get access token: ${tokenResponse.status} ${errorText}`)
    }

    const tokenData = await tokenResponse.json()

    if (!tokenData.access_token) {
      throw new Error('No access token received from Google OAuth2 service')
    }

    console.log('✅ OAuth2 access token generated successfully')
    return tokenData.access_token
  } catch (error) {
    console.error('❌ OAuth2 token generation failed:', error)
    throw new Error(`OAuth2 authentication failed: ${error.message}`)
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get environment variables
    const FIREBASE_SERVICE_ACCOUNT_JSON = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    // Validate Firebase service account credentials
    if (!FIREBASE_SERVICE_ACCOUNT_JSON) {
      console.log('⚠️ FIREBASE_SERVICE_ACCOUNT not configured - returning error response')
      return new Response(
        JSON.stringify({
          success: false,
          message: 'FIREBASE_SERVICE_ACCOUNT environment variable is not configured. Please set it in Supabase Dashboard → Project Settings → Edge Functions → Environment Variables',
          error: 'Missing Firebase service account credentials',
          instructions: 'Add FIREBASE_SERVICE_ACCOUNT with your complete Firebase service account JSON'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Parse and validate service account JSON
    let serviceAccount
    try {
      console.log('🔍 Parsing service account JSON...')
      serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT_JSON)

      console.log('✅ Service account parsed successfully')
      console.log('🔍 Project ID:', serviceAccount.project_id)
      console.log('🔍 Client email:', serviceAccount.client_email)
      console.log('🔍 Private key length:', serviceAccount.private_key?.length || 'undefined')

      // Validate required fields
      const requiredFields = ['type', 'project_id', 'private_key', 'client_email']
      for (const field of requiredFields) {
        if (!serviceAccount[field]) {
          throw new Error(`Missing required field: ${field}`)
        }
      }

      if (serviceAccount.type !== 'service_account') {
        throw new Error('Invalid service account type. Expected "service_account"')
      }

      console.log('✅ Service account validation passed')
    } catch (parseError) {
      console.error('❌ Invalid Firebase service account JSON:', parseError)
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Invalid Firebase service account JSON format',
          error: parseError.message,
          instructions: 'Please provide a valid Firebase service account JSON with all required fields'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Supabase environment variables are required')
    }

    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Parse and validate request body
    let requestBody
    try {
      requestBody = await req.json()
    } catch (parseError) {
      console.error('❌ Invalid JSON in request body:', parseError)
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid JSON in request body',
          message: 'Request body must be valid JSON'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    const {
      title,
      body,
      target_user_id,
      target_user_type,
      topic,
      data,
      deep_link_url,
      admin_id
    } = requestBody

    // Validate required fields
    if (!title && !body) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields',
          message: 'Either title or body must be provided'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    // Validate target parameters
    if (target_user_id && !target_user_type) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Invalid target parameters',
          message: 'target_user_type is required when target_user_id is provided'
        }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      )
    }

    console.log('🔔 FCM Request:', {
      title,
      target_user_id,
      target_user_type,
      topic,
      admin_id,
      project_id: serviceAccount.project_id
    })

    // Generate OAuth2 access token
    console.log('🔑 Generating OAuth2 access token...')
    const accessToken = await getAccessToken(serviceAccount)
    console.log('✅ OAuth2 access token generated successfully')

    // Build FCM HTTP v1 API payload
    const fcmMessage: any = {
      message: {
        notification: {
          title: title || 'Goat Goat',
          body: body || 'You have a new notification',
        },
        data: {
          ...(data || {}),
          deep_link_url: deep_link_url || '',
          timestamp: new Date().toISOString(),
        },
      }
    }

    // Determine target (specific user, topic, or default) - HTTP v1 API format
    if (target_user_id && target_user_type) {
      // Get user's FCM token from database
      let tableName = ''
      switch (target_user_type) {
        case 'customer':
          tableName = 'customers'
          break
        case 'seller':
          tableName = 'sellers'
          break
        case 'admin':
          tableName = 'admin_users'
          break
        default:
          throw new Error(`Invalid target_user_type: ${target_user_type}`)
      }

      const { data: user, error } = await supabase
        .from(tableName)
        .select('fcm_token')
        .eq('id', target_user_id)
        .single()

      if (error) {
        console.error('Error fetching user FCM token:', error)
        throw new Error(`Failed to fetch user FCM token: ${error.message}`)
      }

      if (user?.fcm_token) {
        fcmMessage.message.token = user.fcm_token
        console.log('📤 Sending FCM message to user token:', user.fcm_token.substring(0, 20) + '...')
      } else {
        throw new Error(`No FCM token found for user ${target_user_id}`)
      }
    } else if (topic) {
      // Send to topic - HTTP v1 API format
      fcmMessage.message.topic = topic
      console.log('📤 Sending FCM message to topic:', topic)
    } else {
      // Default to all users topic
      fcmMessage.message.topic = 'all_users'
      console.log('📤 Sending FCM message to default topic: all_users')
    }

    // Send to FCM using HTTP v1 API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`
    console.log('🚀 Sending to FCM HTTP v1 API:', fcmUrl)

    const fcmResponse = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(fcmMessage),
    })

    const fcmResult = await fcmResponse.json()

    if (!fcmResponse.ok) {
      console.error('❌ FCM HTTP v1 API Error:', {
        status: fcmResponse.status,
        statusText: fcmResponse.statusText,
        result: fcmResult
      })
      throw new Error(`FCM HTTP v1 API request failed: ${fcmResult.error?.message || fcmResult.error || 'Unknown error'}`)
    }

    console.log('✅ FCM HTTP v1 API Success:', fcmResult)

    // Log notification in database for audit trail
    if (admin_id) {
      const { error: logError } = await supabase
        .from('admin_action_logs')
        .insert({
          admin_id,
          action: 'send_push_notification',
          resource_type: 'notification',
          resource_id: null,
          metadata: {
            title,
            target_user_id,
            target_user_type,
            topic,
            fcm_message_name: fcmResult.name, // HTTP v1 API returns 'name' instead of 'message_id'
            api_version: 'http_v1',
            project_id: serviceAccount.project_id,
            success: 1,
            failure: 0,
          },
        })

      if (logError) {
        console.error('Error logging notification:', logError)
        // Don't fail the request for logging errors
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Push notification sent successfully via Firebase HTTP v1 API',
        fcm_result: fcmResult,
        message_name: fcmResult.name, // HTTP v1 API uses 'name' field
        api_version: 'http_v1',
        project_id: serviceAccount.project_id,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ FCM HTTP v1 API Function Error:', error)

    // Provide detailed error information for debugging
    const errorResponse = {
      success: false,
      error: error.message,
      message: 'Failed to send push notification via Firebase HTTP v1 API',
      api_version: 'http_v1',
      timestamp: new Date().toISOString(),
    }

    // Add additional context for specific error types
    if (error.message.includes('OAuth2')) {
      errorResponse.error_type = 'authentication_error'
      errorResponse.troubleshooting = 'Check Firebase service account credentials and ensure they have FCM permissions'
    } else if (error.message.includes('FCM HTTP v1 API')) {
      errorResponse.error_type = 'fcm_api_error'
      errorResponse.troubleshooting = 'Check Firebase project configuration and FCM token validity'
    } else if (error.message.includes('token')) {
      errorResponse.error_type = 'token_error'
      errorResponse.troubleshooting = 'Check if the target user has a valid FCM token registered'
    }

    return new Response(
      JSON.stringify(errorResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
