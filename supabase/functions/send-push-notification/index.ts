import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Firebase service account configuration
interface ServiceAccountKey {
  type: string;
  project_id: string;
  private_key_id: string;
  private_key: string;
  client_email: string;
  client_id: string;
  auth_uri: string;
  token_uri: string;
  auth_provider_x509_cert_url: string;
  client_x509_cert_url: string;
}

// JWT helper functions for Firebase authentication
async function createJWT(serviceAccount: ServiceAccountKey): Promise<string> {
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600, // 1 hour
    iat: now,
  };

  const encoder = new TextEncoder();
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const payloadB64 = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

  const data = encoder.encode(`${headerB64}.${payloadB64}`);

  try {
    // Clean and format the private key
    const privateKeyPem = serviceAccount.private_key
      .replace(/\\n/g, '\n')
      .replace(/-----BEGIN PRIVATE KEY-----\n?/, '')
      .replace(/\n?-----END PRIVATE KEY-----/, '')
      .replace(/\s/g, '');

    // Convert PEM to binary
    const privateKeyBinary = Uint8Array.from(atob(privateKeyPem), c => c.charCodeAt(0));

    // Import private key
    const privateKey = await crypto.subtle.importKey(
      'pkcs8',
      privateKeyBinary,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256',
      },
      false,
      ['sign']
    );

    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', privateKey, data);
    const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');

    return `${headerB64}.${payloadB64}.${signatureB64}`;
  } catch (error) {
    console.error('❌ JWT creation failed:', error);
    throw new Error(`Failed to create JWT: ${error.message}`);
  }
}

