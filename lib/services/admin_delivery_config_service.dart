import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_fee_config.dart';
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

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Test Supabase connection and permissions
  /// This method helps diagnose connection and RLS policy issues
  Future<Map<String, dynamic>> testConnection() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
    };

    try {
      // Test 1: Basic connection
      if (kDebugMode) {
        print('🔍 Testing Supabase connection...');
      }

      final client = _supabase;
      results['tests']['client_available'] = true;
      results['tests']['supabase_url'] =
          'https://oaynfzqjielnsipttzbs.supabase.co';

      // Test 2: Read access to delivery_fee_configs
      try {
        final readResponse = await client
            .from('delivery_fee_configs')
            .select('id, scope, config_name')
            .limit(1);

        results['tests']['read_access'] = true;
        results['tests']['existing_configs_count'] = readResponse.length;
        if (kDebugMode) {
          print(
            '✅ Read access successful: ${readResponse.length} configs found',
          );
        }
      } catch (e) {
        results['tests']['read_access'] = false;
        results['tests']['read_error'] = e.toString();
        if (kDebugMode) {
          print('❌ Read access failed: $e');
        }
      }

      // Test 3: Write access (insert test)
      try {
        final testConfig = {
          'scope': 'TEST_CONNECTION',
          'config_name':
              'Connection Test ${DateTime.now().millisecondsSinceEpoch}',
          'is_active': false,
          'use_routing': true,
          'tier_rates': [
            {'min_distance': 0, 'max_distance': 5, 'fee': 10},
          ],
          'min_fee': 10,
          'max_fee': 50,
          'free_delivery_threshold': 500,
          'max_delivery_distance': 15,
          'distance_calibration_factor': 1.0,
          'dynamic_multipliers': {},
          'last_modified_by': 'connection_test',
          'version': 1,
        };

        final insertResponse = await client
            .from('delivery_fee_configs')
            .insert(testConfig)
            .select()
            .single();

        results['tests']['write_access'] = true;
        results['tests']['test_config_id'] = insertResponse['id'];

        if (kDebugMode) {
          print(
            '✅ Write access successful: Created test config ${insertResponse['id']}',
          );
        }

        // Clean up test config
        try {
          await client
              .from('delivery_fee_configs')
              .delete()
              .eq('id', insertResponse['id']);
          results['tests']['cleanup_successful'] = true;
          if (kDebugMode) {
            print('🧹 Test config cleaned up successfully');
          }
        } catch (cleanupError) {
          results['tests']['cleanup_successful'] = false;
          results['tests']['cleanup_error'] = cleanupError.toString();
          if (kDebugMode) {
            print('⚠️ Test config cleanup failed: $cleanupError');
          }
        }
      } catch (e) {
        results['tests']['write_access'] = false;
        results['tests']['write_error'] = e.toString();
        if (kDebugMode) {
          print('❌ Write access failed: $e');
        }
      }

      results['overall_status'] = 'completed';
    } catch (e) {
      results['overall_status'] = 'failed';
      results['error'] = e.toString();
      if (kDebugMode) {
        print('❌ Connection test failed: $e');
      }
    }

    return results;
  }

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

      var query = _supabase.from('delivery_fee_configs').select('*');

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

      final response = await _supabase
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
      var response = await _supabase
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

          response = await _supabase
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
        response = await _supabase
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

      // Validate configuration for new config (ID not required)
      if (!_validateNewConfig(config)) {
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

      final response = await _supabase
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
      // Only set last_modified_by if adminUserId looks like a valid UUID
      if (adminUserId.length == 36 && adminUserId.contains('-')) {
        configData['last_modified_by'] = adminUserId;
      } else {
        configData.remove('last_modified_by'); // Let database handle it
      }
      configData.remove('created_at'); // Don't update creation timestamp

      // Optimistic locking: update only if version matches
      final response = await _supabase
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

      await _supabase
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

  /// Validate configuration data for new configurations (ID not required)
  bool _validateNewConfig(DeliveryFeeConfig config) {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG: Validating new config - scope: ${config.scope}');
      }

      // Basic validation (excluding ID check for new configs)
      if (config.scope.isEmpty ||
          config.tierRates.isEmpty ||
          config.minFee < 0 ||
          config.maxFee < config.minFee ||
          config.maxServiceableDistanceKm <= 0 ||
          config.calibrationMultiplier <= 0) {
        if (kDebugMode) {
          print('🔍 DEBUG: Basic validation failed');
          print('  - scope: ${config.scope}');
          print('  - tierRates.length: ${config.tierRates.length}');
          print('  - minFee: ${config.minFee}');
          print('  - maxFee: ${config.maxFee}');
          print(
            '  - maxServiceableDistanceKm: ${config.maxServiceableDistanceKm}',
          );
          print('  - calibrationMultiplier: ${config.calibrationMultiplier}');
        }
        return false;
      }

      // Check tier continuity and non-overlap
      final sortedTiers = List<DeliveryFeeTier>.from(config.tierRates)
        ..sort((a, b) => a.minKm.compareTo(b.minKm));

      for (int i = 0; i < sortedTiers.length; i++) {
        final tier = sortedTiers[i];

        // Check tier validity
        if (tier.maxKm != null && tier.minKm >= tier.maxKm!) {
          if (kDebugMode) {
            print(
              '🔍 DEBUG: Invalid tier range: ${tier.minKm}km - ${tier.maxKm}km',
            );
          }
          return false; // Invalid range
        }

        // Check continuity (except for last tier)
        if (i < sortedTiers.length - 1) {
          final nextTier = sortedTiers[i + 1];
          if (tier.maxKm == null) {
            if (kDebugMode) {
              print(
                '🔍 DEBUG: Unlimited tier found at position $i (should be last)',
              );
            }
            return false; // Only last tier can be unlimited
          }
          if (tier.maxKm != nextTier.minKm) {
            if (kDebugMode) {
              print(
                '🔍 DEBUG: Gap/overlap in tiers: ${tier.maxKm}km ≠ ${nextTier.minKm}km',
              );
            }
            return false; // Gap or overlap in tiers
          }
        }
      }

      if (kDebugMode) {
        print('🔍 DEBUG: New config validation passed');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error validating new config: $e');
      }
      return false;
    }
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
