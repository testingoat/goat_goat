import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

/// SellerStatusSyncService
/// Zero-risk service for syncing seller approval status from Odoo.
/// Follows the same pattern as product status sync for consistency.
///
/// Features:
/// - Check seller approval status in Odoo
/// - Update local Supabase database if status changed
/// - Handle authentication and session management
/// - Comprehensive error handling and logging
class SellerStatusSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sync approval status for a single seller from Odoo
  ///
  /// This method checks the seller's current approval status in Odoo
  /// and updates the local database if the status has changed
  Future<Map<String, dynamic>> syncSellerStatus(
    String sellerId, {
    String? sellerName,
    bool showLogs = true,
  }) async {
    try {
      if (showLogs) {
        print('🔄 SELLER SYNC - Syncing status for seller: $sellerId');
        if (sellerName != null) {
          print('📋 SELLER SYNC - Seller name: $sellerName');
        }
      }

      // Get current seller status from local database
      final localSeller = await _supabase
          .from('sellers')
          .select('*')
          .eq('id', sellerId)
          .single();

      final currentStatus = localSeller['approval_status'];
      if (showLogs) {
        print('📋 SELLER SYNC - Current local status: $currentStatus');
      }

      // Call seller status sync webhook
      final response = await _supabase.functions.invoke(
        'seller-status-sync',
        body: {
          'seller_id': sellerId,
          'seller_name': sellerName,
          'current_status': currentStatus,
        },
        headers: ApiConfig.webhookHeaders,
      );

      if (showLogs) {
        print('📥 SELLER SYNC - Webhook response: ${response.data}');
      }

      if (response.data != null && response.data['success'] == true) {
        final statusChanged = response.data['status_changed'] ?? false;
        final newStatus = response.data['current_status'];
        final previousStatus = response.data['previous_status'];

        if (showLogs) {
          if (statusChanged) {
            print('✅ SELLER SYNC - Status updated: $previousStatus → $newStatus');
          } else {
            print('ℹ️ SELLER SYNC - Status unchanged: $newStatus');
          }
        }

        return {
          'success': true,
          'status_changed': statusChanged,
          'previous_status': previousStatus,
          'current_status': newStatus,
          'message': response.data['message'],
          'sync_timestamp': response.data['sync_timestamp'],
        };
      } else {
        final errorMessage = response.data?['error'] ?? 'Unknown sync error';
        if (showLogs) {
          print('❌ SELLER SYNC - Sync failed: $errorMessage');
        }

        return {
          'success': false,
          'message': 'Status sync failed',
          'error': errorMessage,
          'current_status': currentStatus,
        };
      }
    } catch (e) {
      if (showLogs) {
        print('❌ SELLER SYNC - Sync error: $e');
      }

      return {
        'success': false,
        'message': 'Status sync failed',
        'error': e.toString(),
      };
    }
  }

  /// Sync approval status for multiple sellers
  ///
  /// This method syncs status for multiple sellers in batch
  /// Useful for syncing all pending sellers at once
  Future<Map<String, dynamic>> syncMultipleSellerStatus(
    List<Map<String, dynamic>> sellers, {
    bool showLogs = true,
  }) async {
    try {
      if (showLogs) {
        print('🔄 SELLER SYNC - Syncing ${sellers.length} sellers');
      }

      final results = <Map<String, dynamic>>[];
      int successCount = 0;
      int failureCount = 0;
      int changedCount = 0;

      for (final seller in sellers) {
        final sellerId = seller['id'];
        final sellerName = seller['seller_name'];

        if (showLogs) {
          print('🔄 SELLER SYNC - Processing: $sellerName ($sellerId)');
        }

        final result = await syncSellerStatus(
          sellerId,
          sellerName: sellerName,
          showLogs: false, // Reduce log noise for batch operations
        );

        results.add({
          'seller_id': sellerId,
          'seller_name': sellerName,
          ...result,
        });

        if (result['success'] == true) {
          successCount++;
          if (result['status_changed'] == true) {
            changedCount++;
          }
        } else {
          failureCount++;
        }

        // Small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (showLogs) {
        print('✅ SELLER SYNC - Batch complete: $successCount success, $failureCount failed, $changedCount changed');
      }

      return {
        'success': true,
        'total_sellers': sellers.length,
        'success_count': successCount,
        'failure_count': failureCount,
        'changed_count': changedCount,
        'results': results,
        'message': 'Batch sync completed',
      };
    } catch (e) {
      if (showLogs) {
        print('❌ SELLER SYNC - Batch sync error: $e');
      }

      return {
        'success': false,
        'message': 'Batch sync failed',
        'error': e.toString(),
      };
    }
  }

  /// Sync all pending sellers
  ///
  /// This method fetches all sellers with 'pending' status
  /// and syncs their approval status from Odoo
  Future<Map<String, dynamic>> syncAllPendingSellers({
    bool showLogs = true,
  }) async {
    try {
      if (showLogs) {
        print('🔄 SELLER SYNC - Fetching all pending sellers');
      }

      // Get all pending sellers from database
      final pendingSellers = await _supabase
          .from('sellers')
          .select('id, seller_name, approval_status, odoo_seller_id')
          .eq('approval_status', 'pending')
          .not('odoo_seller_id', 'is', null); // Only sync sellers that exist in Odoo

      if (pendingSellers.isEmpty) {
        if (showLogs) {
          print('ℹ️ SELLER SYNC - No pending sellers found');
        }

        return {
          'success': true,
          'message': 'No pending sellers to sync',
          'total_sellers': 0,
          'changed_count': 0,
        };
      }

      if (showLogs) {
        print('📋 SELLER SYNC - Found ${pendingSellers.length} pending sellers');
      }

      // Sync all pending sellers
      return await syncMultipleSellerStatus(pendingSellers, showLogs: showLogs);
    } catch (e) {
      if (showLogs) {
        print('❌ SELLER SYNC - Error fetching pending sellers: $e');
      }

      return {
        'success': false,
        'message': 'Failed to fetch pending sellers',
        'error': e.toString(),
      };
    }
  }

  /// Check if a seller needs status sync
  ///
  /// This method checks if a seller's status might be outdated
  /// based on last update time and current status
  bool shouldSyncSellerStatus(Map<String, dynamic> seller) {
    final approvalStatus = seller['approval_status'];
    final updatedAt = seller['updated_at'];
    final odooSellerId = seller['odoo_seller_id'];

    // Don't sync if seller is not in Odoo yet
    if (odooSellerId == null) {
      return false;
    }

    // Always sync pending sellers (they might have been approved)
    if (approvalStatus == 'pending') {
      return true;
    }

    // Don't sync already approved/rejected sellers unless they're very old
    if (approvalStatus == 'approved' || approvalStatus == 'rejected') {
      if (updatedAt != null) {
        final lastUpdate = DateTime.parse(updatedAt);
        final daysSinceUpdate = DateTime.now().difference(lastUpdate).inDays;
        
        // Only sync if it's been more than 7 days (in case status was reverted)
        return daysSinceUpdate > 7;
      }
    }

    return false;
  }

  /// Get sync status summary
  ///
  /// This method provides a summary of sellers that need syncing
  Future<Map<String, dynamic>> getSyncStatusSummary() async {
    try {
      final allSellers = await _supabase
          .from('sellers')
          .select('id, seller_name, approval_status, updated_at, odoo_seller_id');

      final needsSync = allSellers.where((seller) => shouldSyncSellerStatus(seller)).toList();
      final pendingCount = allSellers.where((s) => s['approval_status'] == 'pending').length;
      final approvedCount = allSellers.where((s) => s['approval_status'] == 'approved').length;
      final rejectedCount = allSellers.where((s) => s['approval_status'] == 'rejected').length;
      final notInOdooCount = allSellers.where((s) => s['odoo_seller_id'] == null).length;

      return {
        'success': true,
        'total_sellers': allSellers.length,
        'pending_count': pendingCount,
        'approved_count': approvedCount,
        'rejected_count': rejectedCount,
        'not_in_odoo_count': notInOdooCount,
        'needs_sync_count': needsSync.length,
        'needs_sync_sellers': needsSync,
      };
    } catch (e) {
      print('❌ SELLER SYNC - Error getting sync summary: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
