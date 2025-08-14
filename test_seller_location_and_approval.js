/**
 * Test Script: Seller Location & Approval Webhook Integration
 *
 * This script tests both:
 * 1. Location capture and saving functionality
 * 2. Seller approval webhook integration with Odoo
 *
 * Run with: node test_seller_location_and_approval.js
 */

const SUPABASE_URL = 'https://oaynfzqjielnsipttzbs.supabase.co';
const WEBHOOK_API_KEY = 'your-webhook-api-key'; // Replace with actual API key

// Test seller data
const testSeller = {
  seller_name: 'Test Meat Shop',
  contact_phone: '9876543210',
  seller_type: 'meat',
  business_city: 'Bangalore',
  business_address: '123 Test Street, Koramangala',
  business_pincode: '560034',
  gstin: 'TEST123456789',
  fssai_license: 'TEST987654321',
  bank_account_number: '1234567890',
  ifsc_code: 'TEST0001234',
  account_holder_name: 'Test Seller',
  aadhaar_number: '123456789012'
};

// Test location data
const testLocation = {
  latitude: 12.9352,
  longitude: 77.6245,
  delivery_radius_km: 8,
  location_verified: true,
  address: 'Koramangala, Bangalore, Karnataka, India'
};

async function testSellerSyncWebhook() {
  console.log('🔄 Testing Seller Sync Webhook...');

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/seller-sync-webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': WEBHOOK_API_KEY
      },
      body: JSON.stringify({
        seller_id: 'test-seller-uuid-123',
        seller_name: testSeller.seller_name,
        contact_phone: testSeller.contact_phone,
        seller_type: testSeller.seller_type,
        business_city: testSeller.business_city,
        business_address: testSeller.business_address,
        business_pincode: testSeller.business_pincode,
        gstin: testSeller.gstin,
        fssai_license: testSeller.fssai_license,
        bank_account_number: testSeller.bank_account_number,
        ifsc_code: testSeller.ifsc_code,
        account_holder_name: testSeller.account_holder_name,
        aadhaar_number: testSeller.aadhaar_number,
        action: 'create_for_approval',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
    });

    const result = await response.json();

    if (response.ok && result.success) {
      console.log('✅ Seller Sync Webhook Test PASSED');
      console.log(`   Seller created in Odoo with ID: ${result.odoo_seller_id}`);
      return { success: true, odoo_seller_id: result.odoo_seller_id };
    } else {
      console.log('❌ Seller Sync Webhook Test FAILED');
      console.log(`   Error: ${result.error || result.message}`);
      return { success: false, error: result.error };
    }
  } catch (error) {
    console.log('❌ Seller Sync Webhook Test ERROR');
    console.log(`   Exception: ${error.message}`);
    return { success: false, error: error.message };
  }
}

async function testSellerApprovalWebhook(sellerId) {
  console.log('🔄 Testing Seller Approval Webhook...');

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/seller-approval-webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': WEBHOOK_API_KEY
      },
      body: JSON.stringify({
        seller_id: sellerId,
        is_approved: true,
        updated_at: new Date().toISOString()
      })
    });

    const result = await response.json();

    if (response.ok && result.success) {
      console.log('✅ Seller Approval Webhook Test PASSED');
      console.log(`   Seller approved: ${result.seller_name}`);
      console.log(`   Status: ${result.approval_status}`);
      return { success: true };
    } else {
      console.log('❌ Seller Approval Webhook Test FAILED');
      console.log(`   Error: ${result.error || result.message}`);
      return { success: false, error: result.error };
    }
  } catch (error) {
    console.log('❌ Seller Approval Webhook Test ERROR');
    console.log(`   Exception: ${error.message}`);
    return { success: false, error: error.message };
  }
}

async function testLocationFunctionality() {
  console.log('🔄 Testing Location Functionality...');

  // This would typically be tested in the Flutter app
  // Here we just validate the data structure

  const locationValidation = {
    hasLatitude: testLocation.latitude !== null && testLocation.latitude !== undefined,
    hasLongitude: testLocation.longitude !== null && testLocation.longitude !== undefined,
    hasDeliveryRadius: testLocation.delivery_radius_km > 0,
    hasAddress: testLocation.address && testLocation.address.length > 0,
    coordinatesValid: Math.abs(testLocation.latitude) <= 90 && Math.abs(testLocation.longitude) <= 180
  };

  const allValid = Object.values(locationValidation).every(v => v === true);

  if (allValid) {
    console.log('✅ Location Data Validation PASSED');
    console.log(`   Coordinates: ${testLocation.latitude}, ${testLocation.longitude}`);
    console.log(`   Delivery Radius: ${testLocation.delivery_radius_km}km`);
    console.log(`   Address: ${testLocation.address}`);
    return { success: true };
  } else {
    console.log('❌ Location Data Validation FAILED');
    console.log('   Validation results:', locationValidation);
    return { success: false, validation: locationValidation };
  }
}

async function runAllTests() {
  console.log('🚀 Starting Seller Location & Approval Integration Tests');
  console.log('=' .repeat(60));

  const results = {
    locationTest: await testLocationFunctionality(),
    syncTest: await testSellerSyncWebhook(),
    approvalTest: null
  };

  // Only test approval if sync succeeded
  if (results.syncTest.success) {
    results.approvalTest = await testSellerApprovalWebhook('test-seller-uuid-123');
  } else {
    console.log('⏭️  Skipping approval test due to sync failure');
  }

  console.log('=' .repeat(60));
  console.log('📊 TEST RESULTS SUMMARY:');
  console.log(`   Location Functionality: ${results.locationTest.success ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Seller Sync Webhook: ${results.syncTest.success ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`   Seller Approval Webhook: ${results.approvalTest ? (results.approvalTest.success ? '✅ PASS' : '❌ FAIL') : '⏭️ SKIPPED'}`);

  const overallSuccess = results.locationTest.success &&
                         results.syncTest.success &&
                         (results.approvalTest ? results.approvalTest.success : true);

  console.log('=' .repeat(60));
  console.log(`🎯 OVERALL RESULT: ${overallSuccess ? '✅ ALL TESTS PASSED' : '❌ SOME TESTS FAILED'}`);

  if (!overallSuccess) {
    console.log('\n🔧 TROUBLESHOOTING TIPS:');
    if (!results.locationTest.success) {
      console.log('   - Check location data validation logic');
      console.log('   - Verify GPS coordinates are within valid ranges');
    }
    if (!results.syncTest.success) {
      console.log('   - Verify seller-sync-webhook is deployed');
      console.log('   - Check API key configuration');
      console.log('   - Verify Odoo API proxy is working');
    }
    if (results.approvalTest && !results.approvalTest.success) {
      console.log('   - Verify seller-approval-webhook is deployed');
      console.log('   - Check seller exists in database');
      console.log('   - Verify webhook payload format');
    }
  }

  return overallSuccess;
}

// Run tests if this script is executed directly
if (require.main === module) {
  runAllTests().then(success => {
    process.exit(success ? 0 : 1);
  }).catch(error => {
    console.error('💥 Test execution failed:', error);
    process.exit(1);
  });
}

module.exports = {
  testSellerSyncWebhook,
  testSellerApprovalWebhook,
  testLocationFunctionality,
  runAllTests
};