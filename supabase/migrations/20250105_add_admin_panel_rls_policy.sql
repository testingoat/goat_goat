-- Migration: Add RLS policy for admin panel operations
-- Created: 2025-01-05
-- Purpose: Allow admin panel (using anonymous key) to perform CRUD operations on delivery_fee_configs
-- 
-- SECURITY NOTE: This is a temporary solution for admin panel functionality.
-- In production, this should be replaced with proper admin authentication using
-- Supabase auth and role-based access control.
--
-- The admin panel currently uses anonymous key for Supabase operations, but has
-- its own authentication layer (AdminAuthService) for access control.

-- Add RLS policy for anonymous users to perform admin operations on delivery_fee_configs
-- This allows the admin panel to create, read, update, and delete delivery fee configurations
CREATE POLICY "Anonymous admin panel access to delivery fee configs"
ON delivery_fee_configs
FOR ALL
TO anon
USING (true)
WITH CHECK (true);

-- Add comment documenting the temporary nature of this policy
COMMENT ON POLICY "Anonymous admin panel access to delivery fee configs" ON delivery_fee_configs IS 
'TEMPORARY: Allows admin panel anonymous access for CRUD operations. Should be replaced with proper admin authentication in production.';

-- Grant necessary permissions to anonymous role for admin operations
GRANT SELECT, INSERT, UPDATE, DELETE ON delivery_fee_configs TO anon;

-- Log the policy creation for audit purposes
DO $$
BEGIN
  RAISE NOTICE 'SUCCESS: Added temporary admin panel RLS policy for delivery_fee_configs';
  RAISE NOTICE 'SECURITY WARNING: This policy allows anonymous access to admin operations';
  RAISE NOTICE 'TODO: Implement proper admin authentication with Supabase auth';
END $$;
