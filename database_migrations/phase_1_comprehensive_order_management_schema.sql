-- ============================================================================
-- COMPREHENSIVE ORDER MANAGEMENT SYSTEM - PHASE 1A DATABASE SCHEMA EXTENSION
-- ============================================================================
-- 
-- This migration extends the existing order management schema to support
-- the comprehensive order management system while maintaining 100% backward
-- compatibility with existing functionality.
--
-- ZERO-RISK IMPLEMENTATION:
-- - All changes are additive only (no modifications to existing columns)
-- - Existing queries will continue to work unchanged
-- - New functionality is behind feature flags
-- - Rollback capability through feature flag disabling
--
-- Date: 2025-08-16
-- Phase: 1A - Database Schema Extension
-- ============================================================================

-- ============================================================================
-- 1. EXTEND EXISTING ORDERS TABLE (ADDITIVE ONLY)
-- ============================================================================

-- Add new columns to existing orders table (preserving all existing functionality)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_number VARCHAR(20);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMPTZ;

-- Financial enhancements (keeping existing total_amount)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS subtotal DECIMAL(10,2);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee DECIMAL(8,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(8,2) DEFAULT 0;

-- Delivery information enhancements
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_address JSONB;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_coordinates POINT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS estimated_delivery_time TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS actual_delivery_time TIMESTAMPTZ;

-- Metadata and audit enhancements
ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_metadata JSONB DEFAULT '{}';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS special_instructions TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_by UUID;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Create order status enum (will coexist with existing order_status TEXT field)
DO $$ BEGIN
    CREATE TYPE order_status_enum AS ENUM (
        'pending',           -- Just placed, waiting for seller acceptance
        'accepted',          -- Seller accepted, preparing order
        'confirmed',         -- Order confirmed, in preparation
        'ready_for_pickup',  -- Ready for delivery pickup
        'out_for_delivery',  -- Being delivered
        'delivered',         -- Successfully delivered
        'cancelled',         -- Cancelled by customer/seller/system
        'expired',           -- Expired due to no acceptance
        'failed'             -- Failed due to system error
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Add new status enum column (keeping existing order_status for backward compatibility)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS status_enum order_status_enum;

-- Create unique constraint on order_number (with conditional creation)
DO $$ BEGIN
    ALTER TABLE orders ADD CONSTRAINT orders_order_number_unique UNIQUE (order_number);
EXCEPTION
    WHEN duplicate_table THEN null;
END $$;

-- ============================================================================
-- 2. EXTEND EXISTING ORDER_ITEMS TABLE (ADDITIVE ONLY)
-- ============================================================================

-- Add enhanced order item fields
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS product_name VARCHAR(255);
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS product_sku VARCHAR(100);
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS product_snapshot JSONB;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS special_requests TEXT;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS weight_preference VARCHAR(50);
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS cut_preference VARCHAR(100);

-- Add quantity constraint (if not exists)
DO $$ BEGIN
    ALTER TABLE order_items ADD CONSTRAINT order_items_quantity_positive CHECK (quantity > 0);
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- 3. CREATE NEW OMS TABLES
-- ============================================================================

-- Order State Transitions Table
CREATE TABLE IF NOT EXISTS order_state_transitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    
    -- State Change Information
    from_status order_status_enum,
    to_status order_status_enum NOT NULL,
    transition_reason VARCHAR(255),
    
    -- Actor Information
    triggered_by_user_id UUID,
    triggered_by_user_type VARCHAR(20), -- 'customer', 'seller', 'system', 'admin'
    
    -- Timing
    transitioned_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Additional Context
    metadata JSONB DEFAULT '{}',
    notes TEXT
);

-- Seller Capacity Management Table
CREATE TABLE IF NOT EXISTS seller_capacity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id UUID REFERENCES sellers(id) UNIQUE,
    
    -- Capacity Metrics
    max_concurrent_orders INTEGER DEFAULT 10,
    current_active_orders INTEGER DEFAULT 0,
    max_daily_orders INTEGER DEFAULT 100,
    current_daily_orders INTEGER DEFAULT 0,
    
    -- Availability Windows
    operating_hours JSONB, -- {"monday": {"open": "09:00", "close": "21:00"}, ...}
    is_currently_available BOOLEAN DEFAULT true,
    availability_status VARCHAR(50) DEFAULT 'available',
    
    -- Performance Metrics
    average_acceptance_time_seconds INTEGER DEFAULT 0,
    acceptance_rate_percentage DECIMAL(5,2) DEFAULT 100.0,
    average_preparation_time_minutes INTEGER DEFAULT 30,
    
    -- Temporary Overrides
    manual_override_until TIMESTAMPTZ,
    override_reason TEXT,
    
    -- Audit
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_capacity_check TIMESTAMPTZ DEFAULT NOW()
);

