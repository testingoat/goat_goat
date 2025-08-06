import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../config/maps_config.dart';
import '../supabase_service.dart';

/// LocationService - Isolated service for handling all location-related operations
///
/// This service provides location functionality without coupling to existing business logic.
/// It handles permissions, location fetching, geocoding, and persistence through existing services.
///
/// Features:
/// - Permission management with graceful degradation
/// - Current location detection with timeout handling
/// - Reverse geocoding for address lookup
/// - Integration with existing Supabase service for data persistence
/// - Error handling and logging for debugging
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Cache for distance calculations (Phase 3A.1 - Delivery Fee Integration)
  final Map<String, Map<String, dynamic>> _distanceCache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);

  /// Check and request location permissions
  ///
  /// Returns true if permissions are granted, false otherwise
  /// Handles both Android and iOS permission flows gracefully
  Future<bool> ensurePermissions() async {
    try {
      // Check current permission status
      PermissionStatus permission = await Permission.location.status;

      if (kDebugMode) {
        print('📍 Location permission status: $permission');
      }

      // If already granted, return true
      if (permission.isGranted) {
        return true;
      }

      // If denied permanently, cannot request again
      if (permission.isPermanentlyDenied) {
        if (kDebugMode) {
          print('❌ Location permission permanently denied');
        }
        return false;
      }

      // Request permission
      permission = await Permission.location.request();

      if (kDebugMode) {
        print('📍 Location permission after request: $permission');
      }

      return permission.isGranted;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking location permissions: $e');
      }
      return false;
    }
  }

  /// Get current user location with timeout and error handling
  ///
  /// Returns Position if successful, null if failed or permissions denied
  /// Uses high accuracy settings with reasonable timeout
  Future<Position?> getCurrentLocation() async {
    try {
      // Ensure permissions first
      bool hasPermission = await ensurePermissions();
      if (!hasPermission) {
        if (kDebugMode) {
          print('❌ Location permissions not granted');
        }
        return null;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('❌ Location services are disabled');
        }
        return null;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: kLocationTimeoutSeconds),
      );

      if (kDebugMode) {
        print(
          '✅ Current location: ${position.latitude}, ${position.longitude}',
        );
      }

      return position;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting current location: $e');
      }
      return null;
    }
  }

  /// Convert coordinates to human-readable address
  ///
  /// Returns formatted address string or null if geocoding fails
  /// Uses the geocoding package for reverse geocoding
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        // Build formatted address
        List<String> addressParts = [];

        if (place.name != null && place.name!.isNotEmpty) {
          addressParts.add(place.name!);
        }
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }

        String address = addressParts.join(', ');

        if (kDebugMode) {
          print('✅ Reverse geocoded address: $address');
        }

        return address.isNotEmpty ? address : null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error reverse geocoding: $e');
      }
    }
    return null;
  }

  /// Save delivery location to customer profile using existing Supabase service
  ///
  /// Stores location data in the existing customer.delivery_addresses JSONB field
  /// Uses the existing SupabaseService to maintain consistency with current data flow
  Future<bool> saveDeliveryLocation({
    required String customerId,
    required double latitude,
    required double longitude,
    String? address,
    bool isPrimary = true,
  }) async {
    try {
      // Get current location for comparison
      Position? currentPosition = await getCurrentLocation();

      // Reverse geocode if address not provided
      address ??= await reverseGeocode(latitude, longitude);

      // Prepare delivery addresses data structure
      Map<String, dynamic> deliveryData = {
        'selected_delivery': {
          'lat': latitude,
          'lng': longitude,
          'address': address ?? 'Location selected on map',
          'is_primary': isPrimary,
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      // Include current location if available
      if (currentPosition != null) {
        String? currentAddress = await reverseGeocode(
          currentPosition.latitude,
          currentPosition.longitude,
        );

        deliveryData['current_location'] = {
          'lat': currentPosition.latitude,
          'lng': currentPosition.longitude,
          'address': currentAddress ?? 'Current location',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Save using existing Supabase service
      await _supabaseService.updateCustomer(customerId, {
        'delivery_addresses': deliveryData,
      });

      if (kDebugMode) {
        print('✅ Delivery location saved for customer: $customerId');
        print('📍 Location: $latitude, $longitude');
        print('📍 Address: $address');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving delivery location: $e');
      }
      return false;
    }
  }

  /// Get saved delivery location from customer profile
  ///
  /// Returns the saved delivery location data or null if not found
  Future<Map<String, dynamic>?> getSavedDeliveryLocation(
    String customerId,
  ) async {
    try {
      // This would typically fetch from the customer profile
      // For now, we'll return null and let the UI handle the default case
      // In Phase B, we can implement this to read from customer.delivery_addresses

      if (kDebugMode) {
        print('📍 Getting saved delivery location for customer: $customerId');
      }

      return null; // Placeholder for Phase B implementation
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting saved delivery location: $e');
      }
      return null;
    }
  }

  /// Open device settings for location permissions
  ///
  /// Useful when permissions are permanently denied
  Future<void> openLocationSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error opening location settings: $e');
      }
    }
  }

  /// Check if location services are available on the device
  ///
  /// Returns true if location services are enabled and permissions are granted
  Future<bool> isLocationAvailable() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      bool hasPermission = await ensurePermissions();

      return serviceEnabled && hasPermission;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking location availability: $e');
      }
      return false;
    }
  }

  // ===== DISTANCE CALCULATION METHODS (Phase 3A.1 - Delivery Fee Integration) =====

  /// Calculate distance between origin and destination
  /// Uses Google Maps Distance Matrix API or straight-line distance as fallback
  ///
  /// This method is used by DeliveryFeeService for calculating delivery fees
  /// based on distance between customer address and seller location.
  Future<Map<String, dynamic>> calculateDistance({
    required String origin,
    required String destination,
    bool useRouting = true,
  }) async {
    try {
      if (kDebugMode) {
        print('📍 LOCATION - Calculating distance: $origin → $destination');
      }

      // Check cache first
      final cacheKey = '${origin}_${destination}_$useRouting';
      if (_distanceCache.containsKey(cacheKey)) {
        final cached = _distanceCache[cacheKey]!;
        final cacheTime = DateTime.parse(cached['timestamp']);
        if (DateTime.now().difference(cacheTime) < _cacheExpiry) {
          if (kDebugMode) {
            print('📦 LOCATION - Using cached distance');
          }
          return {
            'success': true,
            'distance_km': cached['distance_km'],
            'duration_minutes': cached['duration_minutes'],
            'method': cached['method'],
          };
        }
      }

      Map<String, dynamic> result;

      if (useRouting && kGoogleMapsApiKey.isNotEmpty) {
        // Try Google Maps Distance Matrix API first
        result = await _calculateRoutingDistance(origin, destination);

        if (!result['success']) {
          if (kDebugMode) {
            print(
              '⚠️ LOCATION - Routing failed, falling back to straight-line distance',
            );
          }
          result = await _calculateStraightLineDistance(origin, destination);
        }
      } else {
        // Use straight-line distance
        result = await _calculateStraightLineDistance(origin, destination);
      }

      // Cache successful results
      if (result['success']) {
        _distanceCache[cacheKey] = {
          'distance_km': result['distance_km'],
          'duration_minutes': result['duration_minutes'] ?? 0,
          'method': result['method'],
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ LOCATION - Distance calculation error: $e');
      }
      return {
        'success': false,
        'error': 'Failed to calculate distance: $e',
        'distance_km': 0.0,
      };
    }
  }

  /// Calculate routing distance using Google Maps Distance Matrix API
  Future<Map<String, dynamic>> _calculateRoutingDistance(
    String origin,
    String destination,
  ) async {
    try {
      if (kDebugMode) {
        print('🗺️ LOCATION - Using Google Maps Distance Matrix API');
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${Uri.encodeComponent(origin)}'
        '&destinations=${Uri.encodeComponent(destination)}'
        '&units=metric'
        '&mode=driving'
        '&key=$kGoogleMapsApiKey',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Google Maps API timeout'),
          );

      if (response.statusCode != 200) {
        throw Exception('Google Maps API error: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        throw Exception('Google Maps API status: ${data['status']}');
      }

      final elements = data['rows'][0]['elements'];
      if (elements.isEmpty || elements[0]['status'] != 'OK') {
        throw Exception('No route found between locations');
      }

      final element = elements[0];
      final distanceMeters = element['distance']['value'];
      final durationSeconds = element['duration']['value'];

      final distanceKm = distanceMeters / 1000.0;
      final durationMinutes = durationSeconds / 60.0;

      if (kDebugMode) {
        print(
          '✅ LOCATION - Routing distance: ${distanceKm.toStringAsFixed(2)}km, ${durationMinutes.toStringAsFixed(0)} minutes',
        );
      }

      return {
        'success': true,
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'method': 'google_maps_routing',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ LOCATION - Routing calculation failed: $e');
      }
      return {
        'success': false,
        'error': 'Routing calculation failed: $e',
        'distance_km': 0.0,
      };
    }
  }

  /// Calculate straight-line distance using geocoding
  Future<Map<String, dynamic>> _calculateStraightLineDistance(
    String origin,
    String destination,
  ) async {
    try {
      if (kDebugMode) {
        print('📐 LOCATION - Using straight-line distance calculation');
      }

      // Get coordinates for both locations
      final originCoords = await _geocodeAddress(origin);
      final destCoords = await _geocodeAddress(destination);

      if (originCoords == null || destCoords == null) {
        throw Exception('Failed to geocode one or both addresses');
      }

      // Calculate straight-line distance using Haversine formula
      final distanceKm = _haversineDistance(
        originCoords['lat']!,
        originCoords['lng']!,
        destCoords['lat']!,
        destCoords['lng']!,
      );

      // Estimate duration (assuming average speed of 30 km/h in city)
      final estimatedDurationMinutes = (distanceKm / 30.0) * 60.0;

      if (kDebugMode) {
        print(
          '✅ LOCATION - Straight-line distance: ${distanceKm.toStringAsFixed(2)}km',
        );
      }

      return {
        'success': true,
        'distance_km': distanceKm,
        'duration_minutes': estimatedDurationMinutes,
        'method': 'straight_line',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ LOCATION - Straight-line calculation failed: $e');
      }
      return {
        'success': false,
        'error': 'Straight-line calculation failed: $e',
        'distance_km': 0.0,
      };
    }
  }

  /// Geocode address to get latitude and longitude
  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      if (kGoogleMapsApiKey.isEmpty) {
        // Fallback coordinates for Bangalore if no API key
        if (address.toLowerCase().contains('bangalore') ||
            address.toLowerCase().contains('bengaluru')) {
          return {'lat': 12.9716, 'lng': 77.5946};
        }
        throw Exception('No Google Maps API key available for geocoding');
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=$kGoogleMapsApiKey',
      );

      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Geocoding API timeout'),
          );

      if (response.statusCode != 200) {
        throw Exception('Geocoding API error: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' || data['results'].isEmpty) {
        throw Exception('Address not found: ${data['status']}');
      }

      final location = data['results'][0]['geometry']['location'];
      return {
        'lat': location['lat'].toDouble(),
        'lng': location['lng'].toDouble(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ LOCATION - Geocoding failed for $address: $e');
      }
      return null;
    }
  }

  /// Calculate distance between two points using Haversine formula
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Convert degrees to radians
  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Validate address format
  bool isValidAddress(String address) {
    if (address.trim().isEmpty) return false;
    if (address.trim().length < 10) return false;

    // Basic validation - should contain some location indicators
    final lowerAddress = address.toLowerCase();
    return lowerAddress.contains(
          RegExp(r'\b(bangalore|bengaluru|karnataka|india)\b'),
        ) ||
        lowerAddress.contains(
          RegExp(r'\b(road|street|avenue|lane|area|sector)\b'),
        ) ||
        lowerAddress.contains(RegExp(r'\d{6}')) || // Pincode
        lowerAddress.length > 20; // Assume longer addresses are more complete
  }

  /// Clear distance cache
  void clearDistanceCache() {
    _distanceCache.clear();
    if (kDebugMode) {
      print('🗑️ LOCATION - Distance cache cleared');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getDistanceCacheStats() {
    final now = DateTime.now();
    int validEntries = 0;
    int expiredEntries = 0;

    for (final entry in _distanceCache.values) {
      final cacheTime = DateTime.parse(entry['timestamp']);
      if (now.difference(cacheTime) < _cacheExpiry) {
        validEntries++;
      } else {
        expiredEntries++;
      }
    }

    return {
      'total_entries': _distanceCache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_hit_potential': validEntries / (_distanceCache.length + 1),
    };
  }
}
