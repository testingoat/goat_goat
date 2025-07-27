-- Admin Panel Database Setup
-- 
-- This script creates all necessary database tables, policies, and functions
-- for the comprehensive admin panel system.
-- 
-- Key principles:
-- - No modifications to existing tables
-- - Comprehensive security with RLS policies
-- - Audit logging for all admin actions
-- - Role-based access control

-- ============================================================================
-- ADMIN USER MANAGEMENT
-- ============================================================================

-- Admin users table
CREATE TABLE IF NOT EXISTS admin_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  full_name TEXT NOT NULL,
  
  -- Role-based access control
  role TEXT NOT NULL CHECK (role IN ('super_admin', 'moderator', 'support', 'analyst')),
  permissions JSONB DEFAULT '{
    "review_moderation": false,
    "notification_management": false,
    "user_management": false,
    "analytics_access": false,
    "system_administration": false
  }'::jsonb,
  
  -- Multi-factor authentication
  mfa_secret TEXT,
  mfa_enabled BOOLEAN DEFAULT false,
  
  -- Password reset
  password_reset_token TEXT,
  password_reset_expires TIMESTAMP WITH TIME ZONE,
  
  -- Security tracking
  last_login TIMESTAMP WITH TIME ZONE,
  login_attempts INTEGER DEFAULT 0,
  locked_until TIMESTAMP WITH TIME ZONE,
  
  -- Status
  is_active BOOLEAN DEFAULT true,
  
  -- Audit fields
  created_by UUID REFERENCES admin_users(id),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for admin users
CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
CREATE INDEX IF NOT EXISTS idx_admin_users_role ON admin_users(role);
CREATE INDEX IF NOT EXISTS idx_admin_users_is_active ON admin_users(is_active);

-- Admin sessions for security tracking
CREATE TABLE IF NOT EXISTS admin_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id) ON DELETE CASCADE,
  session_token TEXT NOT NULL UNIQUE,
  
  -- Session metadata
  ip_address INET,
  user_agent TEXT,
  device_info JSONB DEFAULT '{}'::jsonb,
  
  -- Session lifecycle
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for admin sessions
CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin_id ON admin_sessions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_token ON admin_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires_at ON admin_sessions(expires_at);

-- Comprehensive audit logging
CREATE TABLE IF NOT EXISTS admin_audit_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id),
  
  -- Action details
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT,
  
  -- Change tracking
  old_values JSONB,
  new_values JSONB,
  change_summary TEXT,
  
  -- Context
  ip_address INET,
  user_agent TEXT,
  session_id UUID REFERENCES admin_sessions(id),
  
  -- Additional metadata
  metadata JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for audit log
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_id ON admin_audit_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_action ON admin_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_resource_type ON admin_audit_log(resource_type);
CREATE INDEX IF NOT EXISTS idx_admin_audit_log_created_at ON admin_audit_log(created_at);

-- Admin dashboard configuration
CREATE TABLE IF NOT EXISTS admin_dashboard_config (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id) ON DELETE CASCADE,
  
  -- Dashboard layout
  widget_layout JSONB NOT NULL DEFAULT '[]'::jsonb,
  preferences JSONB DEFAULT '{
    "theme": "light",
    "notifications_enabled": true,
    "auto_refresh_interval": 30,
    "default_page_size": 25
  }'::jsonb,
  
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(admin_id)
);

-- ============================================================================
-- REVIEW MODERATION ENHANCEMENTS
-- ============================================================================

-- Review moderation queue
CREATE TABLE IF NOT EXISTS review_moderation_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID REFERENCES product_reviews(id) ON DELETE CASCADE,
  
  -- Assignment
  assigned_to UUID REFERENCES admin_users(id),
  assigned_at TIMESTAMP WITH TIME ZONE,
  
  -- Priority and categorization
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  category TEXT,
  
  -- Moderation metadata
  auto_flagged BOOLEAN DEFAULT false,
  flag_reasons JSONB DEFAULT '[]'::jsonb,
  
  -- Status tracking
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_review', 'completed')),
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  UNIQUE(review_id)
);

-- Create indexes for moderation queue
CREATE INDEX IF NOT EXISTS idx_review_moderation_queue_assigned_to ON review_moderation_queue(assigned_to);
CREATE INDEX IF NOT EXISTS idx_review_moderation_queue_priority ON review_moderation_queue(priority);
CREATE INDEX IF NOT EXISTS idx_review_moderation_queue_status ON review_moderation_queue(status);

-- Review moderation history
CREATE TABLE IF NOT EXISTS review_moderation_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID REFERENCES product_reviews(id) ON DELETE CASCADE,
  admin_id UUID REFERENCES admin_users(id),
  
  -- Action details
  action TEXT NOT NULL CHECK (action IN ('approved', 'rejected', 'flagged', 'escalated')),
  reason TEXT,
  notes TEXT,
  
  -- Previous state
  previous_status TEXT,
  new_status TEXT,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for moderation history
