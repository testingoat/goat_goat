import 'package:flutter/foundation.dart';
import '../models/delivery_fee_config.dart';
import '../supabase_service.dart';
import '../config/maps_config.dart';

/// AdminDeliveryConfigService - CRUD operations for delivery fee configurations
///
/// This service provides admin-only operations for managing delivery fee
/// configurations with real-time updates and optimistic locking.
///
/// Phase C.4 - Distance-based Delivery Fees - Phase 1 (Foundation)
class AdminDeliveryConfigService {
  static final AdminDeliveryConfigService _instance =
      AdminDeliveryConfigService._internal();
  factory AdminDeliveryConfigService() => _instance;
  AdminDeliveryConfigService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  /// Get all delivery fee configurations with optional filtering
  ///
  /// Returns list of configurations sorted by updated_at (newest first)
  Future<List<DeliveryFeeConfig>> getConfigs({
    String? scope,
    bool? isActive,
    int? limit,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '📋 Fetching delivery fee configs - scope: $scope, active: $isActive',
        );
      }

      var query = _supabaseService.client
          .from('delivery_fee_configs')
          .select('*');

      // Apply filters
      if (scope != null) {
        query = query.eq('scope', scope);
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      // Order by updated_at (newest first) and apply limit
      var orderedQuery = query.order('updated_at', ascending: false);

      if (limit != null) {
        orderedQuery = orderedQuery.limit(limit);
      }

      final response = await orderedQuery;

      final configs = response
          .map((json) => DeliveryFeeConfig.fromJson(json))
          .toList();

      if (kDebugMode) {
        print('✅ Retrieved ${configs.length} delivery fee configurations');
      }

      return configs;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching delivery fee configs: $e');
      }
      rethrow;
    }
  }

  /// Get a specific delivery fee configuration by ID
  Future<DeliveryFeeConfig?> getConfigById(String configId) async {
    try {
      if (kDebugMode) {
        print('📋 Fetching delivery fee config by ID: $configId');
      }

      final response = await _supabaseService.client
          .from('delivery_fee_configs')
          .select('*')
          .eq('id', configId)
          .maybeSingle();

      if (response == null) {
        if (kDebugMode) {
          print('⚠️ Delivery fee config not found: $configId');
        }
        return null;
      }

      final config = DeliveryFeeConfig.fromJson(response);

      if (kDebugMode) {
        print('✅ Retrieved delivery fee config: ${config.scope}');
      }

      return config;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching delivery fee config by ID: $e');
      }
      rethrow;
    }
  }

  /// Get active configuration for a specific scope
  ///
  /// Implements scope resolution: ZONE → CITY → GLOBAL
  Future<DeliveryFeeConfig?> getActiveConfig(String scope) async {
    try {
      if (kDebugMode) {
        print('📋 Fetching active config for scope: $scope');
      }

      // Try exact scope match first
      var response = await _supabaseService.client
          .from('delivery_fee_configs')
          .select('*')
          .eq('scope', scope)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        final config = DeliveryFeeConfig.fromJson(response);
        if (kDebugMode) {
          print('✅ Found exact scope match: ${config.scope}');
        }
        return config;
      }

      // If scope is ZONE:CITY-Z##, try CITY:CITY
      if (scope.startsWith('ZONE:')) {
        final parts = scope.split('-');
        if (parts.length > 1) {
          final cityScope = 'CITY:${parts[0].substring(5)}'; // Remove 'ZONE:'

          response = await _supabaseService.client
              .from('delivery_fee_configs')
              .select('*')
              .eq('scope', cityScope)
              .eq('is_active', true)
              .maybeSingle();

          if (response != null) {
            final config = DeliveryFeeConfig.fromJson(response);
            if (kDebugMode) {
              print('✅ Found city fallback: ${config.scope}');
            }
            return config;
          }
        }
      }

      // If scope is CITY:XXX, try GLOBAL
      if (scope.startsWith('CITY:') || scope.startsWith('ZONE:')) {
        response = await _supabaseService.client
            .from('delivery_fee_configs')
            .select('*')
            .eq('scope', 'GLOBAL')
            .eq('is_active', true)
            .maybeSingle();

        if (response != null) {
          final config = DeliveryFeeConfig.fromJson(response);
          if (kDebugMode) {
            print('✅ Found global fallback: ${config.scope}');
          }
          return config;
        }
      }

      if (kDebugMode) {
        print('⚠️ No active config found for scope: $scope');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching active config: $e');
      }
      rethrow;
    }
  }

  /// Create a new delivery fee configuration
  Future<DeliveryFeeConfig> createConfig(DeliveryFeeConfig config) async {
    try {
      if (kDebugMode) {
        print('➕ Creating delivery fee config: ${config.scope}');
      }

      // Validate configuration
      if (!config.isValid) {
        throw ArgumentError('Invalid delivery fee configuration');
      }

      // Check for existing active config with same scope
      final existingConfig = await getActiveConfig(config.scope);
      if (existingConfig != null && config.isActive) {
        throw StateError(
          'Active configuration already exists for scope: ${config.scope}',
        );
      }

      final configData = config.toJson();
      configData.remove('id'); // Let database generate ID
      configData.remove('created_at'); // Let database set timestamp
      configData.remove('updated_at'); // Let database set timestamp

      final response = await _supabaseService.client
          .from('delivery_fee_configs')
          .insert(configData)
          .select()
          .single();

      final createdConfig = DeliveryFeeConfig.fromJson(response);

      if (kDebugMode) {
        print('✅ Created delivery fee config: ${createdConfig.id}');
      }

      return createdConfig;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creating delivery fee config: $e');
      }
      rethrow;
    }
  }

  /// Update an existing delivery fee configuration with optimistic locking
  Future<DeliveryFeeConfig> updateConfig(
    DeliveryFeeConfig config,
    String adminUserId,
  ) async {
    try {
      if (kDebugMode) {
        print(
          '✏️ Updating delivery fee config: ${config.id} (version ${config.version})',
        );
      }

      // Validate configuration
      if (!config.isValid) {
        throw ArgumentError('Invalid delivery fee configuration');
      }

      final configData = config.toJson();
      configData['last_modified_by'] = adminUserId;
      configData.remove('created_at'); // Don't update creation timestamp

      // Optimistic locking: update only if version matches
      final response = await _supabaseService.client
          .from('delivery_fee_configs')
          .update(configData)
          .eq('id', config.id)
          .eq('version', config.version) // Optimistic lock
          .select()
          .maybeSingle();

      if (response == null) {
        throw StateError(
          'Configuration was modified by another admin. Please reload and try again.',
        );
      }

      final updatedConfig = DeliveryFeeConfig.fromJson(response);

      if (kDebugMode) {
        print(
          '✅ Updated delivery fee config: ${updatedConfig.id} (version ${updatedConfig.version})',
        );
      }

      return updatedConfig;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating delivery fee config: $e');
      }
      rethrow;
    }
  }

  /// Toggle active status of a configuration
  Future<DeliveryFeeConfig> toggleActive(
    String configId,
    bool isActive,
    String adminUserId,
  ) async {
    try {
      if (kDebugMode) {
        print('🔄 Toggling config active status: $configId → $isActive');
      }

      // Get current config for optimistic locking
      final currentConfig = await getConfigById(configId);
      if (currentConfig == null) {
        throw StateError('Configuration not found: $configId');
      }

      // If activating, check for existing active config with same scope
      if (isActive) {
        final existingActive = await getActiveConfig(currentConfig.scope);
        if (existingActive != null && existingActive.id != configId) {
          throw StateError(
            'Another active configuration exists for scope: ${currentConfig.scope}',
          );
        }
      }

      final updatedConfig = currentConfig.copyWith(
        isActive: isActive,
        lastModifiedBy: adminUserId,
      );

      return await updateConfig(updatedConfig, adminUserId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error toggling config active status: $e');
      }
      rethrow;
    }
  }

  /// Delete a delivery fee configuration
  Future<bool> deleteConfig(String configId, String adminUserId) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting delivery fee config: $configId');
      }

      // Check if config exists and get current version
      final currentConfig = await getConfigById(configId);
      if (currentConfig == null) {
        if (kDebugMode) {
          print('⚠️ Config not found for deletion: $configId');
        }
        return false;
      }

      // Prevent deletion of active GLOBAL config (safety check)
      if (currentConfig.scope == 'GLOBAL' && currentConfig.isActive) {
        throw StateError('Cannot delete active GLOBAL configuration');
      }

      await _supabaseService.client
          .from('delivery_fee_configs')
          .delete()
          .eq('id', configId)
          .eq('version', currentConfig.version); // Optimistic lock

      if (kDebugMode) {
        print('✅ Deleted delivery fee config: $configId');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting delivery fee config: $e');
      }
      rethrow;
    }
  }

  /// Duplicate an existing configuration with new scope
  Future<DeliveryFeeConfig> duplicateConfig(
    String sourceConfigId,
    String newScope,
    String newConfigName,
    String adminUserId,
  ) async {
    try {
      if (kDebugMode) {
        print('📋 Duplicating config: $sourceConfigId → $newScope');
      }

      final sourceConfig = await getConfigById(sourceConfigId);
      if (sourceConfig == null) {
        throw StateError('Source configuration not found: $sourceConfigId');
      }

      final duplicatedConfig = sourceConfig.copyWith(
        id: '', // Will be generated by database
        scope: newScope,
        configName: newConfigName,
        isActive: false, // Start as inactive
        version: 1, // Reset version
        lastModifiedBy: adminUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      return await createConfig(duplicatedConfig);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error duplicating delivery fee config: $e');
      }
      rethrow;
    }
  }

  /// Get configuration history (if history table exists)
  /// This is a placeholder for future Phase 5 implementation
  Future<List<Map<String, dynamic>>> getConfigHistory(String configId) async {
    // TODO: Implement in Phase 5 when history table is added
    if (kDebugMode) {
      print('📚 Config history requested for: $configId (not implemented yet)');
    }
    return [];
  }

  /// Validate configuration data
  bool validateConfig(DeliveryFeeConfig config) {
    try {
      // Basic validation
      if (!config.isValid) return false;

      // Validate tier rates
      if (config.tierRates.isEmpty) return false;

      // Check tier continuity and non-overlap
      final sortedTiers = List<DeliveryFeeTier>.from(config.tierRates)
        ..sort((a, b) => a.minKm.compareTo(b.minKm));

      for (int i = 0; i < sortedTiers.length; i++) {
        final tier = sortedTiers[i];

        // Check tier validity
        if (tier.maxKm != null && tier.minKm >= tier.maxKm!) {
          return false; // Invalid range
        }

        // Check continuity (except for last tier)
        if (i < sortedTiers.length - 1) {
          final nextTier = sortedTiers[i + 1];
          if (tier.maxKm == null || tier.maxKm != nextTier.minKm) {
            return false; // Gap or overlap in tiers
          }
        }
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error validating config: $e');
      }
      return false;
    }
  }

  /// Check if service is available (feature flag)
  bool isAvailable() {
    return kEnableAdminDeliveryRates;
  }
}
