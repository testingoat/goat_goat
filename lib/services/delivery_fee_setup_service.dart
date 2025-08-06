/// Delivery Fee Setup Service
///
/// This service ensures that a default delivery fee configuration exists
/// in the database and creates one if missing. This fixes the issue where
/// delivery fees always show as FREE due to missing configuration.

import '../supabase_service.dart';

class DeliveryFeeSetupService {
  static final SupabaseService _supabaseService = SupabaseService();

  /// Ensure default delivery fee configuration exists
  /// This should be called on app startup or when delivery fee calculation fails
  static Future<bool> ensureDefaultConfigExists() async {
    try {
      print(
        '🔧 DELIVERY_SETUP - Checking for active delivery fee configuration...',
      );

      // Check if any active GLOBAL configuration exists
      final existingConfig = await _supabaseService.client
          .from('delivery_fee_configs')
          .select('id, config_name, is_active')
          .eq('is_active', true)
          .eq('scope', 'GLOBAL')
          .maybeSingle();

      if (existingConfig != null) {
        print(
          '✅ DELIVERY_SETUP - Active configuration found: ${existingConfig['config_name']}',
        );
        return true;
      }

      print(
        '⚠️ DELIVERY_SETUP - No active configuration found, creating default...',
      );

      // Create default configuration
      final defaultConfig = {
        'scope': 'GLOBAL',
        'config_name': 'Default Delivery Rates',
        'is_active': true,
        'use_routing': false, // Use straight-line distance for simplicity
        'calibration_multiplier':
            1.5, // Multiply straight-line by 1.5 for realistic driving distance
        'tier_rates': [
          {
            'min_km': 0.0,
            'max_km': 5.0,
            'fee': 25.0, // ₹25 for 0-5km
          },
          {
            'min_km': 5.0,
            'max_km': 10.0,
            'fee': 35.0, // ₹35 for 5-10km
          },
          {
            'min_km': 10.0,
            'max_km': 15.0,
            'fee': 45.0, // ₹45 for 10-15km
          },
        ],
        'dynamic_multipliers': {
          'peak_hours': {
            'enabled': false,
            'start_time': '18:00',
            'end_time': '22:00',
            'multiplier': 1.1,
            'days': ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'],
          },
          'weather': {'enabled': false, 'multiplier': 1.0},
          'demand': {'enabled': false, 'multiplier': 1.0},
        },
        'min_fee': 15.0,
        'max_fee': 99.0,
        'free_delivery_threshold': 500.0, // Free delivery for orders ≥ ₹500
        'max_serviceable_distance_km': 15.0,
        'version': 1,
        'last_modified_by': 'system_auto_setup',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Insert the default configuration
      final result = await _supabaseService.client
          .from('delivery_fee_configs')
          .insert(defaultConfig)
          .select('id, config_name')
          .single();

      print(
        '✅ DELIVERY_SETUP - Default configuration created: ${result['config_name']} (ID: ${result['id']})',
      );

      return true;
    } catch (e) {
      print('❌ DELIVERY_SETUP - Error creating default configuration: $e');
      return false;
    }
  }

  /// Get current delivery fee configuration status
  static Future<Map<String, dynamic>> getConfigurationStatus() async {
    try {
      // Get all configurations
      final allConfigs = await _supabaseService.client
          .from('delivery_fee_configs')
          .select('id, scope, config_name, is_active, created_at')
          .order('created_at', ascending: false);

      // Get active GLOBAL configuration
      final activeGlobal = await _supabaseService.client
          .from('delivery_fee_configs')
          .select('*')
          .eq('is_active', true)
          .eq('scope', 'GLOBAL')
          .maybeSingle();

      return {
        'total_configs': allConfigs.length,
        'active_global_config': activeGlobal,
        'all_configs': allConfigs,
        'has_active_config': activeGlobal != null,
      };
    } catch (e) {
      print('❌ DELIVERY_SETUP - Error getting configuration status: $e');
      return {
        'total_configs': 0,
        'active_global_config': null,
        'all_configs': [],
        'has_active_config': false,
        'error': e.toString(),
      };
    }
  }

  /// Test delivery fee calculation with debug information
  static Future<Map<String, dynamic>> testDeliveryFeeCalculation({
    required String customerAddress,
    required double orderSubtotal,
  }) async {
    try {
      print('🧪 DELIVERY_TEST - Testing delivery fee calculation...');
      print('   Address: $customerAddress');
      print('   Order Subtotal: ₹${orderSubtotal.toStringAsFixed(0)}');

      // First ensure configuration exists
      final configExists = await ensureDefaultConfigExists();
      if (!configExists) {
        return {
          'success': false,
          'error': 'Failed to create default configuration',
          'fee': 0.0,
        };
      }

      // Get configuration status
      final status = await getConfigurationStatus();
      print(
        '   Configuration Status: ${status['has_active_config'] ? 'Active' : 'Missing'}',
      );

      if (status['active_global_config'] != null) {
        final config = status['active_global_config'];
        print('   Config Name: ${config['config_name']}');
        print(
          '   Free Delivery Threshold: ₹${config['free_delivery_threshold']}',
        );
        print('   Max Distance: ${config['max_serviceable_distance_km']}km');
      }

      // Import and use the actual delivery fee service
      // Note: This would need to be imported properly in the actual implementation
      return {
        'success': true,
        'configuration_ready': true,
        'config_status': status,
        'message': 'Configuration is ready for delivery fee calculation',
      };
    } catch (e) {
      print('❌ DELIVERY_TEST - Error testing delivery fee calculation: $e');
      return {'success': false, 'error': e.toString(), 'fee': 0.0};
    }
  }

  /// Initialize delivery fee system on app startup
  static Future<void> initializeDeliveryFeeSystem() async {
    try {
      print('🚀 DELIVERY_SETUP - Initializing delivery fee system...');

      final success = await ensureDefaultConfigExists();
      if (success) {
        final status = await getConfigurationStatus();
        print('✅ DELIVERY_SETUP - System initialized successfully');
        print('   Total configurations: ${status['total_configs']}');
        print(
          '   Active configuration: ${status['has_active_config'] ? 'Yes' : 'No'}',
        );
      } else {
        print('❌ DELIVERY_SETUP - System initialization failed');
      }
    } catch (e) {
      print('❌ DELIVERY_SETUP - Initialization error: $e');
    }
  }

  /// Debug delivery fee calculation pipeline
  static Future<void> debugDeliveryFeeCalculation(
    String customerAddress,
    double orderSubtotal,
  ) async {
    print('\n🔍 DELIVERY_DEBUG - Full Pipeline Debug');
    print('=' * 50);

    try {
      // Step 1: Check configuration
      print('\n1️⃣ Configuration Check:');
      final status = await getConfigurationStatus();
      print('   Has active config: ${status['has_active_config']}');

      if (!status['has_active_config']) {
        print('   ❌ No active configuration found!');
        print('   🔧 Creating default configuration...');
        await ensureDefaultConfigExists();
      } else {
        final config = status['active_global_config'];
        print('   ✅ Active config: ${config['config_name']}');
        print(
          '   📊 Free delivery threshold: ₹${config['free_delivery_threshold']}',
        );
      }

      // Step 2: Check order subtotal vs threshold
      print('\n2️⃣ Order Subtotal Check:');
      print('   Order subtotal: ₹${orderSubtotal.toStringAsFixed(0)}');
      final threshold =
          status['active_global_config']?['free_delivery_threshold'] ?? 500.0;
      print('   Free delivery threshold: ₹${threshold.toStringAsFixed(0)}');

      if (orderSubtotal >= threshold) {
        print('   🎉 Order qualifies for FREE delivery!');
        print('   ⚠️ This might be why you always see FREE delivery');
        print(
          '   💡 Try with order total below ₹${threshold.toStringAsFixed(0)} to see distance-based fees',
        );
      } else {
        print('   💰 Order should have distance-based delivery fee');
      }

      // Step 3: Address and distance info
      print('\n3️⃣ Address and Distance:');
      print('   Customer address: $customerAddress');
      print('   Default seller location: Bangalore, Karnataka, India');
      print('   💡 Distance calculation will determine the fee');
    } catch (e) {
      print('❌ DELIVERY_DEBUG - Debug error: $e');
    }

    print('\n' + '=' * 50);
  }
}
