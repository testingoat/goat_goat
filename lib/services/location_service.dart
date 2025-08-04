import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
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
        print('✅ Current location: ${position.latitude}, ${position.longitude}');
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
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
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
  Future<Map<String, dynamic>?> getSavedDeliveryLocation(String customerId) async {
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
}
