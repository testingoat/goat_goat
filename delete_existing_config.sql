-- Delete existing delivery fee configuration
-- This will allow you to create a new one in the admin panel

-- First, let's see what exists (for confirmation)
SELECT * FROM public.delivery_fee_configs;

-- Delete all existing configurations
-- WARNING: This will remove all delivery fee configurations
DELETE FROM public.delivery_fee_configs;

-- Verify deletion
SELECT COUNT(*) as remaining_configs FROM public.delivery_fee_configs;
