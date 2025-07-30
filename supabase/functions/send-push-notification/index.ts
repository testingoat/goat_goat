import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get environment variables
    const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

    if (!FCM_SERVER_KEY) {
      throw new Error('FCM_SERVER_KEY environment variable is required')
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
        fcmPayload.to = user.fcm_token
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

    // Send to FCM
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${FCM_SERVER_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(fcmPayload),
    })

    const fcmResult = await fcmResponse.json()

    if (!fcmResponse.ok) {
      console.error('FCM Error:', fcmResult)
      throw new Error(`FCM request failed: ${fcmResult.error || 'Unknown error'}`)
    }

    console.log('✅ FCM Success:', fcmResult)

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

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Push notification sent successfully',
        fcm_result: fcmResult,
        message_id: fcmResult.message_id,
      }),
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
