import 'package:flutter/foundation.dart';
import 'location_service.dart';
import '../config/maps_config.dart';

/// LocationService Test Helper
/// 
/// This file provides test methods to verify LocationService functionality
/// during Phase A implementation. Can be removed after Phase B is complete.
class LocationServiceTest {
  static final LocationService _locationService = LocationService();

  /// Test all LocationService methods
  static Future<void> runAllTests() async {
    if (kDebugMode) {
      print('🧪 Starting LocationService tests...');
    }

    await testPermissions();
    await testCurrentLocation();
    await testReverseGeocode();
    await testLocationAvailability();

    if (kDebugMode) {
      print('✅ LocationService tests completed');
    }
  }

  /// Test permission handling
  static Future<void> testPermissions() async {
    if (kDebugMode) {
      print('🧪 Testing location permissions...');
    }

    try {
      bool hasPermission = await _locationService.ensurePermissions();
      if (kDebugMode) {
        print('📍 Permission result: $hasPermission');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Permission test failed: $e');
      }
    }
  }

  /// Test current location fetching
  static Future<void> testCurrentLocation() async {
    if (kDebugMode) {
      print('🧪 Testing current location...');
    }

    try {
      var position = await _locationService.getCurrentLocation();
      if (position != null) {
        if (kDebugMode) {
          print('📍 Current location: ${position.latitude}, ${position.longitude}');
        }
      } else {
        if (kDebugMode) {
          print('📍 Current location: null (permissions denied or service disabled)');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Current location test failed: $e');
      }
    }
  }

  /// Test reverse geocoding with default coordinates
  static Future<void> testReverseGeocode() async {
    if (kDebugMode) {
      print('🧪 Testing reverse geocoding...');
    }

    try {
      String? address = await _locationService.reverseGeocode(
        kDefaultLatitude,
        kDefaultLongitude,
      );
      if (kDebugMode) {
        print('📍 Reverse geocoded address: $address');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Reverse geocoding test failed: $e');
      }
    }
  }

  /// Test location availability
  static Future<void> testLocationAvailability() async {
    if (kDebugMode) {
      print('🧪 Testing location availability...');
    }

    try {
      bool isAvailable = await _locationService.isLocationAvailable();
      if (kDebugMode) {
        print('📍 Location available: $isAvailable');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Location availability test failed: $e');
      }
    }
  }

  /// Test save delivery location (mock customer ID)
  static Future<void> testSaveDeliveryLocation() async {
    if (kDebugMode) {
      print('🧪 Testing save delivery location...');
    }

    try {
      bool success = await _locationService.saveDeliveryLocation(
        customerId: 'test-customer-id',
        latitude: kDefaultLatitude,
        longitude: kDefaultLongitude,
        address: 'Test Address, Bangalore',
      );
      if (kDebugMode) {
        print('📍 Save delivery location result: $success');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Save delivery location test failed: $e');
      }
    }
  }
}
