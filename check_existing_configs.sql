-- First, let's see what columns actually exist in the table
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'delivery_fee_configs'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Then check all existing delivery fee configurations
SELECT *
FROM public.delivery_fee_configs
ORDER BY created_at DESC;

-- Count total configurations
SELECT COUNT(*) as total_configs
FROM public.delivery_fee_configs;
