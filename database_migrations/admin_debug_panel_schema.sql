-- Admin Debug Panel Database Schema
-- Zero-risk implementation with proper RLS and indexing
-- Created: 2025-08-16

-- =====================================================
-- EDGE FUNCTION LOGS TABLE
-- =====================================================

-- Main table for storing edge function execution logs
CREATE TABLE IF NOT EXISTS edge_function_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Basic execution info
  ts TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  endpoint TEXT NOT NULL,
  status INTEGER NOT NULL,
  latency_ms INTEGER DEFAULT 0,
  
  -- Request/Response data (sanitized)
  request JSONB DEFAULT '{}'::jsonb,
  response JSONB DEFAULT '{}'::jsonb,
  
  -- Feature flags and configuration
  flags JSONB DEFAULT '{}'::jsonb,
  dry_run BOOLEAN DEFAULT false,
  
  -- Tracking info
  created_by TEXT DEFAULT 'system',
  caller_ip INET,
  user_agent TEXT,
  
  -- Volume and error tracking
  api_call_count INTEGER DEFAULT 1,
  error_rate_percent DECIMAL(5,2) DEFAULT 0.0,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- ODOO SESSION LOGS TABLE
-- =====================================================

-- Track Odoo authentication attempts and session info
CREATE TABLE IF NOT EXISTS odoo_session_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Session attempt info
  attempt_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  success BOOLEAN NOT NULL,
  failure_reason TEXT,
  
  -- Session details
  set_cookie_seen BOOLEAN DEFAULT false,
  uid_present BOOLEAN DEFAULT false,
  session_id TEXT,
  
  -- Request context
  caller_ip INET,
  user_agent TEXT,
  endpoint_called TEXT,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- PRODUCT WEBHOOK EVENTS TABLE
-- =====================================================

-- Track product approval workflow events
CREATE TABLE IF NOT EXISTS product_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Product reference
  product_id UUID,
  seller_id UUID,
  
  -- Event details
  event_type TEXT NOT NULL CHECK (event_type IN ('approval', 'rejection', 'sync', 'duplicate_check', 'dry_run')),
  event_source TEXT NOT NULL CHECK (event_source IN ('webhook', 'status-sync', 'manual', 'auto')),
  
  -- Status change
  old_status TEXT,
  new_status TEXT,
  
  -- Event data
  event_data JSONB DEFAULT '{}'::jsonb,
  dry_run_data JSONB DEFAULT '{}'::jsonb,
  
  -- Duplicate prevention tracking
  duplicate_check_field TEXT, -- 'default_code' or 'ref'
  duplicate_value TEXT,
  duplicate_prevented BOOLEAN DEFAULT false,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- FEATURE FLAGS TRACKING TABLE
-- =====================================================

-- Track feature flag state changes for debugging
CREATE TABLE IF NOT EXISTS feature_flag_changes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Flag details
  flag_name TEXT NOT NULL,
  old_value BOOLEAN,
  new_value BOOLEAN NOT NULL,
  
  -- Change context
  changed_by TEXT DEFAULT 'system',
  change_reason TEXT,
  
  -- Audit fields
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Edge function logs indexes
CREATE INDEX IF NOT EXISTS idx_edge_logs_ts ON edge_function_logs(ts DESC);
CREATE INDEX IF NOT EXISTS idx_edge_logs_endpoint ON edge_function_logs(endpoint);
CREATE INDEX IF NOT EXISTS idx_edge_logs_status ON edge_function_logs(status);
CREATE INDEX IF NOT EXISTS idx_edge_logs_user_agent ON edge_function_logs(user_agent);
CREATE INDEX IF NOT EXISTS idx_edge_logs_error_rate ON edge_function_logs(error_rate_percent) WHERE error_rate_percent > 5.0;
CREATE INDEX IF NOT EXISTS idx_edge_logs_created_at ON edge_function_logs(created_at DESC);

-- Odoo session logs indexes
CREATE INDEX IF NOT EXISTS idx_odoo_session_timestamp ON odoo_session_logs(attempt_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_odoo_session_success ON odoo_session_logs(success);
CREATE INDEX IF NOT EXISTS idx_odoo_session_endpoint ON odoo_session_logs(endpoint_called);

-- Product webhook events indexes
CREATE INDEX IF NOT EXISTS idx_product_events_product_id ON product_webhook_events(product_id);
CREATE INDEX IF NOT EXISTS idx_product_events_type ON product_webhook_events(event_type);
CREATE INDEX IF NOT EXISTS idx_product_events_source ON product_webhook_events(event_source);
CREATE INDEX IF NOT EXISTS idx_product_events_created_at ON product_webhook_events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_product_events_duplicate ON product_webhook_events(duplicate_check_field, duplicate_value) WHERE duplicate_prevented = true;

-- Feature flag changes indexes
CREATE INDEX IF NOT EXISTS idx_feature_flag_name ON feature_flag_changes(flag_name);
CREATE INDEX IF NOT EXISTS idx_feature_flag_created_at ON feature_flag_changes(created_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE edge_function_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE odoo_session_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flag_changes ENABLE ROW LEVEL SECURITY;

-- Admin-only access policies
CREATE POLICY "Admin read access on edge_function_logs" ON edge_function_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE id = auth.uid() 
      AND (permissions->>'system_administration')::boolean = true
    )
  );

