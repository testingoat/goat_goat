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
    const { phone_number, message, api_key } = await req.json()

    // Validate required parameters
    if (!phone_number || !message || !api_key) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Missing required parameters: phone_number, message, api_key' 
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    console.log(`📱 Sending SMS to ${phone_number}: ${message.substring(0, 50)}...`)

    // Send SMS via Fast2SMS API
    const fast2smsResponse = await fetch('https://www.fast2sms.com/dev/bulkV2', {
      method: 'POST',
      headers: {
        'authorization': api_key,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        route: 'v3',
        sender_id: 'TXTIND',
        message: message,
        language: 'english',
        flash: 0,
        numbers: phone_number.replace(/^\+91/, ''), // Remove +91 prefix if present
      }),
    })

    const fast2smsResult = await fast2smsResponse.json()
    console.log('📱 Fast2SMS Response:', fast2smsResult)

    // Initialize Supabase client for admin logging
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // Log admin action
    try {
      await supabase.from('admin_action_logs').insert({
        admin_id: 'system', // Could be passed from client if needed
        action_type: 'send_sms_notification',
        resource_type: 'notification',
        resource_id: `sms_${Date.now()}`,
        action_details: {
          phone_number: phone_number,
          message_length: message.length,
          fast2sms_response: fast2smsResult,
        },
        ip_address: req.headers.get('x-forwarded-for') || 'unknown',
        user_agent: req.headers.get('user-agent') || 'unknown',
      })
    } catch (logError) {
      console.error('❌ Failed to log admin action:', logError)
      // Don't fail the SMS sending if logging fails
    }

    // Check if SMS was sent successfully
    if (fast2smsResult.return === true || fast2smsResult.status_code === 200) {
      return new Response(
        JSON.stringify({
          success: true,
          message: 'SMS sent successfully',
          fast2sms_response: fast2smsResult,
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          message: `Fast2SMS error: ${fast2smsResult.message || 'Unknown error'}`,
          fast2sms_response: fast2smsResult,
        }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

  } catch (error) {
    console.error('❌ Error in fast2sms-custom function:', error)
    
    return new Response(
      JSON.stringify({
        success: false,
        message: `Server error: ${error.message}`,
      }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
