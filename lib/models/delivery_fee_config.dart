/// DeliveryFeeConfig - Data model for admin-managed delivery fee configurations
///
/// This model represents the delivery fee configuration that administrators can
/// modify in real-time through the admin panel. Supports scope-based targeting
/// (GLOBAL/CITY/ZONE) and dynamic pricing multipliers.
///
/// Phase C.4 - Distance-based Delivery Fees - Phase 1 (Foundation)
class DeliveryFeeConfig {
  final String id;
  final String scope; // 'GLOBAL' | 'CITY:BLR' | 'ZONE:BLR-Z23'
  final String configName;
  final bool isActive;
  final bool useRouting;
  final double calibrationMultiplier;
  final List<DeliveryFeeTier> tierRates;
  final DeliveryFeeMultipliers dynamicMultipliers;
  final double minFee;
  final double maxFee;
  final double? freeDeliveryThreshold;
  final double maxServiceableDistanceKm;
  final int version;
  final String? lastModifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeliveryFeeConfig({
    required this.id,
    required this.scope,
    this.configName = 'default',
    this.isActive = true,
    this.useRouting = true,
    this.calibrationMultiplier = 1.3,
    required this.tierRates,
    required this.dynamicMultipliers,
    this.minFee = 15.0,
    this.maxFee = 99.0,
    this.freeDeliveryThreshold = 500.0,
    this.maxServiceableDistanceKm = 15.0,
    this.version = 1,
    this.lastModifiedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create DeliveryFeeConfig from Supabase JSON
  factory DeliveryFeeConfig.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeConfig(
      id: json['id'] ?? '',
      scope: json['scope'] ?? 'GLOBAL',
      configName: json['config_name'] ?? 'default',
      isActive: json['is_active'] ?? true,
      useRouting: json['use_routing'] ?? true,
      calibrationMultiplier: (json['calibration_multiplier'] ?? 1.3).toDouble(),
      tierRates: _parseTierRates(json['tier_rates']),
      dynamicMultipliers: DeliveryFeeMultipliers.fromJson(
        json['dynamic_multipliers'] ?? {},
      ),
      minFee: (json['min_fee'] ?? 15.0).toDouble(),
      maxFee: (json['max_fee'] ?? 99.0).toDouble(),
      freeDeliveryThreshold: json['free_delivery_threshold']?.toDouble(),
      maxServiceableDistanceKm: (json['max_serviceable_distance_km'] ?? 15.0)
          .toDouble(),
      version: json['version'] ?? 1,
      lastModifiedBy: json['last_modified_by'],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  /// Convert DeliveryFeeConfig to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scope': scope,
      'config_name': configName,
      'is_active': isActive,
      'use_routing': useRouting,
      'calibration_multiplier': calibrationMultiplier,
      'tier_rates': tierRates.map((tier) => tier.toJson()).toList(),
      'dynamic_multipliers': dynamicMultipliers.toJson(),
      'min_fee': minFee,
      'max_fee': maxFee,
      'free_delivery_threshold': freeDeliveryThreshold,
      'max_serviceable_distance_km': maxServiceableDistanceKm,
      'version': version,
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  DeliveryFeeConfig copyWith({
    String? id,
    String? scope,
    String? configName,
    bool? isActive,
    bool? useRouting,
    double? calibrationMultiplier,
    List<DeliveryFeeTier>? tierRates,
    DeliveryFeeMultipliers? dynamicMultipliers,
    double? minFee,
    double? maxFee,
    double? freeDeliveryThreshold,
    double? maxServiceableDistanceKm,
    int? version,
    String? lastModifiedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryFeeConfig(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      configName: configName ?? this.configName,
      isActive: isActive ?? this.isActive,
      useRouting: useRouting ?? this.useRouting,
      calibrationMultiplier:
          calibrationMultiplier ?? this.calibrationMultiplier,
      tierRates: tierRates ?? this.tierRates,
      dynamicMultipliers: dynamicMultipliers ?? this.dynamicMultipliers,
      minFee: minFee ?? this.minFee,
      maxFee: maxFee ?? this.maxFee,
      freeDeliveryThreshold:
          freeDeliveryThreshold ?? this.freeDeliveryThreshold,
      maxServiceableDistanceKm:
          maxServiceableDistanceKm ?? this.maxServiceableDistanceKm,
      version: version ?? this.version,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Increment version for optimistic locking
  DeliveryFeeConfig incrementVersion() {
    return copyWith(version: version + 1, updatedAt: DateTime.now());
  }

  /// Check if configuration is valid
  bool get isValid {
    return id.isNotEmpty &&
        scope.isNotEmpty &&
        tierRates.isNotEmpty &&
        minFee >= 0 &&
        maxFee >= minFee &&
        maxServiceableDistanceKm > 0 &&
        calibrationMultiplier > 0;
  }

  /// Get scope type (GLOBAL, CITY, ZONE)
  String get scopeType {
    if (scope == 'GLOBAL') return 'GLOBAL';
    if (scope.startsWith('CITY:')) return 'CITY';
    if (scope.startsWith('ZONE:')) return 'ZONE';
    return 'UNKNOWN';
  }

  /// Get scope value (e.g., 'BLR' from 'CITY:BLR')
  String? get scopeValue {
    if (scope == 'GLOBAL') return null;
    final parts = scope.split(':');
    return parts.length > 1 ? parts[1] : null;
  }

  /// Parse tier rates from JSON
  static List<DeliveryFeeTier> _parseTierRates(dynamic tierRatesJson) {
    if (tierRatesJson == null) return [];

    final List<dynamic> tierList = tierRatesJson is String
        ? [] // Handle empty string case
        : (tierRatesJson as List<dynamic>? ?? []);

    return tierList
        .map((tier) => DeliveryFeeTier.fromJson(tier as Map<String, dynamic>))
        .toList();
  }

  @override
  String toString() {
    return 'DeliveryFeeConfig(id: $id, scope: $scope, version: $version, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryFeeConfig &&
        other.id == id &&
        other.version == version;
  }

  @override
  int get hashCode => Object.hash(id, version);
}

/// DeliveryFeeTier - Individual distance-based pricing tier
class DeliveryFeeTier {
  final double minKm;
  final double? maxKm; // null for unlimited (last tier)
  final double? fee; // Fixed fee for this tier
  final double? baseFee; // Base fee for unlimited tier
  final double? perKmFee; // Per-km fee for unlimited tier

  const DeliveryFeeTier({
    required this.minKm,
    this.maxKm,
    this.fee,
    this.baseFee,
    this.perKmFee,
  });

  factory DeliveryFeeTier.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeTier(
      minKm: (json['min_km'] ?? 0.0).toDouble(),
      maxKm: json['max_km']?.toDouble(),
      fee: json['fee']?.toDouble(),
      baseFee: json['base_fee']?.toDouble(),
      perKmFee: json['per_km_fee']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'min_km': minKm,
      'max_km': maxKm,
      'fee': fee,
      'base_fee': baseFee,
      'per_km_fee': perKmFee,
    };
  }

  /// Check if this tier applies to the given distance
  bool appliesTo(double distanceKm) {
    if (distanceKm < minKm) return false;
    if (maxKm == null) return true; // Unlimited tier
    return distanceKm <= maxKm!;
  }

  /// Calculate fee for this tier
  double calculateFee(double distanceKm) {
    if (!appliesTo(distanceKm)) return 0.0;

    if (fee != null) {
      // Fixed fee tier
      return fee!;
    } else if (baseFee != null && perKmFee != null) {
      // Variable fee tier (base + per km)
      final extraKm = distanceKm - minKm;
      return baseFee! + (extraKm * perKmFee!);
    }

    return 0.0;
  }

  /// Get display string for this tier
  String get displayRange {
    if (maxKm == null) {
      return '${minKm.toStringAsFixed(0)}km+';
    }
    return '${minKm.toStringAsFixed(0)}-${maxKm!.toStringAsFixed(0)}km';
  }

  @override
  String toString() {
    return 'DeliveryFeeTier($displayRange: ${fee ?? '$baseFee+$perKmFee/km'})';
  }
}

/// DeliveryFeeMultipliers - Dynamic pricing multipliers
class DeliveryFeeMultipliers {
  final PeakHoursMultiplier peakHours;
  final WeatherMultiplier weather;
  final DemandMultiplier demand;

  const DeliveryFeeMultipliers({
    required this.peakHours,
    required this.weather,
    required this.demand,
  });

  factory DeliveryFeeMultipliers.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeMultipliers(
      peakHours: PeakHoursMultiplier.fromJson(json['peak_hours'] ?? {}),
      weather: WeatherMultiplier.fromJson(json['weather'] ?? {}),
      demand: DemandMultiplier.fromJson(json['demand'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'peak_hours': peakHours.toJson(),
      'weather': weather.toJson(),
      'demand': demand.toJson(),
    };
  }

  /// Get default multipliers (all disabled)
  static DeliveryFeeMultipliers get defaultMultipliers {
    return DeliveryFeeMultipliers(
      peakHours: PeakHoursMultiplier.disabled(),
      weather: WeatherMultiplier.disabled(),
      demand: DemandMultiplier.disabled(),
    );
  }
}

/// PeakHoursMultiplier - Time-based pricing multiplier
class PeakHoursMultiplier {
  final bool enabled;
  final String startTime; // "18:00"
  final String endTime; // "22:00"
  final double multiplier; // 1.1 = 10% increase
  final List<String> days; // ["monday", "tuesday", ...]

  const PeakHoursMultiplier({
    this.enabled = false,
    this.startTime = "18:00",
    this.endTime = "22:00",
    this.multiplier = 1.1,
    this.days = const ["monday", "tuesday", "wednesday", "thursday", "friday"],
  });

  factory PeakHoursMultiplier.fromJson(Map<String, dynamic> json) {
    return PeakHoursMultiplier(
      enabled: json['enabled'] ?? false,
      startTime: json['start_time'] ?? "18:00",
      endTime: json['end_time'] ?? "22:00",
      multiplier: (json['multiplier'] ?? 1.1).toDouble(),
      days: List<String>.from(
        json['days'] ??
            ["monday", "tuesday", "wednesday", "thursday", "friday"],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'start_time': startTime,
      'end_time': endTime,
      'multiplier': multiplier,
      'days': days,
    };
  }

  static PeakHoursMultiplier disabled() {
    return const PeakHoursMultiplier(enabled: false);
  }
}

/// WeatherMultiplier - Weather-based pricing multiplier
class WeatherMultiplier {
  final bool enabled;
  final double rainThresholdMm; // 2.0 mm
  final double multiplier; // 1.1 = 10% increase

  const WeatherMultiplier({
    this.enabled = false,
    this.rainThresholdMm = 2.0,
    this.multiplier = 1.1,
  });

  factory WeatherMultiplier.fromJson(Map<String, dynamic> json) {
    return WeatherMultiplier(
      enabled: json['enabled'] ?? false,
      rainThresholdMm: (json['rain_threshold_mm'] ?? 2.0).toDouble(),
      multiplier: (json['multiplier'] ?? 1.1).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'rain_threshold_mm': rainThresholdMm,
      'multiplier': multiplier,
    };
  }

  static WeatherMultiplier disabled() {
    return const WeatherMultiplier(enabled: false);
  }
}

/// DemandMultiplier - Supply/demand-based pricing multiplier
class DemandMultiplier {
  final bool enabled;
  final double lowSupplyThreshold; // 0.7 = 70% supply/demand ratio
  final double multiplier; // 1.1 = 10% increase

  const DemandMultiplier({
    this.enabled = false,
    this.lowSupplyThreshold = 0.7,
    this.multiplier = 1.1,
  });

  factory DemandMultiplier.fromJson(Map<String, dynamic> json) {
    return DemandMultiplier(
      enabled: json['enabled'] ?? false,
      lowSupplyThreshold: (json['low_supply_threshold'] ?? 0.7).toDouble(),
      multiplier: (json['multiplier'] ?? 1.1).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'low_supply_threshold': lowSupplyThreshold,
      'multiplier': multiplier,
    };
  }

  static DemandMultiplier disabled() {
    return const DemandMultiplier(enabled: false);
  }
}