-- Order Routing Decisions Table
CREATE TABLE IF NOT EXISTS order_routing_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id),
    
    -- Routing Algorithm Results
    algorithm_version VARCHAR(20) NOT NULL,
    primary_seller_id UUID REFERENCES sellers(id),
    fallback_sellers UUID[] DEFAULT '{}',
    
    -- Decision Factors
    routing_factors JSONB, -- Distance, capacity, rating, etc.
    decision_score DECIMAL(8,4),
    
    -- Timing
    routing_completed_at TIMESTAMPTZ DEFAULT NOW(),
    routing_duration_ms INTEGER,
    
    -- Results
    routing_successful BOOLEAN DEFAULT true,
    failure_reason TEXT
);

-- OMS Configuration Table (for admin panel controls)
CREATE TABLE IF NOT EXISTS oms_configuration (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    config_key VARCHAR(100) NOT NULL UNIQUE,
    config_value JSONB NOT NULL,
    config_type VARCHAR(50) NOT NULL, -- 'routing', 'timer', 'capacity', 'notification'
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

-- ============================================================================
-- 4. INSERT DEFAULT OMS CONFIGURATION VALUES
-- ============================================================================

-- Routing Algorithm Configuration
INSERT INTO oms_configuration (config_key, config_value, config_type, description) VALUES
('routing_algorithm_weights', '{
    "distance": 0.25,
    "capacity": 0.20,
    "acceptance_time": 0.15,
    "rating": 0.15,
    "availability": 0.10,
    "delivery_zone": 0.10,
    "performance": 0.05
}', 'routing', 'Weights for seller selection scoring algorithm'),

('routing_max_distance_km', '{"value": 15}', 'routing', 'Maximum distance for seller selection in kilometers'),

('routing_algorithm_version', '{"value": "v1.0"}', 'routing', 'Current version of the routing algorithm'),

-- Timer Configuration
('order_acceptance_timeout_minutes', '{"value": 5}', 'timer', '5-minute order acceptance deadline'),

('order_grace_period_seconds', '{"value": 30}', 'timer', 'Grace period before order expiration'),

('fallback_routing_enabled', '{"value": true}', 'timer', 'Enable automatic fallback routing on expiration'),

-- Capacity Management Configuration
('default_max_concurrent_orders', '{"value": 10}', 'capacity', 'Default maximum concurrent orders per seller'),

('default_max_daily_orders', '{"value": 100}', 'capacity', 'Default maximum daily orders per seller'),

('capacity_check_interval_minutes', '{"value": 5}', 'capacity', 'Interval for capacity status checks'),

-- Notification Configuration
('notification_delivery_methods', '{
    "primary": "fcm",
    "backup": "sms",
    "fallback": "realtime"
}', 'notification', 'Order of notification delivery methods'),

('notification_retry_attempts', '{"value": 3}', 'notification', 'Number of retry attempts for failed notifications'),

('notification_retry_delay_seconds', '{"value": 30}', 'notification', 'Delay between notification retry attempts')

ON CONFLICT (config_key) DO NOTHING;

-- ============================================================================
-- 5. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

-- Orders table indexes
CREATE INDEX IF NOT EXISTS idx_orders_status_enum ON orders(status_enum);
CREATE INDEX IF NOT EXISTS idx_orders_expires_at ON orders(expires_at);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_seller_id ON orders(seller_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);

-- Order state transitions indexes
CREATE INDEX IF NOT EXISTS idx_order_transitions_order_id ON order_state_transitions(order_id);
CREATE INDEX IF NOT EXISTS idx_order_transitions_status ON order_state_transitions(to_status);
CREATE INDEX IF NOT EXISTS idx_order_transitions_time ON order_state_transitions(transitioned_at);

-- Seller capacity indexes
CREATE INDEX IF NOT EXISTS idx_seller_capacity_seller_id ON seller_capacity(seller_id);
CREATE INDEX IF NOT EXISTS idx_seller_capacity_available ON seller_capacity(is_currently_available);
CREATE INDEX IF NOT EXISTS idx_seller_capacity_updated ON seller_capacity(updated_at);

-- Order routing decisions indexes
CREATE INDEX IF NOT EXISTS idx_routing_decisions_order_id ON order_routing_decisions(order_id);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_seller_id ON order_routing_decisions(primary_seller_id);
CREATE INDEX IF NOT EXISTS idx_routing_decisions_time ON order_routing_decisions(routing_completed_at);

-- OMS configuration indexes
CREATE INDEX IF NOT EXISTS idx_oms_config_type ON oms_configuration(config_type);
CREATE INDEX IF NOT EXISTS idx_oms_config_active ON oms_configuration(is_active);

-- ============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on new tables
ALTER TABLE order_state_transitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_capacity ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_routing_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE oms_configuration ENABLE ROW LEVEL SECURITY;

-- Order State Transitions Policies
CREATE POLICY "Users can view order transitions for their orders" ON order_state_transitions
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = order_state_transitions.order_id
        AND (orders.customer_id = auth.uid() OR orders.seller_id IN (
            SELECT id FROM sellers WHERE user_id = auth.uid()
        ))
    )
);

