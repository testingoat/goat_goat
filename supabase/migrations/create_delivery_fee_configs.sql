-- Create delivery_fee_configs table for admin-managed delivery rates
-- This table stores all delivery fee configuration that admins can modify in real-time

CREATE TABLE delivery_fee_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Configuration identification
  config_name VARCHAR(100) NOT NULL DEFAULT 'default',
  city_code VARCHAR(10) DEFAULT 'ALL', -- 'BLR', 'DEL', 'MUM', 'ALL'
  is_active BOOLEAN DEFAULT true,
  
  -- Distance calculation settings
  use_routing BOOLEAN DEFAULT true, -- Use Google Distance Matrix vs straight-line
  calibration_multiplier DECIMAL(3,2) DEFAULT 1.3, -- Multiply straight-line distance
  
  -- Tier-based pricing structure
  tier_rates JSONB NOT NULL DEFAULT '[]'::jsonb,
  -- Example: [
  --   {"min_km": 0, "max_km": 3, "fee": 19},
  --   {"min_km": 3, "max_km": 6, "fee": 29},
  --   {"min_km": 6, "max_km": 9, "fee": 39},
  --   {"min_km": 9, "max_km": 12, "fee": 49},
  --   {"min_km": 12, "max_km": null, "base_fee": 59, "per_km_fee": 5}
  -- ]
  
  -- Dynamic pricing multipliers
  dynamic_multipliers JSONB DEFAULT '{}'::jsonb,
  -- Example: {
  --   "peak_hours": {
  --     "enabled": true,
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
  min_fee DECIMAL(8,2) DEFAULT 15.00,
  max_fee DECIMAL(8,2) DEFAULT 99.00,
  free_delivery_threshold DECIMAL(8,2) DEFAULT 500.00,
  max_serviceable_distance_km DECIMAL(5,2) DEFAULT 15.00,
  
  -- Versioning and concurrency control
  version INTEGER DEFAULT 1,
  last_modified_by UUID REFERENCES auth.users(id),
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_tier_rates CHECK (jsonb_typeof(tier_rates) = 'array'),
  CONSTRAINT valid_multipliers CHECK (jsonb_typeof(dynamic_multipliers) = 'object'),
  CONSTRAINT valid_fees CHECK (min_fee >= 0 AND max_fee >= min_fee),
  CONSTRAINT valid_distance CHECK (max_serviceable_distance_km > 0)
);

-- Create indexes for performance
CREATE INDEX idx_delivery_fee_configs_active ON delivery_fee_configs(is_active);
CREATE INDEX idx_delivery_fee_configs_city ON delivery_fee_configs(city_code);
CREATE INDEX idx_delivery_fee_configs_updated ON delivery_fee_configs(updated_at DESC);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_delivery_fee_configs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  NEW.version = OLD.version + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_delivery_fee_configs_updated_at
  BEFORE UPDATE ON delivery_fee_configs
  FOR EACH ROW
  EXECUTE FUNCTION update_delivery_fee_configs_updated_at();

-- Insert default configuration
INSERT INTO delivery_fee_configs (
  config_name,
  city_code,
  tier_rates,
  dynamic_multipliers,
  min_fee,
  max_fee,
  free_delivery_threshold,
  max_serviceable_distance_km
) VALUES (
  'default_rates',
  'ALL',
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
  15.00
);

-- Row Level Security (RLS) policies
ALTER TABLE delivery_fee_configs ENABLE ROW LEVEL SECURITY;

-- Admin users can read/write all configs
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

-- Regular users can only read active configs (for the service)
CREATE POLICY "Users can read active delivery fee configs"
ON delivery_fee_configs
FOR SELECT
TO authenticated
USING (is_active = true);

-- Grant permissions
GRANT SELECT ON delivery_fee_configs TO authenticated;
GRANT ALL ON delivery_fee_configs TO service_role;
