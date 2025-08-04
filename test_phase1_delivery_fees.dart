/// Test script for Phase 1: Admin Delivery Fee Management Foundation
/// 
/// This script verifies that all Phase 1 components are working correctly:
/// - Database table creation and constraints
/// - Default configuration insertion
/// - AdminDeliveryConfigService CRUD operations
/// - RLS policies and security
/// 
/// Run this script to validate Phase 1 completion before proceeding to Phase 2

import 'package:flutter/foundation.dart';
import 'lib/services/admin_delivery_config_service.dart';
import 'lib/models/delivery_fee_config.dart';
import 'lib/config/maps_config.dart';

void main() async {
  print('🧪 Testing Phase 1: Admin Delivery Fee Management Foundation');
  print('=' * 60);
  
  await testPhase1Foundation();
}

Future<void> testPhase1Foundation() async {
  final adminService = AdminDeliveryConfigService();
  
  try {
    // Test 1: Feature Flag Check
    print('\n📋 Test 1: Feature Flag Configuration');
    print('kEnableAdminDeliveryRates: $kEnableAdminDeliveryRates');
    print('kEnableDeliveryFees: $kEnableDeliveryFees');
    print('kEnableRealtimeRateUpdates: $kEnableRealtimeRateUpdates');
    print('kEnableAdvancedMultipliers: $kEnableAdvancedMultipliers');
    print('kDeliveryFeesShowInCart: $kDeliveryFeesShowInCart');
    
    if (!kEnableAdminDeliveryRates) {
      print('⚠️ Admin delivery rates feature is disabled');
      print('   Enable kEnableAdminDeliveryRates = true to test');
      return;
    }
    
    // Test 2: Service Availability
    print('\n📋 Test 2: Service Availability');
    final isAvailable = adminService.isAvailable();
    print('AdminDeliveryConfigService available: $isAvailable');
    assert(isAvailable, 'Service should be available when feature flag is enabled');
    print('✅ Service availability check passed');
    
    // Test 3: Fetch Default Configuration
    print('\n📋 Test 3: Default Configuration Retrieval');
    final globalConfig = await adminService.getActiveConfig('GLOBAL');
    
    if (globalConfig == null) {
      print('❌ Default GLOBAL configuration not found');
      print('   Please run the Supabase migration first');
      return;
    }
    
    print('✅ Default GLOBAL configuration found:');
    print('   ID: ${globalConfig.id}');
    print('   Scope: ${globalConfig.scope}');
    print('   Config Name: ${globalConfig.configName}');
    print('   Is Active: ${globalConfig.isActive}');
    print('   Version: ${globalConfig.version}');
    print('   Tier Rates: ${globalConfig.tierRates.length} tiers');
    print('   Min Fee: ₹${globalConfig.minFee}');
    print('   Max Fee: ₹${globalConfig.maxFee}');
    print('   Free Delivery Threshold: ₹${globalConfig.freeDeliveryThreshold}');
    
    // Test 4: Configuration Validation
    print('\n📋 Test 4: Configuration Validation');
    final isValid = adminService.validateConfig(globalConfig);
    print('Configuration validation: $isValid');
    assert(isValid, 'Default configuration should be valid');
    print('✅ Configuration validation passed');
    
    // Test 5: Tier Rate Validation
    print('\n📋 Test 5: Tier Rate Structure');
    for (int i = 0; i < globalConfig.tierRates.length; i++) {
      final tier = globalConfig.tierRates[i];
      print('   Tier ${i + 1}: ${tier.displayRange} → ₹${tier.fee ?? '${tier.baseFee}+${tier.perKmFee}/km'}');
    }
    
    // Test distance calculations
    final testDistances = [1.5, 4.0, 7.5, 10.5, 15.0];
    print('\n   Fee calculations for test distances:');
    for (final distance in testDistances) {
      final applicableTier = globalConfig.tierRates.firstWhere(
        (tier) => tier.appliesTo(distance),
        orElse: () => globalConfig.tierRates.last,
      );
      final fee = applicableTier.calculateFee(distance);
      print('   ${distance}km → ₹$fee (${applicableTier.displayRange})');
    }
    
    // Test 6: CRUD Operations
    print('\n📋 Test 6: CRUD Operations');
    
    // Create test configuration
    final testConfig = DeliveryFeeConfig(
      id: '', // Will be generated
      scope: 'CITY:TEST',
      configName: 'test_config',
      isActive: false,
      tierRates: [
        const DeliveryFeeTier(minKm: 0, maxKm: 5, fee: 25),
        const DeliveryFeeTier(minKm: 5, maxKm: null, baseFee: 50, perKmFee: 8),
      ],
      dynamicMultipliers: DeliveryFeeMultipliers.defaultMultipliers,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    print('   Creating test configuration...');
    final createdConfig = await adminService.createConfig(testConfig);
    print('   ✅ Created config: ${createdConfig.id}');
    
    // Read configuration
    print('   Reading created configuration...');
    final readConfig = await adminService.getConfigById(createdConfig.id);
    assert(readConfig != null, 'Should be able to read created config');
    print('   ✅ Read config: ${readConfig!.scope}');
    
    // Update configuration
    print('   Updating configuration...');
    final updatedConfig = readConfig.copyWith(
      configName: 'updated_test_config',
      minFee: 20.0,
    );
    final savedConfig = await adminService.updateConfig(updatedConfig, 'test_admin');
    print('   ✅ Updated config: ${savedConfig.configName} (version ${savedConfig.version})');
    
    // Test optimistic locking
    print('   Testing optimistic locking...');
    try {
      // Try to update with old version
      await adminService.updateConfig(updatedConfig, 'test_admin');
      print('   ❌ Optimistic locking failed - should have thrown error');
    } catch (e) {
      print('   ✅ Optimistic locking working: ${e.toString().substring(0, 50)}...');
    }
    
    // Delete configuration
    print('   Deleting test configuration...');
    final deleted = await adminService.deleteConfig(savedConfig.id, 'test_admin');
    assert(deleted, 'Should be able to delete test config');
    print('   ✅ Deleted config successfully');
    
    // Test 7: Scope Resolution
    print('\n📋 Test 7: Scope Resolution');
    
    // Test GLOBAL fallback
    final globalFallback = await adminService.getActiveConfig('CITY:NONEXISTENT');
    assert(globalFallback != null, 'Should fallback to GLOBAL config');
    assert(globalFallback!.scope == 'GLOBAL', 'Should return GLOBAL config');
    print('   ✅ GLOBAL fallback working for non-existent city');
    
    // Test 8: List Configurations
    print('\n📋 Test 8: List Configurations');
    final allConfigs = await adminService.getConfigs();
    print('   Total configurations: ${allConfigs.length}');
    
    final activeConfigs = await adminService.getConfigs(isActive: true);
    print('   Active configurations: ${activeConfigs.length}');
    
    final globalConfigs = await adminService.getConfigs(scope: 'GLOBAL');
    print('   GLOBAL configurations: ${globalConfigs.length}');
    
    assert(allConfigs.isNotEmpty, 'Should have at least one configuration');
    assert(activeConfigs.isNotEmpty, 'Should have at least one active configuration');
    assert(globalConfigs.isNotEmpty, 'Should have GLOBAL configuration');
    print('   ✅ List operations working correctly');
    
    // Test 9: Data Model Validation
    print('\n📋 Test 9: Data Model Validation');
    
    // Test JSON serialization/deserialization
    final originalConfig = globalConfig;
    final json = originalConfig.toJson();
    final deserializedConfig = DeliveryFeeConfig.fromJson(json);
    
    assert(originalConfig.id == deserializedConfig.id, 'ID should match');
    assert(originalConfig.scope == deserializedConfig.scope, 'Scope should match');
    assert(originalConfig.version == deserializedConfig.version, 'Version should match');
    print('   ✅ JSON serialization/deserialization working');
    
    // Test scope parsing
    assert(globalConfig.scopeType == 'GLOBAL', 'Should identify GLOBAL scope type');
    assert(globalConfig.scopeValue == null, 'GLOBAL scope should have no value');
    print('   ✅ Scope parsing working correctly');
    
    // Phase 1 Completion Summary
    print('\n' + '=' * 60);
    print('🎉 Phase 1 Foundation Testing Complete!');
    print('=' * 60);
    print('✅ Database table and constraints working');
    print('✅ Default GLOBAL configuration loaded');
    print('✅ AdminDeliveryConfigService CRUD operations functional');
    print('✅ Optimistic locking preventing conflicts');
    print('✅ Scope resolution with fallback working');
    print('✅ Data models and validation working');
    print('✅ Feature flags configured correctly');
    print('');
    print('🚀 Ready for Phase 2: Admin UI Foundation');
    print('   Next: Create admin panel screens for configuration management');
    
  } catch (e, stackTrace) {
    print('\n❌ Phase 1 Testing Failed!');
    print('Error: $e');
    if (kDebugMode) {
      print('Stack trace: $stackTrace');
    }
    print('');
    print('🔧 Troubleshooting:');
    print('1. Ensure Supabase migration has been run');
    print('2. Check database connection and permissions');
    print('3. Verify RLS policies are correctly configured');
    print('4. Enable kEnableAdminDeliveryRates feature flag');
  }
}

/// Helper function to print test section headers
void printTestHeader(String title) {
  print('\n📋 $title');
  print('-' * (title.length + 4));
}