CREATE POLICY "System can manage order transitions" ON order_state_transitions
FOR ALL USING (auth.role() = 'service_role');

-- Seller Capacity Policies
CREATE POLICY "Sellers can view their own capacity" ON seller_capacity
FOR SELECT USING (
    seller_id IN (SELECT id FROM sellers WHERE user_id = auth.uid())
);

CREATE POLICY "System can manage seller capacity" ON seller_capacity
FOR ALL USING (auth.role() = 'service_role');

-- Order Routing Decisions Policies
CREATE POLICY "Users can view routing for their orders" ON order_routing_decisions
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM orders
        WHERE orders.id = order_routing_decisions.order_id
        AND (orders.customer_id = auth.uid() OR orders.seller_id IN (
            SELECT id FROM sellers WHERE user_id = auth.uid()
        ))
    )
);

CREATE POLICY "System can manage routing decisions" ON order_routing_decisions
FOR ALL USING (auth.role() = 'service_role');

-- OMS Configuration Policies
CREATE POLICY "Public can read OMS configuration" ON oms_configuration
FOR SELECT USING (true);

CREATE POLICY "Authenticated users can manage OMS configuration" ON oms_configuration
FOR ALL USING (auth.role() = 'authenticated');

-- ============================================================================
-- 7. ADD NEW FEATURE FLAGS FOR OMS
-- ============================================================================

-- Insert OMS feature flags
INSERT INTO feature_flags (feature_name, enabled, description, target_user_percentage) VALUES
('comprehensive_order_management', false, 'Master flag for comprehensive order management system', 0),
('order_routing_algorithm', false, 'Intelligent seller selection and routing algorithm', 0),
('order_acceptance_timer', false, '5-minute order acceptance timer with expiration', 0),
('seller_capacity_management', false, 'Seller capacity tracking and management', 0),
('order_state_transitions', false, 'Detailed order state transition tracking', 0),
('enhanced_order_notifications', false, 'Enhanced real-time order notifications', 0),
('order_fallback_routing', false, 'Automatic fallback routing on order expiration', 0),
('oms_admin_panel', false, 'Order Management System admin panel controls', 0)
ON CONFLICT (feature_name) DO NOTHING;

-- ============================================================================
-- 8. CREATE FUNCTIONS FOR OMS OPERATIONS
-- ============================================================================

-- Function to update order status with transition logging
CREATE OR REPLACE FUNCTION update_order_status_with_transition(
    p_order_id UUID,
    p_new_status order_status_enum,
    p_triggered_by UUID DEFAULT NULL,
    p_user_type VARCHAR(20) DEFAULT 'system',
    p_reason VARCHAR(255) DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_old_status order_status_enum;
BEGIN
    -- Get current status
    SELECT status_enum INTO v_old_status FROM orders WHERE id = p_order_id;

    -- Update order status
    UPDATE orders
    SET status_enum = p_new_status,
        updated_at = NOW()
    WHERE id = p_order_id;

    -- Log the transition
    INSERT INTO order_state_transitions (
        order_id,
        from_status,
        to_status,
        transition_reason,
        triggered_by_user_id,
        triggered_by_user_type,
        notes
    ) VALUES (
        p_order_id,
        v_old_status,
        p_new_status,
        p_reason,
        p_triggered_by,
        p_user_type,
        p_notes
    );

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to initialize seller capacity
CREATE OR REPLACE FUNCTION initialize_seller_capacity(p_seller_id UUID) RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO seller_capacity (seller_id)
    VALUES (p_seller_id)
    ON CONFLICT (seller_id) DO NOTHING;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Log migration completion
DO $$
BEGIN
    RAISE NOTICE 'Comprehensive Order Management System Phase 1A migration completed successfully';
    RAISE NOTICE 'All changes are backward compatible and existing functionality is preserved';
    RAISE NOTICE 'New features are controlled by feature flags and disabled by default';
END $$;