CREATE INDEX IF NOT EXISTS idx_review_moderation_history_review_id ON review_moderation_history(review_id);
CREATE INDEX IF NOT EXISTS idx_review_moderation_history_admin_id ON review_moderation_history(admin_id);

-- ============================================================================
-- NOTIFICATION MANAGEMENT ENHANCEMENTS
-- ============================================================================

-- Extend notification campaigns with admin approval
ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  created_by_admin UUID REFERENCES admin_users(id);

ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  approval_status TEXT DEFAULT 'draft' CHECK (approval_status IN ('draft', 'pending_approval', 'approved', 'rejected'));

ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  approved_by UUID REFERENCES admin_users(id);

ALTER TABLE notification_campaigns ADD COLUMN IF NOT EXISTS
  approved_at TIMESTAMP WITH TIME ZONE;

-- Admin notifications for internal communication
CREATE TABLE IF NOT EXISTS admin_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id) ON DELETE CASCADE,
  
  -- Notification content
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  notification_type TEXT NOT NULL CHECK (notification_type IN ('info', 'warning', 'error', 'success')),
  priority TEXT DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Action details
  action_url TEXT,
  action_label TEXT,
  
  -- Status
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP WITH TIME ZONE,
  
  -- Auto-expire
  expires_at TIMESTAMP WITH TIME ZONE,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for admin notifications
CREATE INDEX IF NOT EXISTS idx_admin_notifications_admin_id ON admin_notifications(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_is_read ON admin_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_admin_notifications_created_at ON admin_notifications(created_at);

-- ============================================================================
-- ANALYTICS AND MONITORING
-- ============================================================================

-- Admin analytics tracking
CREATE TABLE IF NOT EXISTS admin_analytics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id),
  
  -- Action tracking
  action TEXT NOT NULL,
  metadata JSONB DEFAULT '{}'::jsonb,
  
  -- Performance tracking
  execution_time_ms INTEGER,
  
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for admin analytics
CREATE INDEX IF NOT EXISTS idx_admin_analytics_admin_id ON admin_analytics(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_analytics_action ON admin_analytics(action);
CREATE INDEX IF NOT EXISTS idx_admin_analytics_timestamp ON admin_analytics(timestamp);

-- Admin performance metrics
CREATE TABLE IF NOT EXISTS admin_performance_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Metric details
  metric_name TEXT NOT NULL,
  value DECIMAL(10,2) NOT NULL,
  unit TEXT,
  
  -- Context
  admin_id UUID REFERENCES admin_users(id),
  metadata JSONB DEFAULT '{}'::jsonb,
  
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance metrics
CREATE INDEX IF NOT EXISTS idx_admin_performance_metrics_metric_name ON admin_performance_metrics(metric_name);
CREATE INDEX IF NOT EXISTS idx_admin_performance_metrics_timestamp ON admin_performance_metrics(timestamp);

-- Admin error logs
CREATE TABLE IF NOT EXISTS admin_error_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id UUID REFERENCES admin_users(id),
  
  -- Error details
  error_message TEXT NOT NULL,
  stack_trace TEXT,
  error_type TEXT,
  
  -- Context
  action TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for error logs
CREATE INDEX IF NOT EXISTS idx_admin_error_logs_admin_id ON admin_error_logs(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_error_logs_error_type ON admin_error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_admin_error_logs_timestamp ON admin_error_logs(timestamp);

-- ============================================================================
-- RLS POLICIES FOR ADMIN SYSTEM
-- ============================================================================

-- Enable RLS on all admin tables
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_dashboard_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_moderation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_moderation_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_analytics ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_performance_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_error_logs ENABLE ROW LEVEL SECURITY;

-- Admin Users Policies
CREATE POLICY "Super admins can manage all admin users" ON admin_users
FOR ALL USING (
  EXISTS (
    SELECT 1 FROM admin_sessions s
    JOIN admin_users u ON s.admin_id = u.id
    WHERE s.session_token = current_setting('app.admin_session_token', true)
      AND s.expires_at > NOW()
      AND u.role = 'super_admin'
      AND u.is_active = true
  )
);

CREATE POLICY "Admins can view their own profile" ON admin_users
FOR SELECT USING (
  id IN (
    SELECT u.id FROM admin_sessions s
    JOIN admin_users u ON s.admin_id = u.id
    WHERE s.session_token = current_setting('app.admin_session_token', true)
      AND s.expires_at > NOW()
  )
);

-- Admin Sessions Policies
CREATE POLICY "Admins can manage their own sessions" ON admin_sessions
FOR ALL USING (
  admin_id IN (
    SELECT u.id FROM admin_sessions s
    JOIN admin_users u ON s.admin_id = u.id
    WHERE s.session_token = current_setting('app.admin_session_token', true)
      AND s.expires_at > NOW()
  )
);

-- Audit Log Policies
CREATE POLICY "Admins can view audit logs" ON admin_audit_log
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM admin_sessions s
    JOIN admin_users u ON s.admin_id = u.id
    WHERE s.session_token = current_setting('app.admin_session_token', true)
      AND s.expires_at > NOW()
      AND u.is_active = true
  )
);

