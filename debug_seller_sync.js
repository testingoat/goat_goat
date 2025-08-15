/**
 * Debug script for specific seller sync issue
 * Seller ID: 4cc6524c-b3a3-4f56-bac6-37ae2a57de09
 * Odoo ID: 22
 * Issue: Status not syncing from Odoo "Approved" to Supabase "approved"
 */

const SUPABASE_URL = 'https://oaynfzqjielnsipttzbs.supabase.co';
const WEBHOOK_API_KEY = 'dev-webhook-api-key-2024-secure-odoo-integration';

async function debugSpecificSeller() {
  console.log('🔍 DEBUGGING SELLER SYNC ISSUE');
  console.log('================================');
  
  const problemSellerId = '4cc6524c-b3a3-4f56-bac6-37ae2a57de09';
  const sellerName = 'Prabhydev Aralimatti';
  const odooSellerId = 22;
  
  console.log(`📋 Seller ID: ${problemSellerId}`);
  console.log(`📋 Seller Name: ${sellerName}`);
  console.log(`📋 Odoo ID: ${odooSellerId}`);
  console.log(`📋 Expected Odoo Status: "Approved"`);
  console.log(`📋 Expected Supabase Status: "approved"`);
  console.log('');
  
  try {
    console.log('🔄 Step 1: Testing seller-status-sync function...');
    
    const syncPayload = {
      seller_id: problemSellerId,
      seller_name: sellerName,
      current_status: 'pending'
    };
    
    console.log('📤 Sending sync request...');
    console.log('📋 Payload:', JSON.stringify(syncPayload, null, 2));
    
    const syncResponse = await fetch(`${SUPABASE_URL}/functions/v1/seller-status-sync`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': WEBHOOK_API_KEY
      },
      body: JSON.stringify(syncPayload)
    });
    
    console.log(`📥 Response Status: ${syncResponse.status}`);
    
    if (syncResponse.status !== 200) {
      console.log('❌ Non-200 response - checking error details...');
      const errorText = await syncResponse.text();
      console.log('📋 Error Response:', errorText);
      return;
    }
    
    const syncData = await syncResponse.json();
    console.log('📥 Response Data:', JSON.stringify(syncData, null, 2));
    
    // Analyze the response
    if (syncData.success) {
      console.log('✅ Sync function executed successfully');
      
      if (syncData.status_changed) {
        console.log(`🔄 Status changed: ${syncData.previous_status} → ${syncData.current_status}`);
        console.log('✅ SYNC WORKING - Status was updated!');
      } else {
        console.log(`ℹ️ Status unchanged: ${syncData.current_status}`);
        
        if (syncData.current_status === 'pending') {
          console.log('❌ ISSUE FOUND: Odoo still shows pending status');
          console.log('🔍 Possible causes:');
          console.log('   1. Odoo status field name mismatch');
          console.log('   2. Status mapping issue in sync function');
          console.log('   3. Odoo search not finding the correct record');
        } else if (syncData.current_status === 'approved') {
          console.log('❌ ISSUE FOUND: Sync detected approved status but Supabase not updated');
          console.log('🔍 Possible causes:');
          console.log('   1. Database update failed');
          console.log('   2. Permission issue with Supabase update');
          console.log('   3. Transaction rollback');
        }
      }
    } else {
      console.log('❌ Sync function failed');
      console.log(`📋 Error: ${syncData.error || 'Unknown error'}`);
    }
    
  } catch (error) {
    console.error('❌ Debug test failed:', error);
  }
}

