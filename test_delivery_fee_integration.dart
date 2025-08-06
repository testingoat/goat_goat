/// Test file for Phase 3A.1 - Delivery Fee Service Integration
/// 
/// This file tests the integration between DeliveryFeeService and LocationService
/// to ensure delivery fee calculations work correctly with admin panel configurations.
/// 
/// Run this test to verify:
/// - Admin panel configurations are fetched correctly
/// - Distance calculations work with Google Maps API
/// - Tier-based pricing is applied correctly
/// - Free delivery thresholds are respected
/// - Caching mechanisms function properly

import 'package:flutter/foundation.dart';
import 'lib/services/delivery_fee_service.dart';
import 'lib/services/location_service.dart';

/// Test the delivery fee calculation system
Future<void> testDeliveryFeeIntegration() async {
  print('🧪 TESTING - Phase 3A.1 Delivery Fee Integration');
  print('=' * 60);

  final deliveryFeeService = DeliveryFeeService();
  final locationService = LocationService();

  // Test 1: Fetch active configuration
  print('\n📋 Test 1: Fetching Active Configuration');
  try {
    final config = await deliveryFeeService.getActiveConfig();
    if (config != null) {
      print('✅ Active configuration found: ${config.configName}');
      print('   Scope: ${config.scope}');
      print('   Min Fee: ₹${config.minFee}');
      print('   Max Fee: ₹${config.maxFee}');
      print('   Free Delivery Threshold: ₹${config.freeDeliveryThreshold}');
      print('   Max Distance: ${config.maxServiceableDistanceKm}km');
      print('   Tier Count: ${config.tierRates.length}');
    } else {
      print('❌ No active configuration found');
      return;
    }
  } catch (e) {
    print('❌ Error fetching configuration: $e');
    return;
  }

  // Test 2: Distance calculation
  print('\n📏 Test 2: Distance Calculation');
  try {
    final distanceResult = await locationService.calculateDistance(
      origin: 'Bangalore, Karnataka, India',
      destination: 'Koramangala, Bangalore, Karnataka, India',
      useRouting: true,
    );

    if (distanceResult['success']) {
      print('✅ Distance calculated: ${distanceResult['distance_km'].toStringAsFixed(2)}km');
      print('   Method: ${distanceResult['method']}');
      if (distanceResult['duration_minutes'] != null) {
        print('   Duration: ${distanceResult['duration_minutes'].toStringAsFixed(0)} minutes');
      }
    } else {
      print('❌ Distance calculation failed: ${distanceResult['error']}');
    }
  } catch (e) {
    print('❌ Error calculating distance: $e');
  }

  // Test 3: Delivery fee calculation (normal order)
  print('\n💰 Test 3: Delivery Fee Calculation (Normal Order)');
  try {
    final feeResult = await deliveryFeeService.calculateDeliveryFee(
      customerAddress: 'Koramangala, Bangalore, Karnataka, India',
      orderSubtotal: 250.0, // Below free delivery threshold
    );

    if (feeResult['success']) {
      print('✅ Delivery fee calculated: ₹${feeResult['fee'].toStringAsFixed(0)}');
      print('   Distance: ${feeResult['distance_km'].toStringAsFixed(2)}km');
      print('   Tier: ${feeResult['tier']}');
      if (feeResult['applied_multipliers'].isNotEmpty) {
        print('   Multipliers: ${feeResult['applied_multipliers'].join(', ')}');
      }
    } else {
      print('❌ Fee calculation failed: ${feeResult['error']}');
    }
  } catch (e) {
    print('❌ Error calculating delivery fee: $e');
  }

  // Test 4: Free delivery threshold
  print('\n🎉 Test 4: Free Delivery Threshold');
  try {
    final feeResult = await deliveryFeeService.calculateDeliveryFee(
      customerAddress: 'Koramangala, Bangalore, Karnataka, India',
      orderSubtotal: 600.0, // Above free delivery threshold (₹500)
    );

    if (feeResult['success']) {
      if (feeResult['fee'] == 0.0 && feeResult['reason'] == 'free_delivery_threshold') {
        print('✅ Free delivery applied correctly');
        print('   Threshold: ₹${feeResult['threshold']}');
      } else {
        print('⚠️ Free delivery not applied: ₹${feeResult['fee'].toStringAsFixed(0)}');
      }
    } else {
      print('❌ Fee calculation failed: ${feeResult['error']}');
    }
  } catch (e) {
    print('❌ Error testing free delivery: $e');
  }

  // Test 5: Location serviceability
  print('\n🗺️ Test 5: Location Serviceability');
  try {
    final isServiceable = await deliveryFeeService.isLocationServiceable(
      'Koramangala, Bangalore, Karnataka, India',
    );
    print('✅ Location serviceability: ${isServiceable ? 'Serviceable' : 'Not Serviceable'}');

    // Test distant location
    final isDistantServiceable = await deliveryFeeService.isLocationServiceable(
      'Mumbai, Maharashtra, India',
    );
    print('✅ Distant location serviceability: ${isDistantServiceable ? 'Serviceable' : 'Not Serviceable'}');
  } catch (e) {
    print('❌ Error checking serviceability: $e');
  }

  // Test 6: Cache performance
  print('\n📦 Test 6: Cache Performance');
  try {
    final cacheStats = locationService.getDistanceCacheStats();
    print('✅ Cache statistics:');
    print('   Total entries: ${cacheStats['total_entries']}');
    print('   Valid entries: ${cacheStats['valid_entries']}');
    print('   Cache hit potential: ${(cacheStats['cache_hit_potential'] * 100).toStringAsFixed(1)}%');
  } catch (e) {
    print('❌ Error getting cache stats: $e');
  }

  // Test 7: Address validation
  print('\n✅ Test 7: Address Validation');
  final testAddresses = [
    'Koramangala, Bangalore, Karnataka, India',
    'Short',
    '123 Main Street, Bangalore 560034',
    'Invalid',
  ];

  for (final address in testAddresses) {
    final isValid = locationService.isValidAddress(address);
    print('   "$address" → ${isValid ? 'Valid' : 'Invalid'}');
  }

  print('\n🎯 TESTING COMPLETE - Phase 3A.1 Integration');
  print('=' * 60);
}

/// Main function to run the test
void main() async {
  await testDeliveryFeeIntegration();
}
