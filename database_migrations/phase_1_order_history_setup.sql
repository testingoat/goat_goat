-- Phase 1.1 Order History & Tracking Database Setup
-- 
-- This script creates the necessary database tables and policies for the
-- Order History & Tracking feature without modifying existing tables.
-- 
-- Key principles:
-- - No modifications to existing tables (orders, order_items, customers)
-- - New tables for feature flags and monitoring only
-- - Proper RLS policies for security
-- - Backward compatibility maintained

-- ============================================================================
-- FEATURE FLAGS TABLE
-- ============================================================================

-- Create feature flags table for remote feature flag management
CREATE TABLE IF NOT EXISTS feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_name TEXT NOT NULL UNIQUE,
  enabled BOOLEAN DEFAULT false,
  description TEXT,
  target_user_percentage INTEGER DEFAULT 0 CHECK (target_user_percentage >= 0 AND target_user_percentage <= 100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert initial feature flags for Phase 1
INSERT INTO feature_flags (feature_name, enabled, description, target_user_percentage) VALUES
  ('order_history', false, 'Order History & Tracking feature for customers', 0),
  ('product_reviews', false, 'Product Reviews & Ratings system', 0),
  ('basic_notifications', false, 'Basic SMS notifications for order updates', 0),
  ('inventory_management', false, 'Advanced inventory management for sellers', 0),
  ('loyalty_program', false, 'Customer loyalty points and rewards program', 0),
  ('advanced_analytics', false, 'Advanced analytics dashboard for sellers', 0),
  ('multi_vendor', false, 'Multi-vendor marketplace functionality', 0),
  ('debug_mode', false, 'Debug mode for development and testing', 0),
  ('performance_monitoring', true, 'Performance monitoring and analytics', 100)
ON CONFLICT (feature_name) DO NOTHING;

-- RLS policies for feature flags
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

-- Allow public read access to feature flags (they control app behavior)
CREATE POLICY "Public can read feature flags" ON feature_flags
FOR SELECT USING (true);

-- Only authenticated users can modify feature flags (admin functionality)
CREATE POLICY "Authenticated users can manage feature flags" ON feature_flags
FOR ALL USING (auth.role() = 'authenticated');

-- ============================================================================
-- FEATURE USAGE LOGGING TABLE
-- ============================================================================

-- Create table for tracking feature usage and analytics
CREATE TABLE IF NOT EXISTS feature_usage_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_name TEXT NOT NULL,
  action TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id),
  user_type TEXT, -- 'customer', 'seller', 'admin'
  session_id TEXT,
  metadata JSONB, -- Additional context data
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for efficient querying
CREATE INDEX IF NOT EXISTS idx_feature_usage_logs_feature_name ON feature_usage_logs(feature_name);
CREATE INDEX IF NOT EXISTS idx_feature_usage_logs_timestamp ON feature_usage_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_feature_usage_logs_user_id ON feature_usage_logs(user_id);

-- RLS policies for feature usage logs
ALTER TABLE feature_usage_logs ENABLE ROW LEVEL SECURITY;

-- Allow public insert for usage tracking (anonymous usage is OK)
CREATE POLICY "Public can log feature usage" ON feature_usage_logs
FOR INSERT WITH CHECK (true);

-- Allow authenticated users to read their own usage logs
CREATE POLICY "Users can read their own usage logs" ON feature_usage_logs
FOR SELECT USING (auth.uid() = user_id OR auth.role() = 'service_role');

-- ============================================================================
-- FEATURE ERROR LOGGING TABLE
-- ============================================================================

-- Create table for tracking feature-specific errors
CREATE TABLE IF NOT EXISTS feature_error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_name TEXT NOT NULL,
  error_message TEXT NOT NULL,
  error_code TEXT,
  stack_trace TEXT,
  user_id UUID REFERENCES auth.users(id),
  user_type TEXT,
  context JSONB, -- Additional error context
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for efficient querying
CREATE INDEX IF NOT EXISTS idx_feature_error_logs_feature_name ON feature_error_logs(feature_name);
CREATE INDEX IF NOT EXISTS idx_feature_error_logs_timestamp ON feature_error_logs(timestamp);

-- RLS policies for error logs
ALTER TABLE feature_error_logs ENABLE ROW LEVEL SECURITY;

-- Allow public insert for error tracking
CREATE POLICY "Public can log feature errors" ON feature_error_logs
FOR INSERT WITH CHECK (true);

-- Allow service role to read all error logs for monitoring
CREATE POLICY "Service role can read all error logs" ON feature_error_logs
FOR SELECT USING (auth.role() = 'service_role');

