-- Add odoo_seller_id field to sellers table for Odoo integration
-- This field links Supabase sellers to Odoo res.partner records

-- Add the column
ALTER TABLE sellers ADD COLUMN IF NOT EXISTS odoo_seller_id INTEGER;

-- Add index for efficient lookups
CREATE INDEX IF NOT EXISTS idx_sellers_odoo_id ON sellers(odoo_seller_id);

-- Add comment for documentation
COMMENT ON COLUMN sellers.odoo_seller_id IS 'Links to Odoo res.partner ID for seller approval workflow';

-- Update RLS policies to include the new field (if needed)
-- Note: Existing RLS policies should automatically include this field
