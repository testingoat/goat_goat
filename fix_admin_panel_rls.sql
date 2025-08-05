-- URGENT FIX: Admin Panel RLS Policy for delivery_fee_configs
-- Run this SQL in Supabase Dashboard > SQL Editor to fix the admin panel access issue
--
-- This fixes the error: "new row violates row-level security policy for table 'delivery_fee_configs'"

-- Add RLS policy for anonymous users (admin panel) to perform operations on delivery_fee_configs
CREATE POLICY "Anonymous admin panel access to delivery fee configs"
ON delivery_fee_configs
FOR ALL
TO anon
USING (true)
WITH CHECK (true);

-- Grant necessary permissions to anonymous role
GRANT SELECT, INSERT, UPDATE, DELETE ON delivery_fee_configs TO anon;

-- Verify the policy was created
SELECT 
    schemaname,
    tablename,
    policyname,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'delivery_fee_configs'
ORDER BY policyname;
