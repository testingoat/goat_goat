// Google Maps Configuration and Feature Flags
//
// This file contains configuration constants for Google Maps integration
// following the zero-risk implementation pattern with feature flags.

/// Feature flag to enable/disable Google Maps integration in the catalog screen
///
/// Set to `true` to enable the delivery location section with Google Maps
/// Set to `false` to disable and hide the maps functionality entirely
///
/// This allows for safe rollout and instant rollback if needed
const bool kEnableCatalogMap = true;

// ===== PHASE C FEATURE FLAGS =====

/// Phase C.1: Places API Autocomplete
/// Enable address search functionality in location selector
const bool kEnablePlacesAutocomplete = true;

/// Phase C.2: Multiple Delivery Addresses
/// Enable saving and managing multiple delivery locations
const bool kEnableMultipleAddresses = false; // Start disabled for safe rollout

/// Phase C.3: Delivery Zone Validation
/// Enable checking if selected location is in delivery area
const bool kEnableDeliveryZones = false;

/// Phase C.4: Distance-based Delivery Fees
/// Enable calculating delivery fees based on distance
const bool kEnableDeliveryFees = false;

/// Phase C.4: Admin Delivery Rate Management
/// Enable admin panel delivery fee configuration (Phase 1-5)
const bool kEnableAdminDeliveryRates =
    true; // ✅ ENABLED - Phase 2 Admin UI ready!

// ===== PHASE 3A.3 FEATURE FLAGS =====

/// Phase 3A.3: Delivery Address Pill in Header
/// Enable compact delivery address display in app header
const bool kShowDeliveryAddressPill = true;

/// Phase 3A.3: Simplified Address Input (UI Fix)
/// Enable single smart input field instead of dual input fields
/// Removes "Or enter manually" secondary text field to eliminate UI duplication
const bool kUseSimplifiedAddressInput = true;

/// Phase 3A.3: Hide Home Map Section (UI Fix)
/// Hide redundant DeliveryLocationSection from home screen
/// Keeps only the address pill to eliminate duplicate address entry points
const bool kHideHomeMapSection = true;

/// Phase C.4: Real-time Rate Updates
/// Enable real-time config updates from admin panel (Phase 4+)
const bool kEnableRealtimeRateUpdates = false;

/// Phase C.4: Advanced Multipliers
/// Enable dynamic pricing multipliers (peak hours, weather, demand) (Phase 3+)
const bool kEnableAdvancedMultipliers = false;

/// Phase C.4: Delivery Fees in Cart
/// Show delivery fees in shopping cart summary (Phase 6+)
const bool kDeliveryFeesShowInCart = false;

/// Default location coordinates (Bangalore, India)
/// Used as fallback when user location is not available
const double kDefaultLatitude = 12.9716;
const double kDefaultLongitude = 77.5946;

/// Map UI configuration constants
const double kCompactMapHeight = 120.0;
const double kMapBorderRadius = 12.0;
const double kDefaultMapZoom = 15.0;

/// Location service configuration
const int kLocationTimeoutSeconds = 30;
const double kLocationAccuracyMeters = 100.0;

/// Google Maps API configuration
/// Note: API keys should be configured in platform-specific files
/// Android: android/app/src/main/AndroidManifest.xml
/// iOS: ios/Runner/AppDelegate.swift and Info.plist

/// Google Maps API Key for HTTP requests (Distance Matrix, Geocoding, Places)
/// This is used for server-side API calls from the Flutter app
const String kGoogleMapsApiKey = 'AIzaSyDOBBimUu_eGMwsXZUqrNFk3puT5rMWbig';

class MapsConfig {
  static const String androidApiKeyMetaName = 'com.google.android.geo.API_KEY';
  static const String iosApiKeyName = 'GOOGLE_MAPS_API_KEY';

  // Prevent instantiation
  MapsConfig._();
}
