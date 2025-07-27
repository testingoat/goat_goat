-- Phase 1.3 Notifications System Database Schema
-- 
-- This script creates the necessary database tables and policies for the
-- comprehensive notification system including automated notifications,
-- admin management, and delivery tracking.

-- ============================================================================
-- NOTIFICATION TEMPLATES TABLE
-- ============================================================================

-- Create notification templates for consistent messaging
CREATE TABLE IF NOT EXISTS notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_name TEXT NOT NULL UNIQUE,
  template_type TEXT NOT NULL CHECK (template_type IN ('order', 'review', 'promotion', 'system', 'custom')),
  
  -- Template content
  title_template TEXT NOT NULL,
  message_template TEXT NOT NULL,
  
  -- Template variables (JSON array of variable names)
  template_variables JSONB DEFAULT '[]'::jsonb,
  
  -- Delivery settings
  delivery_methods JSONB DEFAULT '["sms"]'::jsonb, -- ["sms", "push", "email"]
  is_active BOOLEAN DEFAULT true,
  
  -- Admin settings
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default templates
INSERT INTO notification_templates (template_name, template_type, title_template, message_template, template_variables) VALUES
  ('order_confirmed', 'order', 'Order Confirmed', 'Order #{order_number} confirmed! Total: ₹{total_amount}. Track your order in the app.', '["order_number", "total_amount"]'),
  ('order_shipped', 'order', 'Order Shipped', 'Order #{order_number} is on the way! Expected delivery: {delivery_date}.', '["order_number", "delivery_date"]'),
  ('order_delivered', 'order', 'Order Delivered', 'Order #{order_number} delivered! Thank you for choosing Goat Goat. Rate your experience in the app.', '["order_number"]'),
  ('review_submitted', 'review', 'Review Submitted', 'Thank you for your review! It will be published after moderation.', '[]'),
  ('review_approved', 'review', 'Review Published', 'Your review for {product_name} has been published. Thank you for sharing your experience!', '["product_name"]'),
  ('welcome_customer', 'system', 'Welcome to Goat Goat', 'Welcome {customer_name}! Start exploring fresh meat products from verified sellers.', '["customer_name"]'),
  ('low_stock_alert', 'system', 'Low Stock Alert', 'Product {product_name} is running low. Only {stock_count} items remaining.', '["product_name", "stock_count"]')
ON CONFLICT (template_name) DO NOTHING;

-- ============================================================================
-- ENHANCED NOTIFICATION LOGS TABLE
-- ============================================================================