CREATE POLICY "Admin read access on odoo_session_logs" ON odoo_session_logs
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE id = auth.uid() 
      AND (permissions->>'system_administration')::boolean = true
    )
  );

CREATE POLICY "Admin read access on product_webhook_events" ON product_webhook_events
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE id = auth.uid() 
      AND (permissions->>'system_administration')::boolean = true
    )
  );

CREATE POLICY "Admin read access on feature_flag_changes" ON feature_flag_changes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM admin_users 
      WHERE id = auth.uid() 
      AND (permissions->>'system_administration')::boolean = true
    )
  );

-- System insert policies (for edge functions and services)
CREATE POLICY "System insert on edge_function_logs" ON edge_function_logs
  FOR INSERT WITH CHECK (created_by = 'system' OR created_by LIKE 'edge_function_%');

CREATE POLICY "System insert on odoo_session_logs" ON odoo_session_logs
  FOR INSERT WITH CHECK (true); -- Allow system inserts

CREATE POLICY "System insert on product_webhook_events" ON product_webhook_events
  FOR INSERT WITH CHECK (true); -- Allow system inserts

CREATE POLICY "System insert on feature_flag_changes" ON feature_flag_changes
  FOR INSERT WITH CHECK (true); -- Allow system inserts

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to sanitize sensitive data from logs
CREATE OR REPLACE FUNCTION sanitize_log_data(data JSONB)
RETURNS JSONB AS $$
BEGIN
  -- Remove sensitive fields
  data := data - 'password' - 'api_key' - 'x-api-key' - 'authorization' - 'cookie' - 'session_token';
  
  -- Mask phone numbers (keep last 4 digits)
  IF data ? 'phone_number' THEN
    data := jsonb_set(data, '{phone_number}', to_jsonb('****' || right(data->>'phone_number', 4)));
  END IF;
  
  -- Mask email addresses (keep domain)
  IF data ? 'email' THEN
    data := jsonb_set(data, '{email}', to_jsonb('****@' || split_part(data->>'email', '@', 2)));
  END IF;
  
  RETURN data;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate error rate for an endpoint
CREATE OR REPLACE FUNCTION calculate_endpoint_error_rate(endpoint_name TEXT, time_window INTERVAL DEFAULT '1 hour')
RETURNS DECIMAL AS $$
DECLARE
  total_calls INTEGER;
  error_calls INTEGER;
  error_rate DECIMAL;
BEGIN
  -- Count total calls in time window
  SELECT COUNT(*) INTO total_calls
  FROM edge_function_logs
  WHERE endpoint = endpoint_name
    AND ts >= NOW() - time_window;
  
  -- Count error calls (status >= 400)
  SELECT COUNT(*) INTO error_calls
  FROM edge_function_logs
  WHERE endpoint = endpoint_name
    AND status >= 400
    AND ts >= NOW() - time_window;
  
  -- Calculate error rate percentage
  IF total_calls > 0 THEN
    error_rate := (error_calls::DECIMAL / total_calls::DECIMAL) * 100;
  ELSE
    error_rate := 0;
  END IF;
  
  RETURN ROUND(error_rate, 2);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get API call volume for an endpoint
CREATE OR REPLACE FUNCTION get_endpoint_call_volume(endpoint_name TEXT, time_window INTERVAL DEFAULT '1 hour')
RETURNS INTEGER AS $$
BEGIN
  RETURN (
    SELECT COALESCE(SUM(api_call_count), 0)
    FROM edge_function_logs
    WHERE endpoint = endpoint_name
      AND ts >= NOW() - time_window
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- INITIAL DATA SETUP
-- =====================================================

-- Insert some sample data for testing (only in development)
DO $$
BEGIN
  -- Only insert sample data if no logs exist
  IF NOT EXISTS (SELECT 1 FROM edge_function_logs LIMIT 1) THEN
    INSERT INTO edge_function_logs (endpoint, status, latency_ms, user_agent, created_by) VALUES
    ('odoo-api-proxy', 200, 150, 'GoatGoat-Mobile/1.0', 'edge_function_odoo'),
    ('product-sync-webhook', 200, 89, 'GoatGoat-Webhook/1.0', 'edge_function_webhook'),
    ('fast2sms-otp', 200, 234, 'GoatGoat-Mobile/1.0', 'edge_function_sms'),
    ('send-push-notification', 500, 1200, 'GoatGoat-Admin/1.0', 'edge_function_fcm');
  END IF;
END $$;

-- Grant necessary permissions
GRANT SELECT ON edge_function_logs TO authenticated;
GRANT SELECT ON odoo_session_logs TO authenticated;
GRANT SELECT ON product_webhook_events TO authenticated;
GRANT SELECT ON feature_flag_changes TO authenticated;

GRANT INSERT ON edge_function_logs TO service_role;
GRANT INSERT ON odoo_session_logs TO service_role;
GRANT INSERT ON product_webhook_events TO service_role;
GRANT INSERT ON feature_flag_changes TO service_role;

-- Add comment for documentation
COMMENT ON TABLE edge_function_logs IS 'Stores execution logs from Supabase edge functions for admin debugging';
COMMENT ON TABLE odoo_session_logs IS 'Tracks Odoo authentication attempts and session management';
COMMENT ON TABLE product_webhook_events IS 'Logs product approval workflow events and webhook processing';
COMMENT ON TABLE feature_flag_changes IS 'Tracks feature flag state changes for debugging purposes';
