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
class MapsConfig {
  static const String androidApiKeyMetaName = 'com.google.android.geo.API_KEY';
  static const String iosApiKeyName = 'GOOGLE_MAPS_API_KEY';

  // Prevent instantiation
  MapsConfig._();
}