async function testOdooDirectly() {
  console.log('\n🔄 Step 2: Testing Odoo API directly...');
  console.log('=====================================');
  
  try {
    // Test Odoo authentication
    console.log('🔐 Testing Odoo authentication...');
    
    const authPayload = {
      jsonrpc: '2.0',
      method: 'call',
      params: {
        db: 'staging',
        login: 'admin',
        password: 'admin'
      },
      id: Math.random()
    };
    
    const authResponse = await fetch('https://goatgoat.xyz/web/session/authenticate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(authPayload)
    });
    
    console.log(`📥 Auth Status: ${authResponse.status}`);
    const authData = await authResponse.json();
    
    if (!authData?.result?.uid) {
      console.log('❌ Odoo authentication failed');
      console.log('📋 Auth Response:', JSON.stringify(authData, null, 2));
      return;
    }
    
    console.log('✅ Odoo authentication successful');
    console.log(`📋 User ID: ${authData.result.uid}`);
    
    const sessionCookie = authResponse.headers.get('set-cookie') || '';
    console.log(`📋 Session Cookie: ${sessionCookie ? 'Present' : 'Missing'}`);
    
    // Test search for specific seller
    console.log('\n🔍 Searching for seller in Odoo...');
    
    const searchPayload = {
      jsonrpc: '2.0',
      method: 'call',
      params: {
        model: 'res.partner',
        method: 'search_read',
        args: [],
        kwargs: {
          domain: [['ref', '=', '4cc6524c-b3a3-4f56-bac6-37ae2a57de09']],
          fields: ['id', 'name', 'state', 'ref', 'supplier_rank'],
          limit: 1
        }
      },
      id: Math.random()
    };
    
    const searchResponse = await fetch('https://goatgoat.xyz/web/dataset/call_kw', {
      method: 'POST',
      headers: { 
        'Content-Type': 'application/json',
        'Cookie': sessionCookie
      },
      body: JSON.stringify(searchPayload)
    });
    
    console.log(`📥 Search Status: ${searchResponse.status}`);
    const searchData = await searchResponse.json();
    
    console.log('📋 Search Response:', JSON.stringify(searchData, null, 2));
    
    if (searchData?.result && Array.isArray(searchData.result) && searchData.result.length > 0) {
      const seller = searchData.result[0];
      console.log('✅ Seller found in Odoo:');
      console.log(`   📋 Odoo ID: ${seller.id}`);
      console.log(`   📋 Name: ${seller.name}`);
      console.log(`   📋 State: ${seller.state}`);
      console.log(`   📋 Ref: ${seller.ref}`);
      console.log(`   📋 Supplier Rank: ${seller.supplier_rank}`);
      
      // Check status mapping
      console.log('\n🔍 Status Mapping Analysis:');
      console.log(`   📋 Odoo State: "${seller.state}"`);
      
      const statusMapping = {
        'Pending for Approval': 'pending',
        'approved': 'approved',
        'rejected': 'rejected',
        'draft': 'pending',
        'done': 'approved'
      };
      
      const mappedStatus = statusMapping[seller.state] || 'pending';
      console.log(`   📋 Mapped Status: "${mappedStatus}"`);
      
      if (seller.state === 'Approved' && mappedStatus === 'pending') {
        console.log('❌ ISSUE FOUND: Status mapping missing for "Approved"');
        console.log('🔧 SOLUTION: Add "Approved": "approved" to status mapping');
      } else if (mappedStatus === 'approved') {
        console.log('✅ Status mapping correct - should sync to approved');
      }
      
    } else {
      console.log('❌ Seller not found in Odoo');
      console.log('🔍 Possible causes:');
      console.log('   1. Seller ref UUID mismatch');
      console.log('   2. Seller not properly created in Odoo');
      console.log('   3. Database connection issue');
    }
    
  } catch (error) {
    console.error('❌ Odoo direct test failed:', error);
  }
}

async function runCompleteDebug() {
  console.log('🚀 COMPLETE SELLER SYNC DEBUG');
  console.log('==============================\n');
  
  await debugSpecificSeller();
  await testOdooDirectly();
  
  console.log('\n🎯 DEBUG SUMMARY');
  console.log('================');
  console.log('✅ Tested seller-status-sync function');
  console.log('✅ Tested Odoo API directly');
  console.log('✅ Analyzed status mapping');
  console.log('\n📋 Next Steps:');
  console.log('1. Check function logs in Supabase dashboard');
  console.log('2. Verify status mapping includes "Approved" → "approved"');
  console.log('3. Test database update permissions');
  console.log('4. Verify seller exists with correct ref in Odoo');
}

// Run the complete debug
runCompleteDebug().catch(console.error);
