-- Migration: Create delivery_fee_configs table for admin-managed delivery rates
-- Phase C.4 - Distance-based Delivery Fees - Phase 1 (Foundation)
-- Created: 2025-01-04
-- Purpose: Enable real-time admin control over delivery fee calculations

-- Create delivery_fee_configs table with enhanced scope-based architecture
CREATE TABLE delivery_fee_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Scope-based targeting (improved approach)
  scope TEXT NOT NULL, -- 'GLOBAL' | 'CITY:BLR' | 'ZONE:BLR-Z23'
  config_name TEXT NOT NULL DEFAULT 'default',
  is_active BOOLEAN NOT NULL DEFAULT true,
  
  -- Distance calculation settings
  use_routing BOOLEAN NOT NULL DEFAULT true, -- Use Google Distance Matrix vs straight-line
  calibration_multiplier NUMERIC(3,2) NOT NULL DEFAULT 1.3, -- Multiply straight-line distance
  
  -- Tier-based pricing structure (JSONB for flexibility)
  tier_rates JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- Example structure:
  -- [
  --   {"min_km": 0, "max_km": 3, "fee": 19},
  --   {"min_km": 3, "max_km": 6, "fee": 29},
  --   {"min_km": 6, "max_km": 9, "fee": 39},
  --   {"min_km": 9, "max_km": 12, "fee": 49},
  --   {"min_km": 12, "max_km": null, "base_fee": 59, "per_km_fee": 5}
  -- ]
  
  -- Dynamic pricing multipliers (JSONB for flexibility)
  dynamic_multipliers JSONB NOT NULL DEFAULT '{}'::jsonb,
  -- Example structure:
  -- {
  --   "peak_hours": {
  --     "enabled": false,
  --     "start_time": "18:00",
  --     "end_time": "22:00",
  --     "multiplier": 1.1,
  --     "days": ["monday", "tuesday", "wednesday", "thursday", "friday"]
  --   },
  --   "weather": {
  --     "enabled": false,
  --     "rain_threshold_mm": 2,
  --     "multiplier": 1.1
  --   },
  --   "demand": {
  --     "enabled": false,
  --     "low_supply_threshold": 0.7,
  --     "multiplier": 1.1
  --   }
  -- }
  
  -- Fee limits and thresholds
  min_fee NUMERIC(8,2) NOT NULL DEFAULT 15.00,
  max_fee NUMERIC(8,2) NOT NULL DEFAULT 99.00,
  free_delivery_threshold NUMERIC(8,2) DEFAULT 500.00,
  max_serviceable_distance_km NUMERIC(5,2) NOT NULL DEFAULT 15.00,
  
  -- Versioning and concurrency control
  version INTEGER NOT NULL DEFAULT 1,
  last_modified_by UUID REFERENCES auth.users(id),
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Constraints for data integrity
  CONSTRAINT unique_active_per_scope UNIQUE (scope) WHERE (is_active = true),
  CONSTRAINT valid_tier_rates CHECK (jsonb_typeof(tier_rates) = 'array'),
  CONSTRAINT valid_multipliers CHECK (jsonb_typeof(dynamic_multipliers) = 'object'),
  CONSTRAINT valid_fees CHECK (min_fee >= 0 AND max_fee >= min_fee),
  CONSTRAINT valid_distance CHECK (max_serviceable_distance_km > 0),
  CONSTRAINT valid_calibration CHECK (calibration_multiplier > 0)
);

-- Create indexes for performance
CREATE INDEX idx_delivery_fee_configs_scope ON delivery_fee_configs(scope);
CREATE INDEX idx_delivery_fee_configs_active ON delivery_fee_configs(is_active) WHERE is_active = true;
CREATE INDEX idx_delivery_fee_configs_updated ON delivery_fee_configs(updated_at DESC);

-- Create function to automatically update updated_at and version
CREATE OR REPLACE FUNCTION update_delivery_fee_configs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic timestamp and version updates
CREATE TRIGGER trigger_delivery_fee_configs_updated_at
  BEFORE UPDATE ON delivery_fee_configs
  FOR EACH ROW
  EXECUTE FUNCTION update_delivery_fee_configs_updated_at();

-- Insert default GLOBAL configuration with standard tier rates
INSERT INTO delivery_fee_configs (
  scope,
  config_name,
  tier_rates,
  dynamic_multipliers,
  min_fee,
  max_fee,
  free_delivery_threshold,
  max_serviceable_distance_km,
  use_routing,
  calibration_multiplier
) VALUES (
  'GLOBAL',
  'default_rates',
  '[
    {"min_km": 0, "max_km": 3, "fee": 19},
    {"min_km": 3, "max_km": 6, "fee": 29},
    {"min_km": 6, "max_km": 9, "fee": 39},
    {"min_km": 9, "max_km": 12, "fee": 49},
    {"min_km": 12, "max_km": null, "base_fee": 59, "per_km_fee": 5}
  ]'::jsonb,
  '{
    "peak_hours": {
      "enabled": false,
      "start_time": "18:00",
      "end_time": "22:00",
      "multiplier": 1.1,
      "days": ["monday", "tuesday", "wednesday", "thursday", "friday"]
    },
    "weather": {
      "enabled": false,
      "rain_threshold_mm": 2,
      "multiplier": 1.1
    },
    "demand": {
      "enabled": false,
      "low_supply_threshold": 0.7,
      "multiplier": 1.1
    }
  }'::jsonb,
  15.00,
  99.00,
  500.00,
  15.00,
  true,
  1.3
);

-- Enable Row Level Security (RLS)
ALTER TABLE delivery_fee_configs ENABLE ROW LEVEL SECURITY;

-- Create RLS policy: Admin users can perform all operations
CREATE POLICY "Admin full access to delivery fee configs"
ON delivery_fee_configs
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM user_roles 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
  )
);

-- Create RLS policy: Regular users can only read active configs (for the service)
CREATE POLICY "Users can read active delivery fee configs"
ON delivery_fee_configs
FOR SELECT
TO authenticated
USING (is_active = true);

-- Create RLS policy: Service role has full access (for admin service operations)
CREATE POLICY "Service role full access"
ON delivery_fee_configs
FOR ALL
TO service_role
USING (true);

-- Grant appropriate permissions
GRANT SELECT ON delivery_fee_configs TO authenticated;
GRANT ALL ON delivery_fee_configs TO service_role;

-- Create comment for documentation
COMMENT ON TABLE delivery_fee_configs IS 'Admin-managed delivery fee configurations with real-time updates. Supports scope-based targeting (GLOBAL/CITY/ZONE) and dynamic pricing multipliers.';

-- Create comments for key columns
COMMENT ON COLUMN delivery_fee_configs.scope IS 'Targeting scope: GLOBAL, CITY:BLR, ZONE:BLR-Z23';
COMMENT ON COLUMN delivery_fee_configs.tier_rates IS 'JSONB array of distance-based fee tiers';
COMMENT ON COLUMN delivery_fee_configs.dynamic_multipliers IS 'JSONB object with peak hours, weather, and demand multipliers';
COMMENT ON COLUMN delivery_fee_configs.version IS 'Version number for optimistic locking and conflict resolution';

-- Verify the migration by selecting the default configuration
-- This will be visible in migration logs
DO $$
DECLARE
  config_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO config_count FROM delivery_fee_configs WHERE scope = 'GLOBAL';
  
  IF config_count = 1 THEN
    RAISE NOTICE 'SUCCESS: Default GLOBAL delivery fee configuration created successfully';
  ELSE
    RAISE EXCEPTION 'ERROR: Failed to create default configuration. Count: %', config_count;
  END IF;
END $$;
