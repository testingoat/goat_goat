// Test script to verify Odoo sync is working
const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://oaynfzqjielnsipttzbs.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MTY5NzU5NzQsImV4cCI6MjAzMjU1MTk3NH0.Ej6TuCAWvQSxIrke0Z2zdJOaOqKkJbmqaOLdJGhBOQs';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testOdooSync() {
  console.log('🧪 Testing Odoo sync functionality...');
  
  try {
    // First, get a recent product that has NULL odoo_product_id
    const { data: products, error: queryError } = await supabase
      .from('meat_products')
      .select('*')
      .is('odoo_product_id', null)
      .eq('approval_status', 'pending')
      .order('created_at', { ascending: false })
      .limit(1);

    if (queryError) {
      console.error('❌ Error querying products:', queryError);
      return;
    }

    if (!products || products.length === 0) {
      console.log('ℹ️ No products with NULL odoo_product_id found');
      return;
    }

    const product = products[0];
    console.log('📦 Found product to test:', {
      id: product.id,
      name: product.name,
      odoo_product_id: product.odoo_product_id
    });

    // Test the webhook with this product
    const webhookPayload = {
      product_id: product.id,
      seller_id: product.seller_id,
      product_type: 'meat',
      approval_status: 'pending',
      updated_at: new Date().toISOString(),
      product_data: {
        name: product.name,
        list_price: product.price,
        seller_id: 'Test Seller', // This should be the seller name
        seller_uid: product.seller_id,
        default_code: `GOAT_${Date.now()}`,
        product_type: 'meat',
        state: 'pending',
        description: product.description || 'Test product'
      }
    };

    console.log('🔗 Calling product-sync-webhook...');
    const { data, error } = await supabase.functions.invoke('product-sync-webhook', {
      body: webhookPayload,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': 'goat-goat-webhook-2024-secure-key-v2'
      }
    });

    if (error) {
      console.error('❌ Webhook error:', error);
      return;
    }

    console.log('✅ Webhook response:', data);

    // Check if the product was updated with odoo_product_id
    const { data: updatedProduct, error: updateError } = await supabase
      .from('meat_products')
      .select('odoo_product_id')
      .eq('id', product.id)
      .single();

    if (updateError) {
      console.error('❌ Error checking updated product:', updateError);
      return;
    }

    console.log('📊 Updated product odoo_product_id:', updatedProduct.odoo_product_id);
    
    if (updatedProduct.odoo_product_id) {
      console.log('🎉 SUCCESS: Product now has odoo_product_id!');
    } else {
      console.log('❌ FAILED: Product still has NULL odoo_product_id');
    }

  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

testOdooSync();
