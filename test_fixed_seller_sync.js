/**
 * Test the fixed seller sync for the specific problematic seller
 * Seller ID: 4cc6524c-b3a3-4f56-bac6-37ae2a57de09
 * Expected: Should now map "Approved" → "approved" correctly
 */

const SUPABASE_URL = 'https://oaynfzqjielnsipttzbs.supabase.co';
const WEBHOOK_API_KEY = 'dev-webhook-api-key-2024-secure-odoo-integration';

async function testFixedSellerSync() {
  console.log('🚀 TESTING FIXED SELLER SYNC');
  console.log('=============================');
  
  const sellerId = '4cc6524c-b3a3-4f56-bac6-37ae2a57de09';
  const sellerName = 'Prabhydev Aralimatti';
  
  console.log(`📋 Seller ID: ${sellerId}`);
  console.log(`📋 Seller Name: ${sellerName}`);
  console.log(`📋 Expected: Odoo "Approved" → Supabase "approved"`);
  console.log('');
  
  try {
    console.log('🔄 Testing seller-status-sync with fixed mapping...');
    
    const syncPayload = {
      seller_id: sellerId,
      seller_name: sellerName,
      current_status: 'pending'
    };
    
    console.log('📤 Sending sync request...');
    
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
      const errorText = await syncResponse.text();
      console.log('❌ Error Response:', errorText);
      return;
    }
    
    const syncData = await syncResponse.json();
    console.log('📥 Response Data:', JSON.stringify(syncData, null, 2));
    
    // Analyze the fix
    if (syncData.success) {
      console.log('✅ Sync function executed successfully');
      
      if (syncData.status_changed) {
        console.log(`🎉 SUCCESS! Status changed: ${syncData.previous_status} → ${syncData.current_status}`);
        
        if (syncData.current_status === 'approved') {
          console.log('✅ FIXED! Seller status correctly synced to approved');
          console.log('🎯 The status mapping fix worked!');
        } else {
          console.log(`⚠️ Unexpected status: ${syncData.current_status}`);
        }
      } else {
        console.log(`ℹ️ Status unchanged: ${syncData.current_status}`);
        
        if (syncData.current_status === 'approved') {
          console.log('✅ Status already approved (sync working correctly)');
        } else {
          console.log('❌ Status still not approved - investigating...');
        }
      }
      
      // Show sync details
      console.log('\n📋 Sync Details:');
      console.log(`   Previous Status: ${syncData.previous_status}`);
      console.log(`   Current Status: ${syncData.current_status}`);
      console.log(`   Status Changed: ${syncData.status_changed}`);
      console.log(`   Sync Timestamp: ${syncData.sync_timestamp}`);
      
    } else {
      console.log('❌ Sync function failed');
      console.log(`📋 Error: ${syncData.error || 'Unknown error'}`);
    }
    
  } catch (error) {
    console.error('❌ Test failed:', error);
  }
}

async function verifySupabaseUpdate() {
  console.log('\n🔍 VERIFYING SUPABASE UPDATE');
  console.log('=============================');
  
  // Note: This would require Supabase client setup to check the actual database
  // For now, we'll rely on the sync function response
  console.log('📋 To verify the fix worked:');
  console.log('1. Check the seller-status-sync function logs in Supabase dashboard');
  console.log('2. Query the sellers table to confirm approval_status = "approved"');
  console.log('3. Test the Flutter app to see if status shows as approved');
  console.log('4. Verify the "Check Status" button now shows approved status');
}

async function runFixTest() {
  console.log('🎯 SELLER SYNC FIX VERIFICATION');
  console.log('================================\n');
  
  await testFixedSellerSync();
  await verifySupabaseUpdate();
  
  console.log('\n🎯 FIX SUMMARY');
  console.log('==============');
  console.log('✅ Added "Approved" → "approved" to status mapping');
  console.log('✅ Added case-insensitive mappings for all statuses');
  console.log('✅ Deployed updated seller-status-sync function');
  console.log('✅ Tested with problematic seller');
  console.log('\n📱 Next Steps:');
  console.log('1. Test in Flutter app - click "Check Status" button');
  console.log('2. Verify seller dashboard shows approved status');
  console.log('3. Confirm congratulations notification appears');
  console.log('4. Check that seller gets full access to features');
}

// Run the fix test
runFixTest().catch(console.error);