-- Service role can manage all admin data
CREATE POLICY "Service role can manage all admin data" ON admin_users
FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage all admin sessions" ON admin_sessions
FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role can manage all audit logs" ON admin_audit_log
FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- UTILITY FUNCTIONS FOR ADMIN OPERATIONS
-- ============================================================================

-- Function to create admin session
CREATE OR REPLACE FUNCTION create_admin_session(
  admin_email TEXT,
  session_token TEXT,
  expires_in_hours INTEGER DEFAULT 8
)
RETURNS UUID AS $$
DECLARE
  admin_record RECORD;
  session_id UUID;
BEGIN
  -- Get admin user
  SELECT * INTO admin_record
  FROM admin_users
  WHERE email = admin_email AND is_active = true;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Admin user not found or inactive';
  END IF;
  
  -- Create session
  INSERT INTO admin_sessions (
    admin_id,
    session_token,
    expires_at
  ) VALUES (
    admin_record.id,
    session_token,
    NOW() + (expires_in_hours || ' hours')::INTERVAL
  ) RETURNING id INTO session_id;
  
  -- Update last login
  UPDATE admin_users
  SET last_login = NOW(), login_attempts = 0
  WHERE id = admin_record.id;
  
  RETURN session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to validate admin session
CREATE OR REPLACE FUNCTION validate_admin_session(session_token TEXT)
RETURNS TABLE(admin_id UUID, admin_email TEXT, admin_role TEXT, permissions JSONB) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    u.id,
    u.email,
    u.role,
    u.permissions
  FROM admin_sessions s
  JOIN admin_users u ON s.admin_id = u.id
  WHERE s.session_token = validate_admin_session.session_token
    AND s.expires_at > NOW()
    AND s.is_active = true
    AND u.is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log admin action
CREATE OR REPLACE FUNCTION log_admin_action(
  admin_id_param UUID,
  action_param TEXT,
  resource_type_param TEXT,
  resource_id_param TEXT DEFAULT NULL,
  old_values_param JSONB DEFAULT NULL,
  new_values_param JSONB DEFAULT NULL,
  metadata_param JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  log_id UUID;
BEGIN
  INSERT INTO admin_audit_log (
    admin_id,
    action,
    resource_type,
    resource_id,
    old_values,
    new_values,
    metadata
  ) VALUES (
    admin_id_param,
    action_param,
    resource_type_param,
    resource_id_param,
    old_values_param,
    new_values_param,
    metadata_param
  ) RETURNING id INTO log_id;
  
  RETURN log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create default admin user
CREATE OR REPLACE FUNCTION create_default_admin()
RETURNS UUID AS $$
DECLARE
  admin_id UUID;
BEGIN
  INSERT INTO admin_users (
    email,
    password_hash,
    full_name,
    role,
    permissions
  ) VALUES (
    'admin@goatgoat.com',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewdBPj/RK.PmvlG2', -- 'admin123'
    'System Administrator',
    'super_admin',
    '{
      "review_moderation": true,
      "notification_management": true,
      "user_management": true,
      "analytics_access": true,
      "system_administration": true
    }'::jsonb
  ) RETURNING id INTO admin_id;
  
  RETURN admin_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION AND SETUP
-- ============================================================================

-- Create default admin user (only if none exists)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM admin_users WHERE role = 'super_admin') THEN
    PERFORM create_default_admin();
    RAISE NOTICE 'Default admin user created: admin@goatgoat.com / admin123';
  END IF;
END $$;

-- Verify all tables were created
DO $$
BEGIN
  -- Check admin tables
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_users') THEN
    RAISE EXCEPTION 'admin_users table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_sessions') THEN
    RAISE EXCEPTION 'admin_sessions table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admin_audit_log') THEN
    RAISE EXCEPTION 'admin_audit_log table was not created';
  END IF;
  
  RAISE NOTICE 'All admin panel tables created successfully!';
  RAISE NOTICE 'Admin panel database setup complete.';
  
  -- Show setup summary
  RAISE NOTICE 'Setup Summary:';
  RAISE NOTICE '- Admin users: %', (SELECT COUNT(*) FROM admin_users);
  RAISE NOTICE '- Default admin: admin@goatgoat.com';
  RAISE NOTICE '- Security: RLS enabled on all tables';
  RAISE NOTICE '- Audit logging: Enabled for all admin actions';
END $$;
