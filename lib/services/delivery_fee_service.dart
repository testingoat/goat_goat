import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_fee_config.dart';
import 'location_service.dart';
import 'delivery_fee_setup_service.dart';

/// DeliveryFeeService - Mobile app service for calculating delivery fees
///
/// This service integrates with the admin panel delivery fee configurations
/// to provide real-time delivery fee calculations for customers during checkout.
///
/// Features:
/// - Fetches active delivery configurations from admin panel
/// - Calculates distance-based delivery fees using Google Maps
/// - Applies tier-based pricing with dynamic multipliers
/// - Handles free delivery thresholds and service area limits
/// - Provides caching for performance optimization
/// - Zero-risk implementation - extends existing functionality only
class DeliveryFeeService {
  static final DeliveryFeeService _instance = DeliveryFeeService._internal();
  factory DeliveryFeeService() => _instance;
  DeliveryFeeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final LocationService _locationService = LocationService();

  // Cache for delivery configurations
  DeliveryFeeConfig? _cachedConfig;
  DateTime? _cacheTimestamp;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get active delivery fee configuration
  /// Returns cached config if available and not expired
  Future<DeliveryFeeConfig?> getActiveConfig() async {
    try {
      // Check cache first
      if (_cachedConfig != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheExpiry) {
        print('📦 DELIVERY FEE - Using cached configuration');
        return _cachedConfig;
      }

      print('🔄 DELIVERY FEE - Fetching active configuration from database');

      // Fetch active global configuration
      final response = await _supabase
          .from('delivery_fee_configs')
          .select()
          .eq('is_active', true)
          .eq('scope', 'GLOBAL')
          .maybeSingle();

      if (response != null) {
        _cachedConfig = DeliveryFeeConfig.fromJson(response);
        _cacheTimestamp = DateTime.now();

        print(
          '✅ DELIVERY FEE - Active configuration loaded: ${_cachedConfig!.configName}',
        );
        return _cachedConfig;
      } else {
        print('⚠️ DELIVERY FEE - No active configuration found');

        // Auto-create default configuration if none exists
        print('🔧 DELIVERY FEE - Auto-creating default configuration...');
        final setupSuccess =
            await DeliveryFeeSetupService.ensureDefaultConfigExists();

        if (setupSuccess) {
          // Try fetching again after creating default config
          final retryResponse = await _supabase
              .from('delivery_fee_configs')
              .select()
              .eq('is_active', true)
              .eq('scope', 'GLOBAL')
              .maybeSingle();

          if (retryResponse != null) {
            _cachedConfig = DeliveryFeeConfig.fromJson(retryResponse);
            _cacheTimestamp = DateTime.now();
            print('✅ DELIVERY FEE - Default configuration created and loaded');
            return _cachedConfig;
          }
        }

        print('❌ DELIVERY FEE - Failed to create default configuration');
        return null;
      }
    } catch (e) {
      print('❌ DELIVERY FEE - Error fetching configuration: $e');
      return _cachedConfig; // Return cached config if available
    }
  }

  /// Calculate delivery fee for given customer address
  /// Returns delivery fee amount or null if location not serviceable
  Future<Map<String, dynamic>> calculateDeliveryFee({
    required String customerAddress,
    required double orderSubtotal,
    String? sellerAddress,
  }) async {
    try {
      print('🧮 DELIVERY FEE - Calculating fee for address: $customerAddress');

      // Get active configuration
      final config = await getActiveConfig();
      if (config == null) {
        return {
          'success': false,
          'error': 'No delivery configuration available',
          'fee': 0.0,
        };
      }

      // Check free delivery threshold
      if (config.freeDeliveryThreshold != null &&
          orderSubtotal >= config.freeDeliveryThreshold!) {
        print(
          '🎉 DELIVERY FEE - Free delivery threshold met (₹${config.freeDeliveryThreshold})',
        );
        return {
          'success': true,
          'fee': 0.0,
          'reason': 'free_delivery_threshold',
          'threshold': config.freeDeliveryThreshold,
          'distance_km': 0.0,
        };
      }

      // Calculate distance
      final distanceResult = await _locationService.calculateDistance(
        origin:
            sellerAddress ??
            'Bangalore, Karnataka, India', // Default seller location
        destination: customerAddress,
        useRouting: config.useRouting,
      );

      if (!distanceResult['success']) {
        return {'success': false, 'error': distanceResult['error'], 'fee': 0.0};
      }

      double distanceKm = distanceResult['distance_km'];

      // Apply calibration multiplier if using straight-line distance
      if (!config.useRouting) {
        distanceKm *= config.calibrationMultiplier;
      }

      print('📏 DELIVERY FEE - Distance: ${distanceKm.toStringAsFixed(2)}km');

      // Check if location is serviceable
      if (distanceKm > config.maxServiceableDistanceKm) {
        print(
          '❌ DELIVERY FEE - Location not serviceable (${distanceKm.toStringAsFixed(2)}km > ${config.maxServiceableDistanceKm}km)',
        );
        return {
          'success': false,
          'error': 'Location not serviceable',
          'fee': 0.0,
          'distance_km': distanceKm,
          'max_distance': config.maxServiceableDistanceKm,
        };
      }

      // Find applicable tier and calculate fee
      final tier = _findApplicableTier(config.tierRates, distanceKm);
      if (tier == null) {
        return {
          'success': false,
          'error': 'No applicable pricing tier found',
          'fee': 0.0,
        };
      }

      double baseFee = tier.calculateFee(distanceKm);

      // Apply dynamic multipliers (peak hours, weather, demand)
      double finalFee = _applyDynamicMultipliers(
        baseFee,
        config.dynamicMultipliers,
      );

      // Apply min/max fee constraints
      finalFee = finalFee.clamp(config.minFee, config.maxFee);

      print(
        '💰 DELIVERY FEE - Calculated fee: ₹${finalFee.toStringAsFixed(0)} (base: ₹${baseFee.toStringAsFixed(0)})',
      );

      return {
        'success': true,
        'fee': finalFee,
        'distance_km': distanceKm,
        'tier': tier.displayRange,
        'base_fee': baseFee,
        'applied_multipliers': _getAppliedMultipliers(
          config.dynamicMultipliers,
        ),
        'config_name': config.configName,
      };
    } catch (e) {
      print('❌ DELIVERY FEE - Calculation error: $e');
      return {
        'success': false,
        'error': 'Failed to calculate delivery fee: $e',
        'fee': 0.0,
      };
    }
  }

