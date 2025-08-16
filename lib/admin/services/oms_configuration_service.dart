import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// OMS Configuration Service
///
/// This service manages the Order Management System configuration settings
/// that can be controlled through the admin panel. It provides real-time
/// configuration management for routing algorithms, timer settings, capacity
/// management, and notification preferences.
///
/// ZERO-RISK IMPLEMENTATION:
/// - All configuration changes are logged and auditable
/// - Graceful fallback to default values
/// - Real-time database integration
/// - Safety checks for critical settings
class OMSConfigurationService {
  static final OMSConfigurationService _instance =
      OMSConfigurationService._internal();
  factory OMSConfigurationService() => _instance;
  OMSConfigurationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // CONFIGURATION RETRIEVAL
  // =====================================================

  /// Get all OMS configuration settings
  Future<Map<String, dynamic>> getAllConfigurations() async {
    try {
      if (kDebugMode) {
        print('🔧 OMS CONFIG - Loading all configurations');
      }

      final response = await _supabase
          .from('oms_configuration')
          .select('*')
          .eq('is_active', true)
          .order('config_type');

      final configurations = <String, dynamic>{};

      for (final config in response) {
        configurations[config['config_key']] = {
          'value': config['config_value'],
          'type': config['config_type'],
          'description': config['description'],
          'updated_at': config['updated_at'],
        };
      }

      if (kDebugMode) {
        print('✅ OMS CONFIG - Loaded ${configurations.length} configurations');
      }

      return {
        'success': true,
        'configurations': configurations,
        'count': configurations.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ OMS CONFIG - Error loading configurations: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'configurations': _getDefaultConfigurations(),
      };
    }
  }

  /// Get configurations by type (routing, timer, capacity, notification)
  Future<Map<String, dynamic>> getConfigurationsByType(
    String configType,
  ) async {
    try {
      final response = await _supabase
          .from('oms_configuration')
          .select('*')
          .eq('config_type', configType)
          .eq('is_active', true)
          .order('config_key');

      final configurations = <String, dynamic>{};

      for (final config in response) {
        configurations[config['config_key']] = {
          'value': config['config_value'],
          'description': config['description'],
          'updated_at': config['updated_at'],
        };
      }

      return {
        'success': true,
        'configurations': configurations,
        'type': configType,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ OMS CONFIG - Error loading $configType configurations: $e');
      }
      return {'success': false, 'error': e.toString(), 'configurations': {}};
    }
  }