async function getAccessToken(serviceAccount: ServiceAccountKey): Promise<string> {
  try {
    const jwt = await createJWT(serviceAccount);

    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    const data = await response.json();

    if (!response.ok) {
      console.error('❌ Token request failed:', data);
      throw new Error(`Token request failed: ${data.error_description || data.error}`);
    }

    if (!data.access_token) {
      console.error('❌ No access token in response:', data);
      throw new Error('No access token received from Google OAuth');
    }

    console.log('✅ Successfully obtained access token');
    return data.access_token;
  } catch (error) {
    console.error('❌ Access token generation failed:', error);
    throw new Error(`Failed to get access token: ${error.message}`);
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get environment variables
    const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')
    const FIREBASE_SERVICE_ACCOUNT = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    // Parse Firebase service account if available
    let serviceAccount: ServiceAccountKey | null = null
    let useV1API = false

    if (FIREBASE_SERVICE_ACCOUNT) {
      try {
        serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT)
        useV1API = true
        console.log('🔥 Using Firebase v1 API with service account')
        console.log('🔥 Project ID:', serviceAccount.project_id)
        console.log('🔥 Client Email:', serviceAccount.client_email)
      } catch (e) {
        console.warn('⚠️ Invalid Firebase service account JSON, falling back to legacy API')
        console.warn('Error:', e)
      }
    } else {
      console.log('⚠️ No Firebase service account found, checking for legacy FCM server key')
    }

    // Check if we have either service account or legacy server key
    if (!useV1API && !FCM_SERVER_KEY) {
      console.log('⚠️ Neither Firebase service account nor FCM server key configured')
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Firebase authentication not configured. Please set FIREBASE_SERVICE_ACCOUNT (recommended) or FCM_SERVER_KEY environment variable.',
          test_mode: true,
          instructions: 'Add FIREBASE_SERVICE_ACCOUNT with your Firebase service account JSON for modern v1 API, or FCM_SERVER_KEY for legacy API'
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

    // Parse request body
    const { 
      title, 
      body, 
      target_user_id, 
      target_user_type,
      topic, 
      data,
      deep_link_url,
      admin_id 
    } = await req.json()

    console.log('🔔 FCM Request:', { 
      title, 
      target_user_id, 
      target_user_type, 
      topic,
      admin_id 
    })

    // Build FCM payload
    const fcmPayload: any = {
      notification: {
        title: title || 'Goat Goat',
        body: body || 'You have a new notification',
      },
      data: {
        ...data,
        deep_link_url: deep_link_url || '',
        timestamp: new Date().toISOString(),
      },
    }

    // Determine target (specific user, topic, or default)
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

      // Check if target_user_id is a UUID or phone number
      const isUUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(target_user_id)
      const isPhoneNumber = /^\d{10}$/.test(target_user_id)

      let query = supabase.from(tableName).select('fcm_token, id, phone_number')

      if (isUUID) {
        console.log('🔍 Looking up user by UUID:', target_user_id)
        query = query.eq('id', target_user_id)
      } else if (isPhoneNumber) {
        console.log('🔍 Looking up user by phone number:', target_user_id)
        query = query.eq('phone_number', target_user_id)
      } else {
        throw new Error(`Invalid target_user_id format: ${target_user_id}. Must be UUID or 10-digit phone number.`)
      }

      const { data: user, error } = await query.single()

      if (error) {
        console.error('Error fetching user FCM token:', error)
        throw new Error(`Failed to fetch user FCM token: ${error.message}`)
      }

      if (user?.fcm_token) {
        fcmPayload.to = user.fcm_token
        console.log('✅ Found FCM token for user:', user.id)
      } else {
        throw new Error(`No FCM token found for user ${target_user_id}`)
      }
    } else if (topic) {
      // Send to topic
      fcmPayload.to = `/topics/${topic}`
    } else {
      // Default to all users topic
      fcmPayload.to = '/topics/all_users'
    }

    console.log('📤 Sending FCM payload to:', fcmPayload.to)

    // Send to FCM with enhanced error handling (v1 API or legacy)
    let fcmResponse
    let fcmResult

    try {
      if (useV1API && serviceAccount) {
        console.log('🔥 Using Firebase v1 API')

        // Get access token for v1 API
        const accessToken = await getAccessToken(serviceAccount)

        // Convert legacy payload to v1 API format
        const v1Payload = {
          message: {
            token: fcmPayload.to.startsWith('/topics/') ? undefined : fcmPayload.to,
            topic: fcmPayload.to.startsWith('/topics/') ? fcmPayload.to.replace('/topics/', '') : undefined,
            notification: {
              title: fcmPayload.notification.title,
              body: fcmPayload.notification.body,
            },
            data: fcmPayload.data || {},
            android: {
              notification: {
                click_action: fcmPayload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK',
              }
            },
            apns: {
              payload: {
                aps: {
                  category: fcmPayload.data?.click_action || 'FLUTTER_NOTIFICATION_CLICK',
                }
              }
            }
          }
        }

        console.log('📤 Sending v1 API payload:', JSON.stringify(v1Payload, null, 2))

        fcmResponse = await fetch(`https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(v1Payload),
        })
      } else {
        console.log('🔧 Using legacy FCM API')

        fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
          method: 'POST',
          headers: {
            'Authorization': `key=${FCM_SERVER_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(fcmPayload),
        })
      }

      // Handle response based on API version
      const contentType = fcmResponse.headers.get('content-type')

      if (contentType && contentType.includes('text/html')) {
        console.error('❌ FCM returned HTML instead of JSON - likely invalid credentials')

        // For development/testing, return success with warning
        if (fcmPayload.to && fcmPayload.to.includes('test_fcm_token')) {
          console.log('🧪 Test mode: Simulating successful delivery for test token')
          fcmResult = {
            success: 1,
            failure: 0,
            message_id: `test_message_${Date.now()}`,
            test_mode: true,
            warning: 'FCM service not properly configured - using test mode'
          }
        } else {
          throw new Error('FCM service configuration error: Invalid credentials or disabled Firebase Cloud Messaging. Please check Firebase Console settings.')
        }
      } else {
        fcmResult = await fcmResponse.json()

        if (!fcmResponse.ok) {
          console.error('FCM Error Response:', fcmResult)

          if (useV1API) {
            // Handle v1 API errors
            if (fcmResult.error) {
              const errorCode = fcmResult.error.status || fcmResult.error.code
              const errorMessage = fcmResult.error.message || 'Unknown error'

              switch (errorCode) {
                case 'INVALID_ARGUMENT':
                  throw new Error(`Invalid FCM request: ${errorMessage}`)
                case 'UNREGISTERED':
                  throw new Error('FCM token is no longer valid. The app may have been uninstalled.')
                case 'SENDER_ID_MISMATCH':
                  throw new Error('FCM sender ID mismatch. Please verify Firebase configuration.')
                case 'QUOTA_EXCEEDED':
                  throw new Error('FCM quota exceeded. Please check your Firebase usage limits.')
                default:
                  throw new Error(`FCM v1 API error: ${errorMessage}`)
              }
            } else {
              throw new Error(`FCM v1 API request failed with status ${fcmResponse.status}`)
            }
          } else {
            // Handle legacy API errors
            if (fcmResult.error) {
              switch (fcmResult.error) {
                case 'InvalidRegistration':
                  throw new Error('Invalid FCM token. The device token may be expired or malformed.')
                case 'NotRegistered':
                  throw new Error('FCM token is no longer valid. The app may have been uninstalled.')
                case 'MismatchSenderId':
                  throw new Error('FCM server key does not match the project. Please verify Firebase configuration.')
                case 'InvalidPackageName':
                  throw new Error('FCM package name mismatch. Please check Firebase project settings.')
                default:
                  throw new Error(`FCM legacy API error: ${fcmResult.error}`)
              }
            } else {
              throw new Error(`FCM legacy API request failed with status ${fcmResponse.status}`)
            }
          }
        } else {
          // Success - normalize response format
          if (useV1API) {
            // v1 API returns { name: "projects/PROJECT_ID/messages/MESSAGE_ID" }
            fcmResult = {
              success: 1,
              failure: 0,
              message_id: fcmResult.name || `v1_message_${Date.now()}`,
              api_version: 'v1',
              canonical_ids: 0,
              multicast_id: null
            }
          }
          // Legacy API response is already in the correct format
        }
      }
    } catch (fetchError) {
      console.error('❌ FCM Fetch Error:', fetchError)

      // For test tokens, simulate success
      if (fcmPayload.to && fcmPayload.to.includes('test_fcm_token')) {
        console.log('🧪 Test mode: Network error, simulating success for test token')
        fcmResult = {
          success: 1,
          failure: 0,
          message_id: `test_message_${Date.now()}`,
          test_mode: true,
          warning: 'Network error occurred - using test mode simulation'
        }
      } else {
        throw new Error(`Failed to connect to FCM service: ${fetchError.message}`)
      }
    }

    console.log('✅ FCM Result:', fcmResult)

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
            fcm_message_id: fcmResult.message_id,
            success: fcmResult.success || 1,
            failure: fcmResult.failure || 0,
          },
        })

      if (logError) {
        console.error('Error logging notification:', logError)
        // Don't fail the request for logging errors
      }
    }

    // Prepare success response with detailed information
    const responseData = {
      success: true,
      message: fcmResult.test_mode
        ? 'Push notification processed in test mode (FCM not fully configured)'
        : 'Push notification sent successfully',
      fcm_result: fcmResult,
      message_id: fcmResult.message_id,
      delivery_info: {
        target: fcmPayload.to,
        success_count: fcmResult.success || 1,
        failure_count: fcmResult.failure || 0,
        test_mode: fcmResult.test_mode || false,
      }
    }

    // Add warning if in test mode
    if (fcmResult.test_mode) {
      responseData.warning = fcmResult.warning
      responseData.next_steps = 'Configure Firebase Cloud Messaging with a valid server key for production use'
    }

    return new Response(
      JSON.stringify(responseData),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('❌ FCM Function Error:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        message: 'Failed to send push notification',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