  /// Check if location is serviceable
  Future<bool> isLocationServiceable(String address) async {
    try {
      final config = await getActiveConfig();
      if (config == null) return false;

      final distanceResult = await _locationService.calculateDistance(
        origin: 'Bangalore, Karnataka, India', // Default seller location
        destination: address,
        useRouting: config.useRouting,
      );

      if (!distanceResult['success']) return false;

      double distanceKm = distanceResult['distance_km'];
      if (!config.useRouting) {
        distanceKm *= config.calibrationMultiplier;
      }

      return distanceKm <= config.maxServiceableDistanceKm;
    } catch (e) {
      print('❌ DELIVERY FEE - Error checking serviceability: $e');
      return false;
    }
  }

  /// Clear cached configuration (force refresh)
  void clearCache() {
    _cachedConfig = null;
    _cacheTimestamp = null;
    print('🗑️ DELIVERY FEE - Cache cleared');
  }

  /// Find applicable pricing tier for given distance
  DeliveryFeeTier? _findApplicableTier(
    List<DeliveryFeeTier> tiers,
    double distanceKm,
  ) {
    for (final tier in tiers) {
      if (tier.appliesTo(distanceKm)) {
        return tier;
      }
    }
    return null;
  }

  /// Apply dynamic multipliers (peak hours, weather, demand)
  double _applyDynamicMultipliers(
    double baseFee,
    DeliveryFeeMultipliers multipliers,
  ) {
    double finalFee = baseFee;

    // Apply peak hours multiplier
    if (multipliers.peakHours.enabled && _isPeakHours(multipliers.peakHours)) {
      finalFee *= multipliers.peakHours.multiplier;
    }

    // Apply weather multiplier (if enabled)
    if (multipliers.weather.enabled) {
      finalFee *= multipliers.weather.multiplier;
    }

    // Apply demand multiplier (if enabled)
    if (multipliers.demand.enabled) {
      finalFee *= multipliers.demand.multiplier;
    }

    return finalFee;
  }

  /// Check if current time is within peak hours
  bool _isPeakHours(PeakHoursMultiplier peakHours) {
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);

    if (!peakHours.days.contains(currentDay.toLowerCase())) {
      return false;
    }

    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return currentTime.compareTo(peakHours.startTime) >= 0 &&
        currentTime.compareTo(peakHours.endTime) <= 0;
  }

  /// Get day name from weekday number
  String _getDayName(int weekday) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return days[weekday - 1];
  }

  /// Get list of applied multipliers for transparency
  List<String> _getAppliedMultipliers(DeliveryFeeMultipliers multipliers) {
    final applied = <String>[];

    if (multipliers.peakHours.enabled && _isPeakHours(multipliers.peakHours)) {
      applied.add('Peak Hours (${multipliers.peakHours.multiplier}x)');
    }

    if (multipliers.weather.enabled) {
      applied.add('Weather (${multipliers.weather.multiplier}x)');
    }

    if (multipliers.demand.enabled) {
      applied.add('High Demand (${multipliers.demand.multiplier}x)');
    }

    return applied;
  }
}
