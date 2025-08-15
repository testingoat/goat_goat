import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.50.0";
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
const supabase = createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '');
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    const { action, phoneNumber, otp } = await req.json();
    if (action === 'send') {
      // Check rate limiting
      const { data: rateLimitData } = await supabase.from('otp_rate_limits').select('*').eq('phone_number', phoneNumber).gte('window_start', new Date(Date.now() - 60 * 60 * 1000).toISOString()) // 1 hour window
      .single();
      if (rateLimitData && rateLimitData.request_count >= 10) {
        return new Response(JSON.stringify({
          success: false,
          error: 'Too many OTP requests. Please try again later.'
        }), {
          status: 429,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
      // Generate OTP
      const otpCode = Math.floor(1000 + Math.random() * 9000).toString();
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes
      // Store OTP in database
      const { error: otpError } = await supabase.from('otp_verifications').insert({
        phone_number: phoneNumber,
        otp_code: otpCode,
        expires_at: expiresAt.toISOString()
      });
      if (otpError) {
        console.error('Error storing OTP:', otpError);
        return new Response(JSON.stringify({
          success: false,
          error: 'Failed to generate OTP'
        }), {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
      // Update rate limiting
      if (rateLimitData) {
        await supabase.from('otp_rate_limits').update({
          request_count: rateLimitData.request_count + 1
        }).eq('id', rateLimitData.id);
      } else {
        await supabase.from('otp_rate_limits').insert({
          phone_number: phoneNumber,
          request_count: 1
        });
      }
      // Send OTP via Fast2SMS
      const fast2smsApiKey = Deno.env.get('FAST2SMS_API_KEY');
      try {
        const response = await fetch('https://www.fast2sms.com/dev/bulkV2', {
          method: 'POST',
          headers: {
            'Authorization': fast2smsApiKey,
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            route: 'otp',
            variables_values: otpCode,
            flash: 0,
            numbers: phoneNumber
          })
        });
        const result = await response.json();
        if (result.return === true) {
          return new Response(JSON.stringify({
            success: true,
            message: `OTP sent to ${phoneNumber}`
          }), {
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          });
        } else {
          console.error('Fast2SMS error:', result);
          return new Response(JSON.stringify({
            success: false,
            error: 'Failed to send OTP'
          }), {
            status: 500,
            headers: {
              ...corsHeaders,
              'Content-Type': 'application/json'
            }
          });
        }
      } catch (smsError) {
        console.error('SMS sending error:', smsError);
        return new Response(JSON.stringify({
          success: false,
          error: 'Failed to send OTP'
        }), {
          status: 500,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
    } else if (action === 'verify') {
      // Verify OTP
      const { data: otpData } = await supabase.from('otp_verifications').select('*').eq('phone_number', phoneNumber).eq('otp_code', otp).eq('verified', false).gte('expires_at', new Date().toISOString()).single();
      if (!otpData) {
        return new Response(JSON.stringify({
          success: false,
          error: 'Invalid or expired OTP'
        }), {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json'
          }
        });
      }
      // Mark OTP as verified
      await supabase.from('otp_verifications').update({
        verified: true
      }).eq('id', otpData.id);
      return new Response(JSON.stringify({
        success: true,
        message: 'OTP verified successfully'
      }), {
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json'
        }
      });
    }
    return new Response(JSON.stringify({
      success: false,
      error: 'Invalid action'
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      }
    });
  } catch (error) {
    console.error('Error in fast2sms-otp function:', error);
    return new Response(JSON.stringify({
      success: false,
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
