/// Auto Location Service
///
/// This service handles automatic location fetching on customer login
/// with proper permission handling and fallback mechanisms.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'delivery_address_state.dart';
import 'location_service.dart';

class AutoLocationService {
  static final LocationService _locationService = LocationService();

  /// Auto-fetch location on customer login
  ///
  /// [context] - BuildContext for showing messages
  /// [customerId] - Customer ID for address association
  /// [onLocationFetched] - Callback when location is successfully fetched
  /// [onLocationDenied] - Callback when location permission is denied
  static Future<void> autoFetchLocationOnLogin({
    required BuildContext context,
    required String customerId,
    Function(String address, Map<String, dynamic> locationData)?
    onLocationFetched,
    VoidCallback? onLocationDenied,
  }) async {
    try {
      print('📍 AUTO_LOCATION - Starting auto-fetch for customer: $customerId');

      // Check if we already have a location for this customer
      if (DeliveryAddressState.hasAddress() &&
          DeliveryAddressState.belongsToCustomer(customerId)) {
        print('📍 AUTO_LOCATION - Using existing address from shared state');
        return;
      }

      // Request location permission immediately
      final permissionStatus = await _requestLocationPermission();

      if (permissionStatus == PermissionStatus.granted) {
        // Permission granted - fetch current location
        await _fetchCurrentLocation(
          context: context,
          customerId: customerId,
          onLocationFetched: onLocationFetched,
        );
      } else {
        // Permission denied - show message and call callback
        _showLocationPermissionDeniedMessage(context);
        onLocationDenied?.call();
      }
    } catch (e) {
      print('❌ AUTO_LOCATION - Error in auto-fetch: $e');
      // Don't show error to user, just continue without auto-location
    }
  }

  /// Request location permission
  static Future<PermissionStatus> _requestLocationPermission() async {
    try {
      // Check current permission status
      PermissionStatus permission = await Permission.location.status;

      if (permission == PermissionStatus.denied) {
        // Request permission
        permission = await Permission.location.request();
      }

      print('📍 AUTO_LOCATION - Permission status: $permission');
      return permission;
    } catch (e) {
      print('❌ AUTO_LOCATION - Permission request error: $e');
      return PermissionStatus.denied;
    }
  }

  /// Fetch current GPS location
  static Future<void> _fetchCurrentLocation({
    required BuildContext context,
    required String customerId,
    Function(String address, Map<String, dynamic> locationData)?
    onLocationFetched,
  }) async {
    try {
      print('📍 AUTO_LOCATION - Fetching GPS location...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ AUTO_LOCATION - Location services disabled');
        _showLocationServicesDisabledMessage(context);
        return;
      }

      // Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      print(
        '📍 AUTO_LOCATION - GPS location: ${position.latitude}, ${position.longitude}',
      );

      // Reverse geocode to get address
      await _reverseGeocodeLocation(
        position: position,
        customerId: customerId,
        onLocationFetched: onLocationFetched,
      );
    } catch (e) {
      print('❌ AUTO_LOCATION - GPS fetch error: $e');
      // Don't show error to user, just continue without auto-location
    }
  }

  /// Reverse geocode GPS coordinates to address
  static Future<void> _reverseGeocodeLocation({
    required Position position,
    required String customerId,
    Function(String address, Map<String, dynamic> locationData)?
    onLocationFetched,
  }) async {
    try {
      // Use LocationService to reverse geocode
      final address = await _locationService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (address != null && address.isNotEmpty) {
        final locationData = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': address,
          'formatted_address': address,
          'source': 'gps_auto_fetch',
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().toIso8601String(),
        };

        // Store in shared state
        DeliveryAddressState.setAddress(
          address,
          locationData: locationData,
          customerId: customerId,
        );

        print(
          '✅ AUTO_LOCATION - Address fetched and stored: ${address.length > 50 ? '${address.substring(0, 50)}...' : address}',
        );

        // Call success callback
        onLocationFetched?.call(address, locationData);
      } else {
        print('⚠️ AUTO_LOCATION - Reverse geocoding failed');
      }
    } catch (e) {
      print('❌ AUTO_LOCATION - Reverse geocoding error: $e');
    }
  }

  /// Show location permission denied message (SnackBar)
  static void _showLocationPermissionDeniedMessage(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location permission needed for delivery. Without location permission, delivery will not be allowed.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            // Open app settings
            openAppSettings();
          },
        ),
      ),
    );
  }

  /// Show location services disabled message
  static void _showLocationServicesDisabledMessage(BuildContext context) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.location_disabled, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location services are disabled. Please enable location services for delivery.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[600],
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            // Open location settings
            Geolocator.openLocationSettings();
          },
        ),
      ),
    );
  }

  /// Check if location permission is granted
  static Future<bool> hasLocationPermission() async {
    try {
      final status = await Permission.location.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      print('❌ AUTO_LOCATION - Permission check error: $e');
      return false;
    }
  }

  /// Check if location services are enabled
  static Future<bool> areLocationServicesEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('❌ AUTO_LOCATION - Location services check error: $e');
      return false;
    }
  }

  /// Get current location without storing (for one-time use)
  static Future<Map<String, dynamic>?> getCurrentLocationOnce() async {
    try {
      if (!await hasLocationPermission()) {
        return null;
      }

      if (!await areLocationServicesEnabled()) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ AUTO_LOCATION - One-time location fetch error: $e');
      return null;
    }
  }
}
