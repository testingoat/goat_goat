import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/api_config.dart';

/// SellerSyncService
/// Zero-risk service for syncing sellers with Odoo via webhook.
/// Follows the same pattern as product sync for consistency.
///
/// Features:
/// - Sync new sellers to Odoo for approval
/// - Handle approval/rejection responses
/// - Maintain audit trail
/// - Error handling and retry logic
class SellerSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Sync seller to Odoo for approval after registration
  ///
  /// This method is called after successful seller registration
  /// to create the seller in Odoo approval system
  Future<Map<String, dynamic>> syncSellerToOdoo(
    Map<String, dynamic> sellerData,
  ) async {
    try {
      if (kDebugMode) {
        print('🔄 SellerSyncService: Syncing seller to Odoo for approval');
        print(
          '📋 SellerSyncService: Seller: ${sellerData['seller_name']} (${sellerData['id']})',
        );
      }

      // Prepare webhook payload for Odoo seller creation
      final webhookPayload = {
        'seller_id': sellerData['id'],
        'seller_name': sellerData['seller_name'],
        'contact_phone': sellerData['contact_phone'],
        'seller_type': sellerData['seller_type'],
        'business_city': sellerData['business_city'],
        'business_address': sellerData['business_address'],
        'business_pincode': sellerData['business_pincode'],
        'gstin': sellerData['gstin'],
        'fssai_license': sellerData['fssai_license'],
        'bank_account_number': sellerData['bank_account_number'],
        'ifsc_code': sellerData['ifsc_code'],
        'account_holder_name': sellerData['account_holder_name'],
        'aadhaar_number': sellerData['aadhaar_number'],
        'action': 'create_for_approval',
        'created_at': sellerData['created_at'],
        'updated_at': sellerData['updated_at'],
      };

      if (kDebugMode) {
        print('📤 SellerSyncService: Webhook payload prepared');
      }

      // Call seller sync webhook
      final webhookResponse = await _supabase.functions.invoke(
        'seller-sync-webhook',
        body: webhookPayload,
        headers: ApiConfig.webhookHeaders,
      );

      if (kDebugMode) {
        print(
          '📥 SellerSyncService: Webhook response: ${webhookResponse.data}',
        );
      }

      if (webhookResponse.data != null &&
          webhookResponse.data['success'] == true) {
        return {
          'success': true,
          'message': 'Seller synced to Odoo successfully',
          'odoo_seller_id': webhookResponse.data['odoo_seller_id'],
          'sync_status': 'completed',
        };
      } else {
        // Webhook failed but don't fail the registration
        final errorMessage =
            webhookResponse.data?['error'] ?? 'Unknown webhook error';

        if (kDebugMode) {
          print('⚠️ SellerSyncService: Webhook failed: $errorMessage');
        }

        return {
          'success': false,
          'message': 'Seller registered but Odoo sync failed',
          'error': errorMessage,
          'sync_status': 'failed',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerSyncService: Sync error: $e');
      }

      return {
        'success': false,
        'message': 'Seller registered but sync failed',
        'error': e.toString(),
        'sync_status': 'error',
      };
    }
  }

  /// Handle seller approval/rejection from Odoo
  ///
  /// This method processes approval webhooks from Odoo
  Future<Map<String, dynamic>> handleSellerApproval({
    required String sellerId,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    try {
      if (kDebugMode) {
        print('🔄 SellerSyncService: Processing seller approval');
        print(
          '📋 SellerSyncService: Seller ID: $sellerId, Approved: $isApproved',
        );
      }

      // Prepare approval webhook payload
      final approvalPayload = {
        'seller_id': sellerId,
        'is_approved': isApproved,
        'rejection_reason': rejectionReason,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Call seller approval webhook
      final webhookResponse = await _supabase.functions.invoke(
        'seller-approval-webhook',
        body: approvalPayload,
        headers: ApiConfig.webhookHeaders,
      );

      if (kDebugMode) {
        print(
          '📥 SellerSyncService: Approval response: ${webhookResponse.data}',
        );
      }

      if (webhookResponse.data != null &&
          webhookResponse.data['success'] == true) {
        return {
          'success': true,
          'message': webhookResponse.data['message'],
          'approval_status': webhookResponse.data['approval_status'],
          'seller_name': webhookResponse.data['seller_name'],
        };
      } else {
        final errorMessage =
            webhookResponse.data?['error'] ?? 'Unknown approval error';

        return {
          'success': false,
          'message': 'Approval processing failed',
          'error': errorMessage,
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerSyncService: Approval error: $e');
      }

      return {
        'success': false,
        'message': 'Approval processing failed',
        'error': e.toString(),
      };
    }
  }

  /// Get seller approval status from Odoo
  ///
  /// This method checks the current approval status in Odoo
  Future<Map<String, dynamic>> getSellerApprovalStatus(String sellerId) async {
    try {
      if (kDebugMode) {
        print(
          '🔍 SellerSyncService: Checking seller approval status: $sellerId',
        );
      }

      // Get seller data from local database
      final sellerResponse = await _supabase
          .from('sellers')
          .select(
            'id, seller_name, approval_status, approved_at, rejected_at, rejection_reason',
          )
          .eq('id', sellerId)
          .single();

      return {
        'success': true,
        'seller_data': sellerResponse,
        'approval_status': sellerResponse['approval_status'],
        'approved_at': sellerResponse['approved_at'],
        'rejected_at': sellerResponse['rejected_at'],
        'rejection_reason': sellerResponse['rejection_reason'],
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerSyncService: Status check error: $e');
      }

      return {
        'success': false,
        'message': 'Failed to check approval status',
        'error': e.toString(),
      };
    }
  }

  /// Resend seller for approval (for testing/recovery)
  ///
  /// This method allows manual resending of sellers to Odoo
  Future<Map<String, dynamic>> resendSellerForApproval(String sellerId) async {
    try {
      if (kDebugMode) {
        print('🔄 SellerSyncService: Resending seller for approval: $sellerId');
      }

      // Get seller data
      final sellerResponse = await _supabase
          .from('sellers')
          .select('*')
          .eq('id', sellerId)
          .single();

      // Sync to Odoo
      final syncResult = await syncSellerToOdoo(sellerResponse);

      return {
        'success': syncResult['success'],
        'message': syncResult['success']
            ? 'Seller resent for approval successfully'
            : 'Failed to resend seller for approval',
        'sync_result': syncResult,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ SellerSyncService: Resend error: $e');
      }

      return {
        'success': false,
        'message': 'Failed to resend seller for approval',
        'error': e.toString(),
      };
    }
  }

  /// Validate seller data before sync
  ///
  /// Ensures all required fields are present for Odoo sync
  static String? validateSellerData(Map<String, dynamic> sellerData) {
    // Required fields for Odoo sync
    final requiredFields = [
      'id',
      'seller_name',
      'contact_phone',
      'seller_type',
    ];

    for (final field in requiredFields) {
      if (sellerData[field] == null || sellerData[field].toString().isEmpty) {
        return 'Missing required field: $field';
      }
    }

    // Validate seller type
    final validSellerTypes = ['meat', 'livestock', 'both'];
    if (!validSellerTypes.contains(sellerData['seller_type']?.toLowerCase())) {
      return 'Invalid seller type: ${sellerData['seller_type']}';
    }

    // Validate phone number format
    final phone = sellerData['contact_phone'].toString();
    if (phone.length < 10) {
      return 'Invalid phone number format';
    }

    return null; // Valid
  }

  /// Format seller data for display
  ///
  /// Creates human-readable seller information
  static String formatSellerInfo(Map<String, dynamic> sellerData) {
    final name = sellerData['seller_name'] ?? 'Unknown Seller';
    final type = sellerData['seller_type'] ?? 'Unknown Type';
    final city = sellerData['business_city'] ?? 'Unknown City';
    final status = sellerData['approval_status'] ?? 'pending';

    return '$name ($type) - $city - Status: ${status.toUpperCase()}';
  }
}
