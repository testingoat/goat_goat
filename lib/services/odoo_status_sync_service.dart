import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

/// Service for syncing product approval status from Odoo back to Flutter app
class OdooStatusSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sync approval status for all products from Odoo
  Future<Map<String, dynamic>> syncAllProductStatus({
    String? sellerId,
    bool showLogs = true,
  }) async {
    try {
      if (showLogs) print('🔄 ODOO SYNC - Starting approval status sync...');

      // Get all products that have been synced to Odoo (have odoo_product_id)
      var query = _supabase.from('meat_products').select('*');

      if (sellerId != null) {
        query = query.eq('seller_id', sellerId);
      }

      final localProducts = await query;

      if (showLogs)
        print('🔍 ODOO SYNC - Found ${localProducts.length} local products');

      int syncedCount = 0;
      int updatedCount = 0;
      List<String> errors = [];

      for (final product in localProducts) {
        try {
          // Only sync products that were successfully created in Odoo
          // We'll identify them by checking if they have a recent created_at timestamp
          // and approval_status is still pending (meaning they might be approved in Odoo)

          if (product['approval_status'] == 'pending') {
            final syncResult = await _syncSingleProductStatus(
              product['id'],
              product['name'],
              showLogs: false,
            );

            if (syncResult['success']) {
              syncedCount++;
              if (syncResult['updated']) {
                updatedCount++;
                if (showLogs) {
                  print(
                    '✅ ODOO SYNC - Updated ${product['name']}: ${syncResult['old_status']} → ${syncResult['new_status']}',
                  );
                }
              }
            } else {
              errors.add('${product['name']}: ${syncResult['error']}');
            }
          }
        } catch (e) {
          errors.add('${product['name']}: ${e.toString()}');
        }
      }

      if (showLogs) {
        print('📊 ODOO SYNC - Sync completed:');
        print('   • Products checked: ${localProducts.length}');
        print('   • Products synced: $syncedCount');
        print('   • Status updates: $updatedCount');
        print('   • Errors: ${errors.length}');
      }

      return {
        'success': true,
        'total_products': localProducts.length,
        'synced_count': syncedCount,
        'updated_count': updatedCount,
        'errors': errors,
        'message': 'Sync completed successfully',
      };
    } catch (e) {
      if (showLogs) print('❌ ODOO SYNC - Error: ${e.toString()}');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Sync failed',
      };
    }
  }

  /// Sync approval status for a single product from Odoo
  Future<Map<String, dynamic>> _syncSingleProductStatus(
    String productId,
    String productName, {
    bool showLogs = true,
  }) async {
    try {
      if (showLogs) print('🔄 ODOO SYNC - Syncing status for: $productName');

      // Get current product status from local database
      final localProduct = await _supabase
          .from('meat_products')
          .select('*')
          .eq('id', productId)
          .single();

      final currentStatus = localProduct['approval_status'];

      // Call Odoo status check webhook
      final response = await _supabase.functions.invoke(
        'odoo-status-sync',
        body: {
          'product_id': productId,
          'product_name': productName,
          'current_status': currentStatus,
        },
        headers: ApiConfig.webhookHeaders,
      );

      if (response.data != null && response.data['success'] == true) {
        final odooStatus = response.data['odoo_status'];
        final statusChanged = response.data['status_changed'] == true;

        if (statusChanged) {
          // 🚨 ENHANCED SAFETY GUARDS: Multiple checks to prevent auto-approval
          if (odooStatus == 'approved') {
            try {
              final productCheck = await _supabase
                  .from('meat_products')
                  .select('odoo_product_id, created_at, approval_status')
                  .eq('id', productId)
                  .single();

              // Safety Guard 1: Must have valid Odoo product ID
              final hasOdooId =
                  productCheck['odoo_product_id'] != null &&
                  productCheck['odoo_product_id'].toString().isNotEmpty;
              if (!hasOdooId) {
                if (showLogs) {
                  print(
                    '🛡️ SAFETY GUARD 1 - Ignoring approved status without odoo_product_id for product $productName',
                  );
                }
                return {
                  'success': true,
                  'updated': false,
                  'status': currentStatus,
                  'safety_guard': 'missing_odoo_id',
                };
              }

              // Safety Guard 2: Product must be at least 2 minutes old to prevent immediate approval
              final createdAt = DateTime.parse(productCheck['created_at']);
              final productAge = DateTime.now().difference(createdAt);
              const minAge = Duration(minutes: 2);

              if (productAge < minAge) {
                if (showLogs) {
                  print(
                    '🛡️ SAFETY GUARD 2 - Product too new for approval: ${productAge.inSeconds}s < ${minAge.inSeconds}s for $productName',
                  );
                }
                return {
                  'success': true,
                  'updated': false,
                  'status': currentStatus,
                  'safety_guard': 'product_too_new',
                };
              }

              // Safety Guard 3: Only allow pending -> approved transition
              final currentApprovalStatus = productCheck['approval_status'];
              if (currentApprovalStatus != 'pending') {
                if (showLogs) {
                  print(
                    '🛡️ SAFETY GUARD 3 - Invalid status transition: $currentApprovalStatus -> approved for $productName',
                  );
                }
                return {
                  'success': true,
                  'updated': false,
                  'status': currentStatus,
                  'safety_guard': 'invalid_transition',
                };
              }

              if (showLogs) {
                print(
                  '✅ SAFETY GUARDS PASSED - Approving product $productName (age: ${productAge.inMinutes}min, odoo_id: ${productCheck['odoo_product_id']})',
                );
              }
            } catch (e) {
              // If any check fails, be conservative and do not auto-approve
              if (showLogs) {
                print(
                  '🛡️ SAFETY GUARD ERROR - Prevented approval due to check error for $productName: $e',
                );
              }
              return {
                'success': true,
                'updated': false,
                'status': currentStatus,
                'safety_guard': 'check_error',
              };
            }
          }

          // Update local database with new status from Odoo
          await _supabase
              .from('meat_products')
              .update({
                'approval_status': odooStatus,
                'approved_at': odooStatus == 'approved'
                    ? DateTime.now().toIso8601String()
                    : null,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', productId);

          if (showLogs) {
            print('✅ ODOO SYNC - Status updated: $currentStatus → $odooStatus');
          }

          return {
            'success': true,
            'updated': true,
            'old_status': currentStatus,
            'new_status': odooStatus,
          };
        } else {
          if (showLogs)
            print('ℹ️ ODOO SYNC - Status unchanged: $currentStatus');
          return {'success': true, 'updated': false, 'status': currentStatus};
        }
      } else {
        throw Exception(
          'Odoo status check failed: ${response.data?['error'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      if (showLogs)
        print('❌ ODOO SYNC - Error syncing $productName: ${e.toString()}');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Manual sync trigger for specific product
  Future<Map<String, dynamic>> syncProductStatus(String productId) async {
    try {
      // Get product details
      final product = await _supabase
          .from('meat_products')
          .select('*')
          .eq('id', productId)
          .single();

      return await _syncSingleProductStatus(
        productId,
        product['name'],
        showLogs: true,
      );
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to sync product status',
      };
    }
  }

  /// Check if sync is needed (products with pending status older than 5 minutes)
  Future<bool> isSyncNeeded({String? sellerId}) async {
    try {
      var query = _supabase
          .from('meat_products')
          .select('created_at')
          .eq('approval_status', 'pending');

      if (sellerId != null) {
        query = query.eq('seller_id', sellerId);
      }

      final pendingProducts = await query;

      // Check if any pending products are older than 5 minutes
      final fiveMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 5),
      );

      for (final product in pendingProducts) {
        final createdAt = DateTime.parse(product['created_at']);
        if (createdAt.isBefore(fiveMinutesAgo)) {
          return true; // Sync needed
        }
      }

      return false; // No sync needed
    } catch (e) {
      print('Error checking sync need: $e');
      return false;
    }
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats({String? sellerId}) async {
    try {
      var query = _supabase.from('meat_products').select('approval_status');

      if (sellerId != null) {
        query = query.eq('seller_id', sellerId);
      }

      final products = await query;

      final stats = {
        'total': products.length,
        'pending': products
            .where((p) => p['approval_status'] == 'pending')
            .length,
        'approved': products
            .where((p) => p['approval_status'] == 'approved')
            .length,
        'rejected': products
            .where((p) => p['approval_status'] == 'rejected')
            .length,
      };

      return {'success': true, 'stats': stats};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