-- Enhanced notification logs with template support and delivery tracking
CREATE TABLE IF NOT EXISTS notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Recipients
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  seller_id UUID REFERENCES sellers(id) ON DELETE CASCADE,
  recipient_phone TEXT,
  recipient_email TEXT,
  
  -- Notification content
  template_id UUID REFERENCES notification_templates(id),
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  
  -- Context and metadata
  context_data JSONB DEFAULT '{}'::jsonb, -- Variables used in template
  related_order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  related_product_id UUID REFERENCES meat_products(id) ON DELETE SET NULL,
  related_review_id UUID REFERENCES product_reviews(id) ON DELETE SET NULL,
  
  -- Delivery settings
  delivery_method TEXT NOT NULL CHECK (delivery_method IN ('sms', 'push', 'email')),
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Delivery tracking
  delivery_status TEXT DEFAULT 'pending' CHECK (delivery_status IN ('pending', 'sent', 'delivered', 'failed', 'cancelled')),
  external_id TEXT, -- ID from external service (Fast2SMS, FCM, etc.)
  delivery_attempts INTEGER DEFAULT 0,
  error_message TEXT,
  
  -- Timestamps
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  sent_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_notification_logs_customer_id ON notification_logs(customer_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_seller_id ON notification_logs(seller_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_delivery_status ON notification_logs(delivery_status);
CREATE INDEX IF NOT EXISTS idx_notification_logs_notification_type ON notification_logs(notification_type);
CREATE INDEX IF NOT EXISTS idx_notification_logs_scheduled_at ON notification_logs(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_notification_logs_created_at ON notification_logs(created_at);

-- ============================================================================
-- NOTIFICATION PREFERENCES TABLE
-- ============================================================================

-- User notification preferences (extends existing customers.preferences)
CREATE TABLE IF NOT EXISTS notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  seller_id UUID REFERENCES sellers(id) ON DELETE CASCADE,
  
  -- Notification type preferences
  order_notifications BOOLEAN DEFAULT true,
  review_notifications BOOLEAN DEFAULT true,
  promotion_notifications BOOLEAN DEFAULT false,
  system_notifications BOOLEAN DEFAULT true,
  
  -- Delivery method preferences
  sms_enabled BOOLEAN DEFAULT true,
  push_enabled BOOLEAN DEFAULT true,
  email_enabled BOOLEAN DEFAULT false,
  
  -- Timing preferences
  quiet_hours_start TIME DEFAULT '22:00',
  quiet_hours_end TIME DEFAULT '08:00',
  timezone TEXT DEFAULT 'Asia/Kolkata',
  
  -- Frequency limits
  max_daily_notifications INTEGER DEFAULT 10,
  max_promotional_per_week INTEGER DEFAULT 3,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Ensure only one preference record per user
  UNIQUE(customer_id),
  UNIQUE(seller_id),
  CHECK ((customer_id IS NOT NULL AND seller_id IS NULL) OR (customer_id IS NULL AND seller_id IS NOT NULL))
);

-- ============================================================================
-- NOTIFICATION CAMPAIGNS TABLE (Admin Management)
-- ============================================================================

-- Bulk notification campaigns for admin management
CREATE TABLE IF NOT EXISTS notification_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_name TEXT NOT NULL,
  campaign_description TEXT,
  
  -- Campaign settings
  template_id UUID REFERENCES notification_templates(id),
  target_audience TEXT NOT NULL CHECK (target_audience IN ('all_customers', 'all_sellers', 'specific_customers', 'specific_sellers', 'custom_filter')),
  audience_filter JSONB DEFAULT '{}'::jsonb, -- Filter criteria for custom targeting
  
  -- Scheduling
  scheduled_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_scheduled BOOLEAN DEFAULT false,
  
  -- Campaign status
  campaign_status TEXT DEFAULT 'draft' CHECK (campaign_status IN ('draft', 'scheduled', 'sending', 'completed', 'cancelled')),
  
  -- Statistics
  total_recipients INTEGER DEFAULT 0,
  sent_count INTEGER DEFAULT 0,
  delivered_count INTEGER DEFAULT 0,
  failed_count INTEGER DEFAULT 0,
  
  -- Admin tracking
  created_by UUID REFERENCES auth.users(id),
  started_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- NOTIFICATION ANALYTICS TABLE
-- ============================================================================

-- Analytics for notification performance
CREATE TABLE IF NOT EXISTS notification_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL,
  
  -- Delivery statistics
  total_sent INTEGER DEFAULT 0,
  total_delivered INTEGER DEFAULT 0,
  total_failed INTEGER DEFAULT 0,
  
  -- By delivery method
  sms_sent INTEGER DEFAULT 0,
  sms_delivered INTEGER DEFAULT 0,
  push_sent INTEGER DEFAULT 0,
  push_delivered INTEGER DEFAULT 0,
  email_sent INTEGER DEFAULT 0,
  email_delivered INTEGER DEFAULT 0,
  
  -- By notification type
  order_notifications INTEGER DEFAULT 0,
  review_notifications INTEGER DEFAULT 0,
  promotion_notifications INTEGER DEFAULT 0,
  system_notifications INTEGER DEFAULT 0,
  
  -- Performance metrics
  average_delivery_time_seconds INTEGER DEFAULT 0,
  delivery_rate DECIMAL(5,2) DEFAULT 0.00,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(date)
);

-- ============================================================================
-- RLS POLICIES FOR NOTIFICATION SYSTEM
-- ============================================================================

-- Enable RLS on all notification tables
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_analytics ENABLE ROW LEVEL SECURITY;

-- Notification Templates Policies
CREATE POLICY "Anyone can view active templates" ON notification_templates
FOR SELECT USING (is_active = true);

CREATE POLICY "Service role can manage templates" ON notification_templates
FOR ALL USING (auth.role() = 'service_role');

-- Notification Logs Policies
CREATE POLICY "Users can view their own notifications" ON notification_logs
FOR SELECT USING (
  customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid()) OR
  seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
);

CREATE POLICY "Service role can manage all notifications" ON notification_logs
FOR ALL USING (auth.role() = 'service_role');

-- Notification Preferences Policies
CREATE POLICY "Users can manage their own preferences" ON notification_preferences
FOR ALL USING (
  customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid()) OR
  seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
);

