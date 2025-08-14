import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_service.dart';

/// SellerLocationService
/// Zero-risk service for managing seller location and delivery zones.
/// Integrates with existing LocationService for GPS functionality.
///
/// Features:
/// - GPS capture for business location
/// - Delivery zone management
/// - Location verification and validation
/// - Integration with customer delivery calculations
class SellerLocationService {
  final SupabaseClient _client = Supabase.instance.client;
  final LocationService _locationService = LocationService();

  /// Capture current GPS location for seller's business
  ///
  /// Returns a map with location data or error information
  /// Includes coordinates, address, and accuracy information
  Future<Map<String, dynamic>> captureBusinessLocation() async {
    try {
      if (kDebugMode) {
        print(
          '📍 SellerLocationService: Starting GPS capture for business location',
        );
      }

      // Check location availability
      bool isAvailable = await _locationService.isLocationAvailable();
      if (!isAvailable) {
        return {
          'success': false,
          'error':
              'Location services are not available. Please enable location permissions and GPS.',
          'error_code': 'LOCATION_UNAVAILABLE',
        };
      }

      // Get current position
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        return {
          'success': false,
          'error': 'Unable to get current location. Please try again.',
          'error_code': 'GPS_FAILED',
        };
      }

      if (kDebugMode) {
        print(
          '✅ SellerLocationService: GPS coordinates captured: ${position.latitude}, ${position.longitude}',
        );
        print('📊 SellerLocationService: Accuracy: ${position.accuracy}m');
      }

      // Get human-readable address
      String? address = await _locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      // Validate accuracy (warn if accuracy is poor)
      String? accuracyWarning;
      if (position.accuracy > 100) {
        accuracyWarning =
            'Location accuracy is low (${position.accuracy.toInt()}m). Consider moving to an open area for better accuracy.';
      }

      return {
        'success': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'address': address ?? 'Address not available',
        'timestamp': DateTime.now().toIso8601String(),
        'accuracy_warning': accuracyWarning,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerLocationService: GPS capture failed: $e');
      }

      return {
        'success': false,
        'error': 'Failed to capture location: ${e.toString()}',
        'error_code': 'CAPTURE_ERROR',
      };
    }
  }

  /// Update seller's business location in database
  ///
  /// Parameters:
  /// - sellerId: The seller's UUID
  /// - latitude: Business latitude coordinate
  /// - longitude: Business longitude coordinate
  /// - deliveryRadius: Delivery service radius in kilometers (optional)
  /// - verified: Whether the location has been verified (optional)
  Future<Map<String, dynamic>> updateSellerLocation({
    required String sellerId,
    required double latitude,
    required double longitude,
    int? deliveryRadius,
    bool? verified,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '💾 SellerLocationService: Updating location for seller: $sellerId',
        );
        print('📍 SellerLocationService: Coordinates: $latitude, $longitude');
        if (deliveryRadius != null) {
          print(
            '🚚 SellerLocationService: Delivery radius: ${deliveryRadius}km',
          );
        }
      }

      // Prepare update data
      final updateData = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      };

      if (deliveryRadius != null) {
        updateData['delivery_radius_km'] = deliveryRadius;
      }

      if (verified != null) {
        updateData['location_verified'] = verified;
      }

      // Update seller in database
      final response = await _client
          .from('sellers')
          .update(updateData)
          .eq('id', sellerId)
          .select()
          .single();

      if (kDebugMode) {
        print('✅ SellerLocationService: Location updated successfully');
      }

      return {
        'success': true,
        'message': 'Business location updated successfully',
        'seller_data': response,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerLocationService: Database update failed: $e');
      }

      return {
        'success': false,
        'error': 'Failed to update location: ${e.toString()}',
        'error_code': 'DATABASE_ERROR',
      };
    }
  }

  /// Get seller's current location data from database
  ///
  /// Returns seller's stored location information
  Future<Map<String, dynamic>> getSellerLocation(String sellerId) async {
    try {
      if (kDebugMode) {
        print(
          '📖 SellerLocationService: Fetching location for seller: $sellerId',
        );
      }

      final response = await _client
          .from('sellers')
          .select(
            'latitude, longitude, delivery_radius_km, location_verified, location_updated_at, business_address, business_city',
          )
          .eq('id', sellerId)
          .single();

      if (kDebugMode) {
        print('✅ SellerLocationService: Location data retrieved');
      }

      return {
        'success': true,
        'location_data': response,
        'has_location':
            response['latitude'] != null && response['longitude'] != null,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerLocationService: Failed to fetch location: $e');
      }

      return {
        'success': false,
        'error': 'Failed to fetch location data: ${e.toString()}',
        'error_code': 'FETCH_ERROR',
      };
    }
  }

  /// Calculate if a customer address is within seller's delivery zone
  ///
  /// Parameters:
  /// - sellerLatitude: Seller's business latitude
  /// - sellerLongitude: Seller's business longitude
  /// - deliveryRadius: Seller's delivery radius in kilometers
  /// - customerAddress: Customer's delivery address
  Future<Map<String, dynamic>> isWithinDeliveryZone({
    required double sellerLatitude,
    required double sellerLongitude,
    required int deliveryRadius,
    required String customerAddress,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🎯 SellerLocationService: Checking delivery zone for address: $customerAddress',
        );
        print(
          '📍 SellerLocationService: Seller location: $sellerLatitude, $sellerLongitude',
        );
        print('📏 SellerLocationService: Delivery radius: ${deliveryRadius}km');
      }

      // Use existing LocationService to calculate distance
      final sellerLocation =
          '$sellerLatitude,$sellerLongitude'; // Use coordinates as origin
      final distanceResult = await _locationService.calculateDistance(
        origin: sellerLocation,
        destination: customerAddress,
        useRouting: true,
      );

      if (!distanceResult['success']) {
        return {
          'success': false,
          'error': 'Unable to calculate distance to customer address',
          'error_code': 'DISTANCE_CALCULATION_FAILED',
        };
      }

      final distanceKm = distanceResult['distance_km'] as double;
      final isWithinZone = distanceKm <= deliveryRadius;

      if (kDebugMode) {
        print(
          '📏 SellerLocationService: Distance to customer: ${distanceKm.toStringAsFixed(2)}km',
        );
        print('✅ SellerLocationService: Within delivery zone: $isWithinZone');
      }

      return {
        'success': true,
        'distance_km': distanceKm,
        'delivery_radius_km': deliveryRadius,
        'within_zone': isWithinZone,
        'duration_minutes': distanceResult['duration_minutes'],
        'calculation_method': distanceResult['method'],
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerLocationService: Delivery zone check failed: $e');
      }

      return {
        'success': false,
        'error': 'Failed to check delivery zone: ${e.toString()}',
        'error_code': 'ZONE_CHECK_ERROR',
      };
    }
  }

  /// Validate delivery radius value
  ///
  /// Ensures the delivery radius is within reasonable limits
  static String? validateDeliveryRadius(int? radius) {
    if (radius == null) return null;

    if (radius < 1) {
      return 'Delivery radius must be at least 1 km';
    }

    if (radius > 50) {
      return 'Delivery radius cannot exceed 50 km';
    }

    return null; // Valid radius
  }

  /// Get suggested delivery radius based on business type and location
  ///
  /// Provides intelligent defaults for delivery radius
  static int getSuggestedDeliveryRadius({
    required String sellerType,
    required String? businessCity,
  }) {
    // Base radius suggestions
    int baseRadius = 5; // Default 5km

    // Adjust based on seller type
    switch (sellerType.toLowerCase()) {
      case 'meat':
        baseRadius = 8; // Meat shops typically serve wider areas
        break;
      case 'livestock':
        baseRadius = 15; // Livestock may need larger delivery zones
        break;
      case 'both':
        baseRadius = 10; // Combined services
        break;
    }

    // Adjust based on city size (rough estimates)
    if (businessCity != null) {
      final city = businessCity.toLowerCase();
      if (city.contains('bangalore') ||
          city.contains('bengaluru') ||
          city.contains('mumbai') ||
          city.contains('delhi') ||
          city.contains('chennai') ||
          city.contains('kolkata') ||
          city.contains('hyderabad') ||
          city.contains('pune')) {
        // Major metros - reduce radius due to traffic
        baseRadius = (baseRadius * 0.8).round();
      } else if (city.contains('ahmedabad') ||
          city.contains('surat') ||
          city.contains('jaipur') ||
          city.contains('lucknow') ||
          city.contains('kanpur') ||
          city.contains('nagpur')) {
        // Tier 2 cities - standard radius
        // Keep base radius as is
      } else {
        // Smaller cities - can increase radius
        baseRadius = (baseRadius * 1.2).round();
      }
    }

    // Ensure within valid range
    return baseRadius.clamp(3, 25);
  }

  /// Format location for display
  ///
  /// Creates a human-readable location string
  static String formatLocationDisplay({
    required double? latitude,
    required double? longitude,
    String? address,
    bool showCoordinates = false,
  }) {
    if (latitude == null || longitude == null) {
      return 'Location not set';
    }

    if (address != null &&
        address.isNotEmpty &&
        address != 'Address not available') {
      if (showCoordinates) {
        return '$address\n(${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)})';
      }
      return address;
    }

    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}