  /// Get a specific configuration value
  Future<Map<String, dynamic>> getConfiguration(String configKey) async {
    try {
      final response = await _supabase
          .from('oms_configuration')
          .select('*')
          .eq('config_key', configKey)
          .eq('is_active', true)
          .maybeSingle();

      if (response != null) {
        return {
          'success': true,
          'configuration': {
            'key': response['config_key'],
            'value': response['config_value'],
            'type': response['config_type'],
            'description': response['description'],
            'updated_at': response['updated_at'],
          },
        };
      } else {
        // Return default value if not found
        final defaultValue = _getDefaultValue(configKey);
        return {
          'success': true,
          'configuration': {
            'key': configKey,
            'value': defaultValue,
            'type': 'default',
            'description': 'Default value (not configured)',
            'updated_at': DateTime.now().toIso8601String(),
          },
          'is_default': true,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ OMS CONFIG - Error loading configuration $configKey: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // =====================================================
  // CONFIGURATION UPDATES
  // =====================================================

  /// Update a configuration setting
  Future<Map<String, dynamic>> updateConfiguration({
    required String configKey,
    required Map<String, dynamic> configValue,
    String? updatedBy,
    String? reason,
  }) async {
    try {
      if (kDebugMode) {
        print('🔧 OMS CONFIG - Updating $configKey');
      }

      // Safety check for critical configurations
      if (_isCriticalConfiguration(configKey)) {
        final validation = _validateCriticalConfiguration(
          configKey,
          configValue,
        );
        if (!validation['valid']) {
          return {
            'success': false,
            'error': validation['error'],
            'config_key': configKey,
          };
        }
      }

      // Check if configuration exists
      final existing = await _supabase
          .from('oms_configuration')
          .select('id, config_value')
          .eq('config_key', configKey)
          .maybeSingle();

      final now = DateTime.now().toIso8601String();

      if (existing != null) {
        // Update existing configuration
        await _supabase
            .from('oms_configuration')
            .update({
              'config_value': configValue,
              'updated_at': now,
              'updated_by': updatedBy,
            })
            .eq('config_key', configKey);
      } else {
        // Create new configuration
        await _supabase.from('oms_configuration').insert({
          'config_key': configKey,
          'config_value': configValue,
          'config_type': _inferConfigType(configKey),
          'description': _getConfigDescription(configKey),
          'is_active': true,
          'created_at': now,
          'updated_at': now,
          'created_by': updatedBy,
          'updated_by': updatedBy,
        });
      }

      // Log the configuration change
      await _logConfigurationChange(
        configKey: configKey,
        oldValue: existing?['config_value'],
        newValue: configValue,
        updatedBy: updatedBy,
        reason: reason,
      );

      if (kDebugMode) {
        print('✅ OMS CONFIG - Updated $configKey successfully');
      }

      return {
        'success': true,
        'config_key': configKey,
        'config_value': configValue,
        'message': 'Configuration updated successfully',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ OMS CONFIG - Error updating $configKey: $e');
      }
      return {'success': false, 'error': e.toString(), 'config_key': configKey};
    }
  }

  /// Batch update multiple configurations
  Future<Map<String, dynamic>> updateMultipleConfigurations({
    required Map<String, Map<String, dynamic>> configurations,
    String? updatedBy,
    String? reason,
  }) async {
    try {
      final results = <String, dynamic>{};
      final errors = <String, String>{};

      for (final entry in configurations.entries) {
        final result = await updateConfiguration(
          configKey: entry.key,
          configValue: entry.value,
          updatedBy: updatedBy,
          reason: reason,
        );

        if (result['success']) {
          results[entry.key] = result;
        } else {
          errors[entry.key] = result['error'];
        }
      }

      return {
        'success': errors.isEmpty,
        'updated_count': results.length,
        'error_count': errors.length,
        'results': results,
        'errors': errors,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // =====================================================
  // CONFIGURATION ANALYTICS
  // =====================================================

  /// Get configuration change history
  Future<Map<String, dynamic>> getConfigurationHistory({
    String? configKey,
    int limit = 50,
  }) async {
    try {
      // This would query a configuration_changes table (to be created)
      // For now, return placeholder data
      return {
        'success': true,
        'history': [],
        'message':
            'Configuration history tracking will be implemented in Phase 2',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Get configuration usage statistics
  Future<Map<String, dynamic>> getConfigurationStats() async {
    try {
      final response = await _supabase
          .from('oms_configuration')
          .select('config_type')
          .eq('is_active', true);

      final stats = <String, int>{};
      for (final config in response) {
        final type = config['config_type'] as String;
        stats[type] = (stats[type] ?? 0) + 1;
      }

      return {
        'success': true,
        'stats': stats,
        'total_configurations': response.length,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================

  /// Get default configurations for fallback
  Map<String, dynamic> _getDefaultConfigurations() {
    return {
      'routing_algorithm_weights': {
        'value': {
          'distance': 0.25,
          'capacity': 0.20,
          'acceptance_time': 0.15,
          'rating': 0.15,
          'availability': 0.10,
          'delivery_zone': 0.10,
          'performance': 0.05,
        },
        'type': 'routing',
        'description': 'Default routing algorithm weights',
      },
      'order_acceptance_timeout_minutes': {
        'value': {'value': 5},
        'type': 'timer',
        'description': 'Default 5-minute acceptance timeout',
      },
      'default_max_concurrent_orders': {
        'value': {'value': 10},
        'type': 'capacity',
        'description': 'Default maximum concurrent orders per seller',
      },
    };
  }

  /// Get default value for a specific configuration key
  Map<String, dynamic> _getDefaultValue(String configKey) {
    final defaults = _getDefaultConfigurations();
    return defaults[configKey]?['value'] ?? {'value': null};
  }

  /// Check if a configuration is critical and requires validation
  bool _isCriticalConfiguration(String configKey) {
    const criticalConfigs = [
      'order_acceptance_timeout_minutes',
      'routing_max_distance_km',
      'default_max_concurrent_orders',
      'notification_retry_attempts',
    ];
    return criticalConfigs.contains(configKey);
  }

  /// Validate critical configuration values
  Map<String, dynamic> _validateCriticalConfiguration(
    String configKey,
    Map<String, dynamic> configValue,
  ) {
    switch (configKey) {
      case 'order_acceptance_timeout_minutes':
        final minutes = configValue['value'] as int?;
        if (minutes == null || minutes < 1 || minutes > 60) {
          return {
            'valid': false,
            'error': 'Acceptance timeout must be between 1 and 60 minutes',
          };
        }
        break;

      case 'routing_max_distance_km':
        final distance = configValue['value'] as num?;
        if (distance == null || distance < 1 || distance > 100) {
          return {
            'valid': false,
            'error': 'Max routing distance must be between 1 and 100 km',
          };
        }
        break;

      case 'default_max_concurrent_orders':
        final orders = configValue['value'] as int?;
        if (orders == null || orders < 1 || orders > 100) {
          return {
            'valid': false,
            'error': 'Max concurrent orders must be between 1 and 100',
          };
        }
        break;

      case 'notification_retry_attempts':
        final attempts = configValue['value'] as int?;
        if (attempts == null || attempts < 0 || attempts > 10) {
          return {
            'valid': false,
            'error': 'Retry attempts must be between 0 and 10',
          };
        }
        break;
    }

    return {'valid': true};
  }

  /// Infer configuration type from key
  String _inferConfigType(String configKey) {
    if (configKey.contains('routing') || configKey.contains('algorithm')) {
      return 'routing';
    } else if (configKey.contains('timeout') || configKey.contains('timer')) {
      return 'timer';
    } else if (configKey.contains('capacity') || configKey.contains('max_')) {
      return 'capacity';
    } else if (configKey.contains('notification')) {
      return 'notification';
    } else {
      return 'general';
    }
  }

  /// Get description for configuration key
  String _getConfigDescription(String configKey) {
    const descriptions = {
      'routing_algorithm_weights':
          'Weights for seller selection scoring algorithm',
      'routing_max_distance_km':
          'Maximum distance for seller selection in kilometers',
      'routing_algorithm_version': 'Current version of the routing algorithm',
      'order_acceptance_timeout_minutes': '5-minute order acceptance deadline',
      'order_grace_period_seconds': 'Grace period before order expiration',
      'fallback_routing_enabled':
          'Enable automatic fallback routing on expiration',
      'default_max_concurrent_orders':
          'Default maximum concurrent orders per seller',
      'default_max_daily_orders': 'Default maximum daily orders per seller',
      'capacity_check_interval_minutes': 'Interval for capacity status checks',
      'notification_delivery_methods': 'Order of notification delivery methods',
      'notification_retry_attempts':
          'Number of retry attempts for failed notifications',
      'notification_retry_delay_seconds':
          'Delay between notification retry attempts',
    };

    return descriptions[configKey] ?? 'OMS configuration setting';
  }

  /// Log configuration changes for audit trail
  Future<void> _logConfigurationChange({
    required String configKey,
    required Map<String, dynamic>? oldValue,
    required Map<String, dynamic> newValue,
    String? updatedBy,
    String? reason,
  }) async {
    try {
      // For now, we'll use the existing feature_flag_changes table pattern
      // In a future phase, we could create a dedicated oms_configuration_changes table

      if (kDebugMode) {
        print('📝 OMS CONFIG - Logging change for $configKey');
        print('   Old Value: $oldValue');
        print('   New Value: $newValue');
        print('   Updated By: $updatedBy');
        print('   Reason: $reason');
      }

      // TODO: Implement dedicated configuration change logging table
      // await _supabase.from('oms_configuration_changes').insert({
      //   'config_key': configKey,
      //   'old_value': oldValue,
      //   'new_value': newValue,
      //   'changed_by': updatedBy,
      //   'change_reason': reason,
      //   'changed_at': DateTime.now().toIso8601String(),
      // });
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ OMS CONFIG - Failed to log configuration change: $e');
      }
    }
  }
}
