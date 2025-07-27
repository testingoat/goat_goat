import 'package:supabase_flutter/supabase_flutter.dart';

/// Feature flag management system for gradual rollout of new features
///
/// This system allows us to:
/// - Deploy features with flags OFF for testing
/// - Enable features for specific user groups
/// - Quick rollback if issues are detected
/// - A/B testing capabilities
class FeatureFlags {
  static final FeatureFlags _instance = FeatureFlags._internal();
  factory FeatureFlags() => _instance;
  FeatureFlags._internal();

  // Local feature flags for development and immediate control
  static const Map<String, bool> _localFlags = {
    // Phase 1 Features
    'order_history':
        true, // Phase 1.1 - Order History & Tracking (ENABLED FOR TESTING)
    'product_reviews': false, // Phase 1.2 - Product Reviews & Ratings
    'basic_notifications': false, // Phase 1.3 - Basic Notifications
    // Phase 2 Features
    'inventory_management': false, // Phase 2.1 - Inventory Management
    'loyalty_program': false, // Phase 2.2 - Loyalty Program
    // Phase 3 Features
    'advanced_analytics': false, // Phase 3.1 - Advanced Analytics
    'multi_vendor': false, // Phase 3.2 - Multi-vendor Marketplace
    // Development and Testing
    'debug_mode': false, // Debug information display
    'performance_monitoring': true, // Performance tracking
  };

  // Cache for remote flags to avoid repeated database calls
  static final Map<String, bool> _remoteCache = {};
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Check if a feature is enabled locally
  /// This is the primary method for feature flag checks
  static bool isEnabled(String featureName) {
    return _localFlags[featureName] ?? false;
  }

  /// Check if a feature is enabled with remote configuration
  /// Falls back to local flags if remote check fails
  static Future<bool> isEnabledRemote(String featureName) async {
    try {
      // Check cache first
      if (_isRemoteCacheValid() && _remoteCache.containsKey(featureName)) {
        return _remoteCache[featureName] ?? _localFlags[featureName] ?? false;
      }

      // Fetch from Supabase
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('feature_flags')
          .select('enabled')
          .eq('feature_name', featureName)
          .maybeSingle();

      final remoteEnabled = response?['enabled'] as bool?;

      if (remoteEnabled != null) {
        _remoteCache[featureName] = remoteEnabled;
        _lastCacheUpdate = DateTime.now();
        return remoteEnabled;
      }
    } catch (e) {
      print(
        '⚠️ FEATURE FLAGS - Error fetching remote flag for $featureName: $e',
      );
    }

    // Fallback to local flag
    return _localFlags[featureName] ?? false;
  }

  /// Enable a feature locally (for development/testing)
  static void enableFeature(String featureName) {
    if (_localFlags.containsKey(featureName)) {
      // Note: This modifies the const map conceptually
      // In production, this would update a mutable configuration
      print('🚩 FEATURE FLAGS - Would enable $featureName locally');
    }
  }

  /// Disable a feature locally (for quick rollback)
  static void disableFeature(String featureName) {
    if (_localFlags.containsKey(featureName)) {
      print('🚩 FEATURE FLAGS - Would disable $featureName locally');
    }
  }

  /// Get all feature flags and their status
  static Map<String, bool> getAllFlags() {
    return Map.from(_localFlags);
  }

  /// Get enabled features only
  static List<String> getEnabledFeatures() {
    return _localFlags.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Check if remote cache is still valid
  static bool _isRemoteCacheValid() {
    if (_lastCacheUpdate == null) return false;
    return DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  /// Clear remote cache (useful for testing)
  static void clearRemoteCache() {
    _remoteCache.clear();
    _lastCacheUpdate = null;
  }

  /// Initialize feature flags system
  /// This can be called during app startup to warm the cache
  static Future<void> initialize() async {
    try {
      print('🚩 FEATURE FLAGS - Initializing feature flag system...');

      // Warm cache for critical features
      final criticalFeatures = [
        'order_history',
        'product_reviews',
        'basic_notifications',
      ];

      for (final feature in criticalFeatures) {
        await isEnabledRemote(feature);
      }

      print('🚩 FEATURE FLAGS - Initialization complete');
      print('🚩 FEATURE FLAGS - Enabled features: ${getEnabledFeatures()}');
    } catch (e) {
      print('⚠️ FEATURE FLAGS - Initialization error: $e');
    }
  }

  /// Log feature usage for analytics
  static void logFeatureUsage(String featureName, String action) {
    if (isEnabled('performance_monitoring')) {
      try {
        Supabase.instance.client.from('feature_usage_logs').insert({
          'feature_name': featureName,
          'action': action,
          'timestamp': DateTime.now().toIso8601String(),
          'user_type': 'customer', // This could be dynamic based on context
        });
      } catch (e) {
        print('⚠️ FEATURE FLAGS - Error logging usage: $e');
      }
    }
  }

  /// Check if feature is in beta (for UI indicators)
  static bool isFeatureBeta(String featureName) {
    // Features in Phase 1 are considered beta
    const betaFeatures = [
      'order_history',
      'product_reviews',
      'basic_notifications',
    ];

    return betaFeatures.contains(featureName) && isEnabled(featureName);
  }

  /// Get feature description for UI display
  static String getFeatureDescription(String featureName) {
    const descriptions = {
      'order_history': 'View your complete order history and track deliveries',
      'product_reviews':
          'Read and write reviews for products you\'ve purchased',
      'basic_notifications': 'Receive SMS notifications for order updates',
      'inventory_management': 'Advanced inventory tracking for sellers',
      'loyalty_program': 'Earn and redeem loyalty points on purchases',
      'advanced_analytics': 'Detailed business analytics and insights',
      'multi_vendor': 'Shop from multiple vendors in one order',
    };

    return descriptions[featureName] ?? 'New feature';
  }
}

/// Extension for easy feature flag checking in widgets
extension FeatureFlagContext on String {
  bool get isFeatureEnabled => FeatureFlags.isEnabled(this);
  Future<bool> get isFeatureEnabledRemote => FeatureFlags.isEnabledRemote(this);
  bool get isFeatureBeta => FeatureFlags.isFeatureBeta(this);
  String get featureDescription => FeatureFlags.getFeatureDescription(this);
}