-- ============================================================================
-- NOTIFICATION LOGS TABLE (for Phase 1.3 preparation)
-- ============================================================================

-- Create table for tracking notification delivery
CREATE TABLE IF NOT EXISTS notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  notification_type TEXT NOT NULL, -- 'order_confirmed', 'order_shipped', 'order_delivered'
  delivery_method TEXT NOT NULL, -- 'sms', 'email', 'push'
  recipient TEXT NOT NULL, -- phone number or email
  message TEXT NOT NULL,
  delivery_status TEXT DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'sent', 'failed', 'delivered')),
  external_id TEXT, -- ID from external service (Fast2SMS, etc.)
  error_message TEXT,
  sent_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_notification_logs_customer_id ON notification_logs(customer_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_order_id ON notification_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_delivery_status ON notification_logs(delivery_status);
CREATE INDEX IF NOT EXISTS idx_notification_logs_created_at ON notification_logs(created_at);

-- RLS policies for notification logs
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- Customers can view their own notification logs
CREATE POLICY "Customers can view their own notification logs" ON notification_logs
FOR SELECT USING (
  customer_id IN (
    SELECT id FROM customers WHERE user_id = auth.uid()
  )
);

-- Service role can manage all notification logs
CREATE POLICY "Service role can manage notification logs" ON notification_logs
FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- PERFORMANCE MONITORING TABLE
-- ============================================================================

-- Create table for tracking performance metrics
CREATE TABLE IF NOT EXISTS performance_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_name TEXT NOT NULL,
  metric_value NUMERIC NOT NULL,
  metric_unit TEXT, -- 'ms', 'seconds', 'count', 'bytes'
  feature_name TEXT,
  user_id UUID REFERENCES auth.users(id),
  session_id TEXT,
  context JSONB, -- Additional performance context
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_performance_metrics_metric_name ON performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_feature_name ON performance_metrics(feature_name);
CREATE INDEX IF NOT EXISTS idx_performance_metrics_timestamp ON performance_metrics(timestamp);

-- RLS policies for performance metrics
ALTER TABLE performance_metrics ENABLE ROW LEVEL SECURITY;

-- Allow public insert for performance tracking
CREATE POLICY "Public can log performance metrics" ON performance_metrics
FOR INSERT WITH CHECK (true);

-- Allow service role to read all performance metrics
CREATE POLICY "Service role can read performance metrics" ON performance_metrics
FOR SELECT USING (auth.role() = 'service_role');

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Function to enable a feature flag
CREATE OR REPLACE FUNCTION enable_feature_flag(flag_name TEXT, percentage INTEGER DEFAULT 100)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE feature_flags 
  SET enabled = true, 
      target_user_percentage = percentage,
      updated_at = NOW()
  WHERE feature_name = flag_name;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to disable a feature flag
CREATE OR REPLACE FUNCTION disable_feature_flag(flag_name TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE feature_flags 
  SET enabled = false, 
      target_user_percentage = 0,
      updated_at = NOW()
  WHERE feature_name = flag_name;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get feature usage statistics
CREATE OR REPLACE FUNCTION get_feature_usage_stats(flag_name TEXT, days_back INTEGER DEFAULT 7)
RETURNS TABLE(
  action TEXT,
  usage_count BIGINT,
  unique_users BIGINT,
  last_used TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ful.action,
    COUNT(*) as usage_count,
    COUNT(DISTINCT ful.user_id) as unique_users,
    MAX(ful.timestamp) as last_used
  FROM feature_usage_logs ful
  WHERE ful.feature_name = flag_name
    AND ful.timestamp >= NOW() - INTERVAL '1 day' * days_back
  GROUP BY ful.action
  ORDER BY usage_count DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify tables were created successfully
DO $$
BEGIN
  -- Check if all tables exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'feature_flags') THEN
    RAISE EXCEPTION 'feature_flags table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'feature_usage_logs') THEN
    RAISE EXCEPTION 'feature_usage_logs table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'feature_error_logs') THEN
    RAISE EXCEPTION 'feature_error_logs table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_logs') THEN
    RAISE EXCEPTION 'notification_logs table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'performance_metrics') THEN
    RAISE EXCEPTION 'performance_metrics table was not created';
  END IF;
  
  RAISE NOTICE 'All Phase 1.1 tables created successfully!';
  
  -- Show feature flags status
  RAISE NOTICE 'Feature flags status:';
  FOR rec IN SELECT feature_name, enabled, target_user_percentage FROM feature_flags ORDER BY feature_name LOOP
    RAISE NOTICE '  %: enabled=%, target=%', rec.feature_name, rec.enabled, rec.target_user_percentage;
  END LOOP;
END $$;