-- Notification Campaigns Policies
CREATE POLICY "Service role can manage campaigns" ON notification_campaigns
FOR ALL USING (auth.role() = 'service_role');

-- Notification Analytics Policies
CREATE POLICY "Service role can view analytics" ON notification_analytics
FOR SELECT USING (auth.role() = 'service_role');

-- ============================================================================
-- UTILITY FUNCTIONS FOR NOTIFICATION MANAGEMENT
-- ============================================================================

-- Function to render notification template
CREATE OR REPLACE FUNCTION render_notification_template(
  template_name_param TEXT,
  context_data_param JSONB
)
RETURNS TABLE(title TEXT, message TEXT) AS $$
DECLARE
  template_record RECORD;
  rendered_title TEXT;
  rendered_message TEXT;
  variable_name TEXT;
  variable_value TEXT;
BEGIN
  -- Get template
  SELECT title_template, message_template, template_variables
  INTO template_record
  FROM notification_templates
  WHERE template_name = template_name_param AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template not found: %', template_name_param;
  END IF;
  
  rendered_title := template_record.title_template;
  rendered_message := template_record.message_template;
  
  -- Replace variables in title and message
  FOR variable_name IN SELECT jsonb_array_elements_text(template_record.template_variables) LOOP
    variable_value := context_data_param ->> variable_name;
    IF variable_value IS NOT NULL THEN
      rendered_title := REPLACE(rendered_title, '{' || variable_name || '}', variable_value);
      rendered_message := REPLACE(rendered_message, '{' || variable_name || '}', variable_value);
    END IF;
  END LOOP;
  
  RETURN QUERY SELECT rendered_title, rendered_message;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check notification preferences
