-- Create seller approval webhook trigger
-- This trigger automatically sends new sellers to Odoo for approval

-- First, create a function to call the seller approval webhook
CREATE OR REPLACE FUNCTION notify_seller_for_approval()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url TEXT;
  webhook_payload JSONB;
  http_response RECORD;
BEGIN
  -- Only process new sellers with pending status
  IF NEW.approval_status = 'pending' AND (OLD IS NULL OR OLD.approval_status != 'pending') THEN
    
    -- Log the trigger execution
    RAISE LOG 'Seller approval trigger fired for seller: % (ID: %)', NEW.seller_name, NEW.id;
    
    -- Construct webhook URL
    webhook_url := current_setting('app.supabase_url', true) || '/functions/v1/seller-approval-webhook';
    
    -- Prepare webhook payload for initial notification to Odoo
    -- This creates the seller in Odoo with pending status
    webhook_payload := jsonb_build_object(
      'seller_id', NEW.id,
      'seller_name', NEW.seller_name,
      'contact_phone', NEW.contact_phone,
      'seller_type', NEW.seller_type,
      'business_city', NEW.business_city,
      'business_address', NEW.business_address,
      'business_pincode', NEW.business_pincode,
      'gstin', NEW.gstin,
      'fssai_license', NEW.fssai_license,
      'bank_account_number', NEW.bank_account_number,
      'ifsc_code', NEW.ifsc_code,
      'account_holder_name', NEW.account_holder_name,
      'aadhaar_number', NEW.aadhaar_number,
      'action', 'create_for_approval',
      'created_at', NEW.created_at,
      'updated_at', NEW.updated_at
    );
    
    -- Log the payload
    RAISE LOG 'Sending seller to Odoo for approval: %', webhook_payload;
    
    -- Make HTTP request to webhook (async, non-blocking)
    -- Using pg_net extension for HTTP requests
    SELECT INTO http_response
      net.http_post(
        url := webhook_url,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-api-key', current_setting('app.webhook_api_key', true)
        ),
        body := webhook_payload
      );
    
    -- Log the response (but don't fail the transaction if webhook fails)
    IF http_response.status_code = 200 THEN
      RAISE LOG 'Seller approval webhook succeeded for seller: %', NEW.seller_name;
    ELSE
      RAISE WARNING 'Seller approval webhook failed for seller: % (Status: %, Response: %)', 
        NEW.seller_name, http_response.status_code, http_response.content;
    END IF;
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS seller_approval_webhook_trigger ON sellers;
CREATE TRIGGER seller_approval_webhook_trigger
  AFTER INSERT OR UPDATE ON sellers
  FOR EACH ROW
  EXECUTE FUNCTION notify_seller_for_approval();

-- Add comments for documentation
COMMENT ON FUNCTION notify_seller_for_approval() IS 'Automatically sends new sellers to Odoo for approval via webhook';
COMMENT ON TRIGGER seller_approval_webhook_trigger ON sellers IS 'Triggers seller approval webhook when new sellers are created';

-- Create a manual function to resend seller for approval (for testing/recovery)
CREATE OR REPLACE FUNCTION resend_seller_for_approval(seller_uuid UUID)
RETURNS JSONB AS $$
DECLARE
  seller_record RECORD;
  webhook_url TEXT;
  webhook_payload JSONB;
  http_response RECORD;
BEGIN
  -- Get seller data
  SELECT * INTO seller_record FROM sellers WHERE id = seller_uuid;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Seller not found');
  END IF;
  
  -- Construct webhook URL
  webhook_url := current_setting('app.supabase_url', true) || '/functions/v1/seller-approval-webhook';
  
  -- Prepare webhook payload
  webhook_payload := jsonb_build_object(
    'seller_id', seller_record.id,
    'seller_name', seller_record.seller_name,
    'contact_phone', seller_record.contact_phone,
    'seller_type', seller_record.seller_type,
    'business_city', seller_record.business_city,
    'business_address', seller_record.business_address,
    'business_pincode', seller_record.business_pincode,
    'gstin', seller_record.gstin,
    'fssai_license', seller_record.fssai_license,
    'bank_account_number', seller_record.bank_account_number,
    'ifsc_code', seller_record.ifsc_code,
    'account_holder_name', seller_record.account_holder_name,
    'aadhaar_number', seller_record.aadhaar_number,
    'action', 'resend_for_approval',
    'created_at', seller_record.created_at,
    'updated_at', seller_record.updated_at
  );
  
  -- Make HTTP request
  SELECT INTO http_response
    net.http_post(
      url := webhook_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-api-key', current_setting('app.webhook_api_key', true)
      ),
      body := webhook_payload
    );
  
  -- Return result
  IF http_response.status_code = 200 THEN
    RETURN jsonb_build_object(
      'success', true, 
      'message', 'Seller resent for approval successfully',
      'seller_name', seller_record.seller_name
    );
  ELSE
    RETURN jsonb_build_object(
      'success', false, 
      'error', 'Webhook failed',
      'status_code', http_response.status_code,
      'response', http_response.content
    );
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Add comment
COMMENT ON FUNCTION resend_seller_for_approval(UUID) IS 'Manually resend a seller for approval (for testing/recovery)';

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION notify_seller_for_approval() TO authenticated;
GRANT EXECUTE ON FUNCTION resend_seller_for_approval(UUID) TO authenticated;
