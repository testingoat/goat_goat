// Batch Odoo Status Sync - High Performance Bulk Product Status Synchronization
// Optimized for speed: single authentication, bulk processing, parallel operations

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-api-key',
};

// High-performance batch product status check in Odoo
async function batchCheckProductStatusInOdoo(products: Array<{id: string, name: string, odoo_product_id?: number}>) {
  console.log(`🚀 BATCH ODOO CHECK - Processing ${products.length} products`);
  
  try {
    // Odoo credentials
    const odooUrl = "https://goatgoat.xyz/";
    const odooDb = "staging";
    const odooUsername = "admin";
    const odooPassword = "admin";

    console.log(`🔐 BATCH ODOO CHECK - Authenticating once for all products...`);
    
    // Single authentication for all products
    const authResponse = await fetch(`${odooUrl}/web/session/authenticate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'call',
        params: { db: odooDb, login: odooUsername, password: odooPassword },
        id: Math.random(),
      }),
    });

    if (!authResponse.ok) {
      throw new Error(`Authentication failed: ${authResponse.status}`);
    }

    const authData = await authResponse.json();
    if (!authData?.result?.uid) {
      throw new Error(`Authentication failed: ${JSON.stringify(authData)}`);
    }

    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`✅ BATCH ODOO CHECK - Authenticated successfully`);

    // Prepare batch search - group by search strategy
    const productsWithId = products.filter(p => p.odoo_product_id);
    const productsWithoutId = products.filter(p => !p.odoo_product_id);
    
    const results: Array<{
      product_id: string;
      product_name: string;
      odoo_status: string;
      odoo_state?: string;
      found: boolean;
      error?: string;
    }> = [];

    // Batch 1: Search by IDs (most efficient)
    if (productsWithId.length > 0) {
      console.log(`🔍 BATCH ODOO CHECK - Searching ${productsWithId.length} products by ID`);
      
      const ids = productsWithId.map(p => p.odoo_product_id);
      const searchResponse = await fetch(`${odooUrl}/web/dataset/call_kw`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
        body: JSON.stringify({
          jsonrpc: '2.0',
          method: 'call',
          params: {
            model: 'product.template',
            method: 'search_read',
            args: [
              [['id', 'in', ids]],
              ['id', 'name', 'state', 'active']
            ],
            kwargs: {},
          },
          id: Math.random(),
        }),
      });

      if (searchResponse.ok) {
        const searchData = await searchResponse.json();
        const odooProducts = searchData?.result || [];
        
        // Map results back to our products
        for (const product of productsWithId) {
          const odooProduct = odooProducts.find((op: any) => op.id === product.odoo_product_id);
          
          if (odooProduct) {
            let approvalStatus = 'pending';
            if (odooProduct.state === 'approved') {
              approvalStatus = 'approved';
            } else if (odooProduct.state === 'rejected') {
              approvalStatus = 'rejected';
            }
            
            results.push({
              product_id: product.id,
              product_name: product.name,
              odoo_status: approvalStatus,
              odoo_state: odooProduct.state,
              found: true,
            });
          } else {
            results.push({
              product_id: product.id,
              product_name: product.name,
              odoo_status: 'pending',
              found: false,
              error: 'Product not found in Odoo by ID',
            });
          }
        }
      }
    }

    // Batch 2: Search by exact names (fallback for products without ID)
    if (productsWithoutId.length > 0) {
      console.log(`🔍 BATCH ODOO CHECK - Searching ${productsWithoutId.length} products by name`);
      
      // Process names in smaller batches to avoid query size limits
      const nameSearchBatchSize = 10;
      for (let i = 0; i < productsWithoutId.length; i += nameSearchBatchSize) {
        const batch = productsWithoutId.slice(i, i + nameSearchBatchSize);
        const names = batch.map(p => p.name);
        
        const searchResponse = await fetch(`${odooUrl}/web/dataset/call_kw`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Cookie': sessionCookie },
          body: JSON.stringify({
            jsonrpc: '2.0',
            method: 'call',
            params: {
              model: 'product.template',
              method: 'search_read',
              args: [
                [['name', 'in', names]],
                ['id', 'name', 'state', 'active']
              ],
              kwargs: {},
            },
            id: Math.random(),
          }),
        });

        if (searchResponse.ok) {
          const searchData = await searchResponse.json();
          const odooProducts = searchData?.result || [];
          
          for (const product of batch) {
            const odooProduct = odooProducts.find((op: any) => op.name === product.name);
            
            if (odooProduct) {
              let approvalStatus = 'pending';
              if (odooProduct.state === 'approved') {
                approvalStatus = 'approved';
              } else if (odooProduct.state === 'rejected') {
                approvalStatus = 'rejected';
              }
              
              results.push({
                product_id: product.id,
                product_name: product.name,
                odoo_status: approvalStatus,
                odoo_state: odooProduct.state,
                found: true,
              });
            } else {
              results.push({
                product_id: product.id,
                product_name: product.name,
                odoo_status: 'pending',
                found: false,
                error: 'Product not found in Odoo by name',
              });
            }
          }
        }
      }
    }

    console.log(`✅ BATCH ODOO CHECK - Completed: ${results.length} products processed`);
    return { success: true, results };

  } catch (error) {
    console.error(`❌ BATCH ODOO CHECK - Error: ${error.message}`);
    return { success: false, error: error.message, results: [] };
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log(`🚀 BATCH ODOO SYNC - Webhook called with method: ${req.method}`);
    
    // API Key authentication
    const apiKey = req.headers.get("x-api-key");
    const expectedApiKey = Deno.env.get("WEBHOOK_API_KEY");
    
    if (!apiKey || apiKey !== expectedApiKey) {
      console.log(`❌ BATCH ODOO SYNC - Unauthorized`);
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 401
      });
    }

    const payload = await req.json();
    console.log(`📥 BATCH ODOO SYNC - Processing ${payload.products?.length || 0} products`);

    if (!payload.products || !Array.isArray(payload.products)) {
      return new Response(JSON.stringify({ 
        error: "Invalid payload: products array required" 
      }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400
      });
    }

    // Batch check product statuses in Odoo
    const batchResult = await batchCheckProductStatusInOdoo(payload.products);
    
    if (!batchResult.success) {
      throw new Error(batchResult.error);
    }

    // Prepare bulk database updates
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const updates: Array<{
      id: string;
      approval_status: string;
      approved_at?: string;
      updated_at: string;
    }> = [];

    const statusChanges: Array<{
      product_id: string;
      product_name: string;
      old_status: string;
      new_status: string;
    }> = [];

    // Process results and prepare updates
    for (const result of batchResult.results) {
      if (result.found && payload.current_statuses) {
        const currentStatus = payload.current_statuses[result.product_id];
        
        if (currentStatus && result.odoo_status !== currentStatus) {
          updates.push({
            id: result.product_id,
            approval_status: result.odoo_status,
            approved_at: result.odoo_status === 'approved' ? new Date().toISOString() : undefined,
            updated_at: new Date().toISOString(),
          });

          statusChanges.push({
            product_id: result.product_id,
            product_name: result.product_name,
            old_status: currentStatus,
            new_status: result.odoo_status,
          });
        }
      }
    }

    // Bulk update database if there are changes
    if (updates.length > 0) {
      console.log(`💾 BATCH ODOO SYNC - Bulk updating ${updates.length} products`);
      
      // Use upsert for bulk updates
      const { error: updateError } = await supabase
        .from('meat_products')
        .upsert(updates, { onConflict: 'id' });

      if (updateError) {
        throw new Error(`Database update failed: ${updateError.message}`);
      }
    }

    console.log(`✅ BATCH ODOO SYNC - Completed successfully: ${statusChanges.length} status changes`);

    return new Response(JSON.stringify({
      success: true,
      message: `Batch sync completed successfully`,
      total_products: payload.products.length,
      products_found: batchResult.results.filter(r => r.found).length,
      status_changes: statusChanges.length,
      changes: statusChanges,
      processing_time_ms: Date.now() - (payload.start_time || Date.now()),
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200
    });

  } catch (error) {
    console.error(`❌ BATCH ODOO SYNC - Error: ${error.message}`);
    return new Response(JSON.stringify({
      error: error.message,
      success: false
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500
    });
  }
});