CREATE OR REPLACE FUNCTION should_send_notification(
  target_customer_id UUID DEFAULT NULL,
  target_seller_id UUID DEFAULT NULL,
  notification_type_param TEXT,
  delivery_method_param TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
  preferences_record RECORD;
  current_hour INTEGER;
  daily_count INTEGER;
BEGIN
  -- Get user preferences
  SELECT * INTO preferences_record
  FROM notification_preferences
  WHERE (customer_id = target_customer_id AND target_customer_id IS NOT NULL)
     OR (seller_id = target_seller_id AND target_seller_id IS NOT NULL);
  
  -- If no preferences found, use defaults (allow notification)
  IF NOT FOUND THEN
    RETURN true;
  END IF;
  
  -- Check delivery method preference
  CASE delivery_method_param
    WHEN 'sms' THEN
      IF NOT preferences_record.sms_enabled THEN RETURN false; END IF;
    WHEN 'push' THEN
      IF NOT preferences_record.push_enabled THEN RETURN false; END IF;
    WHEN 'email' THEN
      IF NOT preferences_record.email_enabled THEN RETURN false; END IF;
  END CASE;
  
  -- Check notification type preference
  CASE notification_type_param
    WHEN 'order' THEN
      IF NOT preferences_record.order_notifications THEN RETURN false; END IF;
    WHEN 'review' THEN
      IF NOT preferences_record.review_notifications THEN RETURN false; END IF;
    WHEN 'promotion' THEN
      IF NOT preferences_record.promotion_notifications THEN RETURN false; END IF;
    WHEN 'system' THEN
      IF NOT preferences_record.system_notifications THEN RETURN false; END IF;
  END CASE;
  
  -- Check quiet hours
  current_hour := EXTRACT(HOUR FROM NOW() AT TIME ZONE preferences_record.timezone);
  IF current_hour >= EXTRACT(HOUR FROM preferences_record.quiet_hours_start) OR
     current_hour < EXTRACT(HOUR FROM preferences_record.quiet_hours_end) THEN
    -- During quiet hours, only allow urgent notifications
    IF notification_type_param NOT IN ('order', 'system') THEN
      RETURN false;
    END IF;
  END IF;
  
  -- Check daily limits
  SELECT COUNT(*) INTO daily_count
  FROM notification_logs
  WHERE (customer_id = target_customer_id OR seller_id = target_seller_id)
    AND DATE(created_at) = CURRENT_DATE
    AND delivery_status IN ('sent', 'delivered');
  
  IF daily_count >= preferences_record.max_daily_notifications THEN
    RETURN false;
  END IF;
  
  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update notification analytics
CREATE OR REPLACE FUNCTION update_notification_analytics(target_date DATE DEFAULT CURRENT_DATE)
RETURNS VOID AS $$
DECLARE
  analytics_data RECORD;
BEGIN
  -- Calculate analytics for the target date
  SELECT 
    COUNT(*) as total_sent,
    COUNT(CASE WHEN delivery_status = 'delivered' THEN 1 END) as total_delivered,
    COUNT(CASE WHEN delivery_status = 'failed' THEN 1 END) as total_failed,
    COUNT(CASE WHEN delivery_method = 'sms' THEN 1 END) as sms_sent,
    COUNT(CASE WHEN delivery_method = 'sms' AND delivery_status = 'delivered' THEN 1 END) as sms_delivered,
    COUNT(CASE WHEN delivery_method = 'push' THEN 1 END) as push_sent,
    COUNT(CASE WHEN delivery_method = 'push' AND delivery_status = 'delivered' THEN 1 END) as push_delivered,
    COUNT(CASE WHEN delivery_method = 'email' THEN 1 END) as email_sent,
    COUNT(CASE WHEN delivery_method = 'email' AND delivery_status = 'delivered' THEN 1 END) as email_delivered,
    COUNT(CASE WHEN notification_type = 'order' THEN 1 END) as order_notifications,
    COUNT(CASE WHEN notification_type = 'review' THEN 1 END) as review_notifications,
    COUNT(CASE WHEN notification_type = 'promotion' THEN 1 END) as promotion_notifications,
    COUNT(CASE WHEN notification_type = 'system' THEN 1 END) as system_notifications,
    COALESCE(AVG(EXTRACT(EPOCH FROM (delivered_at - sent_at))), 0) as avg_delivery_time,
    CASE 
      WHEN COUNT(*) > 0 THEN (COUNT(CASE WHEN delivery_status = 'delivered' THEN 1 END) * 100.0 / COUNT(*))
      ELSE 0 
    END as delivery_rate
  INTO analytics_data
  FROM notification_logs
  WHERE DATE(created_at) = target_date;

  -- Upsert analytics record
  INSERT INTO notification_analytics (
    date, total_sent, total_delivered, total_failed,
    sms_sent, sms_delivered, push_sent, push_delivered, email_sent, email_delivered,
    order_notifications, review_notifications, promotion_notifications, system_notifications,
    average_delivery_time_seconds, delivery_rate
  ) VALUES (
    target_date, analytics_data.total_sent, analytics_data.total_delivered, analytics_data.total_failed,
    analytics_data.sms_sent, analytics_data.sms_delivered, analytics_data.push_sent, analytics_data.push_delivered,
    analytics_data.email_sent, analytics_data.email_delivered,
    analytics_data.order_notifications, analytics_data.review_notifications,
    analytics_data.promotion_notifications, analytics_data.system_notifications,
    analytics_data.avg_delivery_time::INTEGER, analytics_data.delivery_rate
  )
  ON CONFLICT (date) DO UPDATE SET
    total_sent = EXCLUDED.total_sent,
    total_delivered = EXCLUDED.total_delivered,
    total_failed = EXCLUDED.total_failed,
    sms_sent = EXCLUDED.sms_sent,
    sms_delivered = EXCLUDED.sms_delivered,
    push_sent = EXCLUDED.push_sent,
    push_delivered = EXCLUDED.push_delivered,
    email_sent = EXCLUDED.email_sent,
    email_delivered = EXCLUDED.email_delivered,
    order_notifications = EXCLUDED.order_notifications,
    review_notifications = EXCLUDED.review_notifications,
    promotion_notifications = EXCLUDED.promotion_notifications,
    system_notifications = EXCLUDED.system_notifications,
    average_delivery_time_seconds = EXCLUDED.average_delivery_time_seconds,
    delivery_rate = EXCLUDED.delivery_rate;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify tables were created successfully
DO $$
BEGIN
  -- Check if all tables exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_templates') THEN
    RAISE EXCEPTION 'notification_templates table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_preferences') THEN
    RAISE EXCEPTION 'notification_preferences table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_campaigns') THEN
    RAISE EXCEPTION 'notification_campaigns table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'notification_analytics') THEN
    RAISE EXCEPTION 'notification_analytics table was not created';
  END IF;
  
  RAISE NOTICE 'All Phase 1.3 Notification System tables created successfully!';
  
  -- Show template count
  RAISE NOTICE 'Default notification templates: %', (SELECT COUNT(*) FROM notification_templates);
END $$;
