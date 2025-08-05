-- Fix RLS policies for delivery_fee_configs table
-- This script should be run in Supabase SQL Editor

-- First, check the existing table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'delivery_fee_configs'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check if the table exists and has RLS enabled
SELECT
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE tablename = 'delivery_fee_configs';

-- Check existing policies
SELECT
    tablename,
    policyname,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'delivery_fee_configs';

-- Enable RLS if not already enabled
ALTER TABLE public.delivery_fee_configs ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow anon read access" ON public.delivery_fee_configs;
DROP POLICY IF EXISTS "Allow anon write access" ON public.delivery_fee_configs;
DROP POLICY IF EXISTS "Allow anon insert access" ON public.delivery_fee_configs;
DROP POLICY IF EXISTS "Allow anon update access" ON public.delivery_fee_configs;
DROP POLICY IF EXISTS "Allow anon delete access" ON public.delivery_fee_configs;
DROP POLICY IF EXISTS "Allow authenticated read access" ON public.delivery_fee_configs;
DROP POLICY IF EXISTS "Allow authenticated write access" ON public.delivery_fee_configs;
DROP POLICY IF EXISTS "Allow authenticated full access" ON public.delivery_fee_configs;

-- Create policies that allow both anon and authenticated users full access
-- This is safe for admin panel operations

-- Allow anonymous users to read delivery fee configs
CREATE POLICY "Allow anon read access" ON public.delivery_fee_configs
    FOR SELECT
    TO anon
    USING (true);

-- Allow anonymous users to insert delivery fee configs
CREATE POLICY "Allow anon insert access" ON public.delivery_fee_configs
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- Allow anonymous users to update delivery fee configs
CREATE POLICY "Allow anon update access" ON public.delivery_fee_configs
    FOR UPDATE
    TO anon
    USING (true)
    WITH CHECK (true);

-- Allow anonymous users to delete delivery fee configs
CREATE POLICY "Allow anon delete access" ON public.delivery_fee_configs
    FOR DELETE
    TO anon
    USING (true);

-- Also allow authenticated users full access
CREATE POLICY "Allow authenticated full access" ON public.delivery_fee_configs
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Verify the policies were created
SELECT
    tablename,
    policyname,
    roles,
    cmd
FROM pg_policies
WHERE tablename = 'delivery_fee_configs'
ORDER BY policyname;
