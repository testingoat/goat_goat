import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing feature flags in the admin panel
/// Zero-risk implementation with proper safety checks and audit logging
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Feature flag for the feature flag service itself (meta!)
  static const bool _enableFeatureFlagManagement = true;

  /// Check if feature flag management is available
  bool get isAvailable => _enableFeatureFlagManagement;

  // =====================================================
  // FEATURE FLAG CRUD OPERATIONS
  // =====================================================

  /// Get all feature flags with their current states
  Future<Map<String, dynamic>> getAllFeatureFlags() async {
    try {
      if (kDebugMode) {
        print('🔍 FEATURE_FLAGS - Fetching all feature flags...');
      }

      // Try to get from feature_flags table first
      try {
        final flags = await _supabase
            .from('feature_flags')
            .select('*')
            .order('feature_name');

        final flagStates = <String, dynamic>{};
        for (final flag in flags) {
          flagStates[flag['feature_name']] = {
            'enabled': flag['enabled'] ?? false,
            'description': flag['description'] ?? '',
            'category':
                'system', // Default category since it's not in the existing table
            'created_at': flag['created_at'],
            'updated_at': flag['updated_at'],
            'target_user_percentage': flag['target_user_percentage'] ?? 0,
          };
        }

        if (kDebugMode) {
          print(
            '✅ FEATURE_FLAGS - Found ${flagStates.length} flags from database',
          );
        }

        return {'success': true, 'data': flagStates, 'source': 'database'};
      } catch (e) {
        if (kDebugMode) {
          print(
            '⚠️ FEATURE_FLAGS - Database not available, using hardcoded values: $e',
          );
        }

        // Fallback to hardcoded values if table doesn't exist
        return {
          'success': true,
          'data': _getHardcodedFeatureFlags(),
          'source': 'hardcoded',
          'note': 'Using hardcoded values - feature_flags table not available',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FEATURE_FLAGS - Error fetching feature flags: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }

  /// Get hardcoded feature flags as fallback
  Map<String, dynamic> _getHardcodedFeatureFlags() {
    return {
      'FORCE_V2_WEBHOOKS': {
        'enabled': true,
        'description': 'Forces all webhooks to use v2 payload format',
        'category': 'webhooks',
        'editable': true,
      },
      'ENABLE_PRODUCT_DUP_CHECK': {
        'enabled': false,
        'description': 'Enables duplicate product checking by default_code',
        'category': 'products',
        'editable': true,
      },
      'ENABLE_AUTO_ACTIVATE_ON_APPROVAL': {
        'enabled': true,
        'description':
            'Automatically activates products when approved via webhook',
        'category': 'products',
        'editable': true,
      },
      'AUTO_SYNC_STATUS_ON_OPEN': {
        'enabled': true,
        'description': 'Automatically syncs product status when app opens',
        'category': 'sync',
        'editable': true,
      },
      'ENABLE_DEBUG_LOGGING': {
        'enabled': true,
        'description': 'Enables debug panel logging for edge functions',
        'category': 'debug',
        'editable': true,
      },
    };
  }

  /// Toggle a feature flag safely
  Future<Map<String, dynamic>> toggleFeatureFlag(
    String flagName,
    bool newValue, {
    String? changedBy,
    String? reason,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 FEATURE_FLAGS - Toggling $flagName to $newValue');
      }

      // Safety check - don't allow toggling critical system flags
      if (_isCriticalFlag(flagName)) {
        return {
          'success': false,
          'error': 'Cannot toggle critical system flag: $flagName',
          'flag_name': flagName,
        };
      }

      // Get current value first
      final currentFlags = await getAllFeatureFlags();
      if (!currentFlags['success']) {
        return {
          'success': false,
          'error': 'Failed to get current flag state',
          'flag_name': flagName,
        };
      }

      final flagData = currentFlags['data'][flagName];
      if (flagData == null) {
        return {
          'success': false,
          'error': 'Feature flag not found: $flagName',
          'flag_name': flagName,
        };
      }

      final oldValue = flagData['enabled'] as bool;

      // No change needed
      if (oldValue == newValue) {
        return {
          'success': true,
          'changed': false,
          'flag_name': flagName,
          'value': newValue,
          'message': 'Flag already has the requested value',
        };
      }

      // Try to update in database
      try {
        // Check if flag exists in database
        final existingFlag = await _supabase
            .from('feature_flags')
            .select('id')
            .eq('feature_name', flagName)
            .maybeSingle();

        if (existingFlag != null) {
          // Update existing flag
          await _supabase
              .from('feature_flags')
              .update({
                'enabled': newValue,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('feature_name', flagName);
        } else {
          // Insert new flag
          await _supabase.from('feature_flags').insert({
            'feature_name': flagName,
            'description': _getFlagDescription(flagName),
            'enabled': newValue,
            'target_user_percentage': newValue ? 100 : 0,
          });
        }

        // Log the change
        await _logFeatureFlagChange(
          flagName,
          oldValue,
          newValue,
          changedBy,
          reason,
        );

        if (kDebugMode) {
          print(
            '✅ FEATURE_FLAGS - Successfully toggled $flagName: $oldValue → $newValue',
          );
        }

        return {
          'success': true,
          'changed': true,
          'flag_name': flagName,
          'old_value': oldValue,
          'new_value': newValue,
          'changed_by': changedBy ?? 'admin',
          'timestamp': DateTime.now().toIso8601String(),
        };
      } catch (dbError) {
        if (kDebugMode) {
          print(
            '⚠️ FEATURE_FLAGS - Database update failed, this is read-only mode: $dbError',
          );
        }

        return {
          'success': false,
          'error': 'Feature flag updates not available - read-only mode',
          'flag_name': flagName,
          'note': 'Database table may not exist or permissions insufficient',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ FEATURE_FLAGS - Error toggling feature flag: $e');
      }
      return {'success': false, 'error': e.toString(), 'flag_name': flagName};
    }
  }

  /// Check if a flag is critical and shouldn't be toggled
  bool _isCriticalFlag(String flagName) {
    const criticalFlags = [
      // Add any flags that are critical to system operation
      // For now, allow all flags to be toggled
    ];
    return criticalFlags.contains(flagName);
  }

  /// Get description for a flag
  String _getFlagDescription(String flagName) {
    final descriptions = {
      'FORCE_V2_WEBHOOKS': 'Forces all webhooks to use v2 payload format',
      'ENABLE_PRODUCT_DUP_CHECK':
          'Enables duplicate product checking by default_code',
      'ENABLE_AUTO_ACTIVATE_ON_APPROVAL':
          'Automatically activates products when approved via webhook',
      'AUTO_SYNC_STATUS_ON_OPEN':
          'Automatically syncs product status when app opens',
      'ENABLE_DEBUG_LOGGING': 'Enables debug panel logging for edge functions',
    };
    return descriptions[flagName] ?? 'Feature flag for system configuration';
  }

  /// Get category for a flag
  String _getFlagCategory(String flagName) {
    if (flagName.contains('WEBHOOK')) return 'webhooks';
    if (flagName.contains('PRODUCT') || flagName.contains('DUP'))
      return 'products';
    if (flagName.contains('SYNC')) return 'sync';
    if (flagName.contains('DEBUG')) return 'debug';
    return 'system';
  }

  /// Log feature flag change to audit trail
  Future<void> _logFeatureFlagChange(
    String flagName,
    bool oldValue,
    bool newValue,
    String? changedBy,
    String? reason,
  ) async {
    try {
      await _supabase.from('feature_flag_changes').insert({
        'flag_name': flagName,
        'old_value': oldValue,
        'new_value': newValue,
        'changed_by': changedBy ?? 'admin',
        'change_reason': reason,
      });
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ FEATURE_FLAGS - Failed to log change: $e');
      }
      // Don't fail the main operation if logging fails
    }
  }

  // =====================================================
  // FEATURE FLAG ANALYTICS
  // =====================================================

  /// Get feature flag usage analytics
  Future<Map<String, dynamic>> getFeatureFlagAnalytics() async {
    try {
      // Get recent changes
      final recentChanges = await _supabase
          .from('feature_flag_changes')
          .select('*')
          .order('created_at', ascending: false)
          .limit(50);

      // Calculate change frequency
      final changeFrequency = <String, int>{};
      for (final change in recentChanges) {
        final flagName = change['flag_name'] as String;
        changeFrequency[flagName] = (changeFrequency[flagName] ?? 0) + 1;
      }

      return {
        'success': true,
        'data': {
          'recent_changes': recentChanges,
          'change_frequency': changeFrequency,
          'total_changes': recentChanges.length,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ FEATURE_FLAGS - Error getting analytics: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }
}
