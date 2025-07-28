import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_auth_service.dart';

/// Service for managing product reviews and moderation in the admin panel
///
/// This service follows the zero-risk pattern:
/// - No modifications to existing services
/// - Composition over modification
/// - Feature flags for gradual rollout
/// - 100% backward compatibility
class ProductReviewService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AdminAuthService _adminAuth = AdminAuthService();

  // Feature flags for gradual rollout
  static const bool _enableReviewModeration = true;
  static const bool _enableBulkOperations = true;
  static const bool _enableAdvancedAnalytics = true;

  // ===== REVIEW RETRIEVAL METHODS =====

  /// Get all reviews with optional filtering and pagination
  Future<Map<String, dynamic>> getReviews({
    String? moderationStatus,
    String? productId,
    String? customerId,
    int limit = 50,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      if (!_enableReviewModeration) {
        return {
          'success': false,
          'message': 'Review moderation feature is currently disabled',
          'reviews': [],
          'total_count': 0,
        };
      }

      print(
        '📋 Getting reviews with filters: status=$moderationStatus, product=$productId',
      );

      var query = _supabase.from('product_reviews').select('''
            *,
            customers!inner(id, full_name, phone_number),
            meat_products!inner(id, name, seller_id, sellers!inner(seller_name))
          ''');

      // Apply filters
      if (moderationStatus != null) {
        query = query.eq('moderation_status', moderationStatus);
      }
      if (productId != null) {
        query = query.eq('product_id', productId);
      }
      if (customerId != null) {
        query = query.eq('customer_id', customerId);
      }

      // Apply ordering and pagination
      final response = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      // Get total count for pagination (simplified approach)
      var countQuery = _supabase.from('product_reviews').select('id');

      if (moderationStatus != null) {
        countQuery = countQuery.eq('moderation_status', moderationStatus);
      }
      if (productId != null) {
        countQuery = countQuery.eq('product_id', productId);
      }
      if (customerId != null) {
        countQuery = countQuery.eq('customer_id', customerId);
      }

      final countResponse = await countQuery;
      final totalCount = countResponse.length;

      await _adminAuth.logAction(
        action: 'get_reviews',
        resourceType: 'product_review',
        metadata: {
          'filters': {
            'moderation_status': moderationStatus,
            'product_id': productId,
            'customer_id': customerId,
          },
          'pagination': {'limit': limit, 'offset': offset},
          'result_count': response.length,
        },
      );

      return {
        'success': true,
        'reviews': response,
        'total_count': totalCount,
        'has_more': response.length == limit,
      };
    } catch (e) {
      print('❌ Error getting reviews: $e');
      return {
        'success': false,
        'message': 'Failed to retrieve reviews: ${e.toString()}',
        'reviews': [],
        'total_count': 0,
      };
    }
  }

  /// Get pending reviews for moderation
  Future<Map<String, dynamic>> getPendingReviews({
    int limit = 20,
    int offset = 0,
  }) async {
    return await getReviews(
      moderationStatus: 'pending',
      limit: limit,
      offset: offset,
      orderBy: 'created_at',
      ascending: true, // Oldest first for fair moderation
    );
  }

  /// Get review statistics for dashboard
  Future<Map<String, dynamic>> getReviewStatistics() async {
    try {
      if (!_enableAdvancedAnalytics) {
        return {
          'success': false,
          'message': 'Advanced analytics feature is currently disabled',
        };
      }

      print('📊 Getting review statistics...');

      // Get moderation status counts
      final statusStats = await _supabase
          .from('product_reviews')
          .select('moderation_status')
          .then((data) {
            final stats = <String, int>{
              'pending': 0,
              'approved': 0,
              'rejected': 0,
            };

            for (final review in data) {
              final status = review['moderation_status'] as String;
              stats[status] = (stats[status] ?? 0) + 1;
            }

            return stats;
          });

      // Get rating distribution
      final ratingStats = await _supabase
          .from('product_reviews')
          .select('rating')
          .eq('moderation_status', 'approved')
          .then((data) {
            final stats = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

            for (final review in data) {
              final rating = review['rating'] as int;
              stats[rating] = (stats[rating] ?? 0) + 1;
            }

            return stats;
          });

      // Get recent activity (last 7 days)
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentReviews = await _supabase
          .from('product_reviews')
          .select('id')
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .then((data) => data.length);

      await _adminAuth.logAction(
        action: 'get_review_statistics',
        resourceType: 'analytics',
        metadata: {
          'status_stats': statusStats,
          'rating_stats': ratingStats,
          'recent_reviews': recentReviews,
        },
      );

      return {
        'success': true,
        'status_distribution': statusStats,
        'rating_distribution': ratingStats,
        'recent_reviews_count': recentReviews,
        'total_reviews': statusStats.values.reduce((a, b) => a + b),
      };
    } catch (e) {
      print('❌ Error getting review statistics: $e');
      return {
        'success': false,
        'message': 'Failed to retrieve statistics: ${e.toString()}',
      };
    }
  }

  // ===== REVIEW MODERATION METHODS =====

  /// Approve a review
  Future<Map<String, dynamic>> approveReview(String reviewId) async {
    try {
      if (!_enableReviewModeration) {
        return {
          'success': false,
          'message': 'Review moderation feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      print('✅ Approving review: $reviewId');

      // Get review details before approval for audit trail
      final reviewBefore = await _supabase
          .from('product_reviews')
          .select('*')
          .eq('id', reviewId)
          .single();

      // Call the database function to approve the review
      await _supabase.rpc(
        'approve_review',
        params: {'target_review_id': reviewId, 'moderator_id': adminId},
      );

      // Get updated review for audit trail
      final reviewAfter = await _supabase
          .from('product_reviews')
          .select('*')
          .eq('id', reviewId)
          .single();

      await _adminAuth.logAction(
        action: 'approve_review',
        resourceType: 'product_review',
        resourceId: reviewId,
        metadata: {
          'old_status': reviewBefore['moderation_status'],
          'new_status': reviewAfter['moderation_status'],
          'product_id': reviewAfter['product_id'],
          'customer_id': reviewAfter['customer_id'],
          'rating': reviewAfter['rating'],
        },
      );

      return {
        'success': true,
        'message': 'Review approved successfully',
        'review': reviewAfter,
      };
    } catch (e) {
      print('❌ Error approving review: $e');
      return {
        'success': false,
        'message': 'Failed to approve review: ${e.toString()}',
      };
    }
  }

  /// Reject a review with reason
  Future<Map<String, dynamic>> rejectReview(
    String reviewId,
    String rejectionReason,
  ) async {
    try {
      if (!_enableReviewModeration) {
        return {
          'success': false,
          'message': 'Review moderation feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      if (rejectionReason.trim().isEmpty) {
        return {'success': false, 'message': 'Rejection reason is required'};
      }

      print('❌ Rejecting review: $reviewId with reason: $rejectionReason');

      // Get review details before rejection for audit trail
      final reviewBefore = await _supabase
          .from('product_reviews')
          .select('*')
          .eq('id', reviewId)
          .single();

      // Call the database function to reject the review
      await _supabase.rpc(
        'reject_review',
        params: {
          'target_review_id': reviewId,
          'moderator_id': adminId,
          'rejection_reason': rejectionReason,
        },
      );

      // Get updated review for audit trail
      final reviewAfter = await _supabase
          .from('product_reviews')
          .select('*')
          .eq('id', reviewId)
          .single();

      await _adminAuth.logAction(
        action: 'reject_review',
        resourceType: 'product_review',
        resourceId: reviewId,
        metadata: {
          'old_status': reviewBefore['moderation_status'],
          'new_status': reviewAfter['moderation_status'],
          'rejection_reason': rejectionReason,
          'product_id': reviewAfter['product_id'],
          'customer_id': reviewAfter['customer_id'],
          'rating': reviewAfter['rating'],
        },
      );

      return {
        'success': true,
        'message': 'Review rejected successfully',
        'review': reviewAfter,
      };
    } catch (e) {
      print('❌ Error rejecting review: $e');
      return {
        'success': false,
        'message': 'Failed to reject review: ${e.toString()}',
      };
    }
  }

  // ===== BULK OPERATIONS =====

  /// Bulk approve multiple reviews
  Future<Map<String, dynamic>> bulkApproveReviews(
    List<String> reviewIds,
  ) async {
    try {
      if (!_enableBulkOperations) {
        return {
          'success': false,
          'message': 'Bulk operations feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      if (reviewIds.isEmpty) {
        return {
          'success': false,
          'message': 'No reviews selected for bulk approval',
        };
      }

      print('✅ Bulk approving ${reviewIds.length} reviews');

      final results = <String, dynamic>{
        'successful': <String>[],
        'failed': <Map<String, String>>[],
      };

      for (final reviewId in reviewIds) {
        try {
          final result = await approveReview(reviewId);
          if (result['success']) {
            results['successful'].add(reviewId);
          } else {
            results['failed'].add({
              'review_id': reviewId,
              'error': result['message'],
            });
          }
        } catch (e) {
          results['failed'].add({'review_id': reviewId, 'error': e.toString()});
        }
      }

      await _adminAuth.logAction(
        action: 'bulk_approve_reviews',
        resourceType: 'product_review',
        metadata: {
          'total_reviews': reviewIds.length,
          'successful_count': results['successful'].length,
          'failed_count': results['failed'].length,
          'review_ids': reviewIds,
        },
      );

      return {
        'success': true,
        'message': 'Bulk approval completed',
        'results': results,
        'total_processed': reviewIds.length,
        'successful_count': results['successful'].length,
        'failed_count': results['failed'].length,
      };
    } catch (e) {
      print('❌ Error in bulk approve: $e');
      return {
        'success': false,
        'message': 'Bulk approval failed: ${e.toString()}',
      };
    }
  }

  /// Bulk reject multiple reviews
  Future<Map<String, dynamic>> bulkRejectReviews(
    List<String> reviewIds,
    String rejectionReason,
  ) async {
    try {
      if (!_enableBulkOperations) {
        return {
          'success': false,
          'message': 'Bulk operations feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      if (reviewIds.isEmpty) {
        return {
          'success': false,
          'message': 'No reviews selected for bulk rejection',
        };
      }

      if (rejectionReason.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Rejection reason is required for bulk rejection',
        };
      }

      print('❌ Bulk rejecting ${reviewIds.length} reviews');

      final results = <String, dynamic>{
        'successful': <String>[],
        'failed': <Map<String, String>>[],
      };

      for (final reviewId in reviewIds) {
        try {
          final result = await rejectReview(reviewId, rejectionReason);
          if (result['success']) {
            results['successful'].add(reviewId);
          } else {
            results['failed'].add({
              'review_id': reviewId,
              'error': result['message'],
            });
          }
        } catch (e) {
          results['failed'].add({'review_id': reviewId, 'error': e.toString()});
        }
      }

      await _adminAuth.logAction(
        action: 'bulk_reject_reviews',
        resourceType: 'product_review',
        metadata: {
          'total_reviews': reviewIds.length,
          'successful_count': results['successful'].length,
          'failed_count': results['failed'].length,
          'rejection_reason': rejectionReason,
          'review_ids': reviewIds,
        },
      );

      return {
        'success': true,
        'message': 'Bulk rejection completed',
        'results': results,
        'total_processed': reviewIds.length,
        'successful_count': results['successful'].length,
        'failed_count': results['failed'].length,
      };
    } catch (e) {
      print('❌ Error in bulk reject: $e');
      return {
        'success': false,
        'message': 'Bulk rejection failed: ${e.toString()}',
      };
    }
  }

  // ===== PRODUCT REVIEW ANALYTICS =====

  /// Get review analytics for a specific product
  Future<Map<String, dynamic>> getProductReviewAnalytics(
    String productId,
  ) async {
    try {
      if (!_enableAdvancedAnalytics) {
        return {
          'success': false,
          'message': 'Advanced analytics feature is currently disabled',
        };
      }

      print('📊 Getting review analytics for product: $productId');

      // Get product review stats
      final stats = await _supabase
          .from('product_review_stats')
          .select('*')
          .eq('product_id', productId)
          .maybeSingle();

      // Get recent reviews for this product
      final recentReviews = await _supabase
          .from('product_reviews')
          .select('''
            *,
            customers!inner(full_name)
          ''')
          .eq('product_id', productId)
          .eq('moderation_status', 'approved')
          .order('created_at', ascending: false)
          .limit(5);

      await _adminAuth.logAction(
        action: 'get_product_review_analytics',
        resourceType: 'product_analytics',
        resourceId: productId,
        metadata: {
          'has_stats': stats != null,
          'recent_reviews_count': recentReviews.length,
        },
      );

      return {
        'success': true,
        'product_id': productId,
        'statistics':
            stats ??
            {
              'total_reviews': 0,
              'average_rating': 0.0,
              'rating_1_count': 0,
              'rating_2_count': 0,
              'rating_3_count': 0,
              'rating_4_count': 0,
              'rating_5_count': 0,
              'verified_reviews_count': 0,
              'verified_average_rating': 0.0,
            },
        'recent_reviews': recentReviews,
      };
    } catch (e) {
      print('❌ Error getting product review analytics: $e');
      return {
        'success': false,
        'message': 'Failed to retrieve analytics: ${e.toString()}',
      };
    }
  }

  // ===== UTILITY METHODS =====

  /// Check if review moderation feature is enabled
  bool get isReviewModerationEnabled => _enableReviewModeration;

  /// Check if bulk operations are enabled
  bool get isBulkOperationsEnabled => _enableBulkOperations;

  /// Check if advanced analytics are enabled
  bool get isAdvancedAnalyticsEnabled => _enableAdvancedAnalytics;

  /// Get moderation queue summary
  Future<Map<String, dynamic>> getModerationQueueSummary() async {
    try {
      final pendingReviews = await _supabase
          .from('product_reviews')
          .select('id')
          .eq('moderation_status', 'pending');
      final pendingCount = pendingReviews.length;

      final todayStart = DateTime.now().copyWith(
        hour: 0,
        minute: 0,
        second: 0,
        millisecond: 0,
      );

      final todayModeratedReviews = await _supabase
          .from('product_reviews')
          .select('id')
          .gte('moderated_at', todayStart.toIso8601String());
      final todayModerated = todayModeratedReviews.length;

      return {
        'success': true,
        'pending_reviews': pendingCount,
        'moderated_today': todayModerated,
        'queue_priority': pendingCount > 10
            ? 'high'
            : pendingCount > 5
            ? 'medium'
            : 'low',
      };
    } catch (e) {
      print('❌ Error getting moderation queue summary: $e');
      return {
        'success': false,
        'message': 'Failed to get queue summary: ${e.toString()}',
        'pending_reviews': 0,
        'moderated_today': 0,
        'queue_priority': 'unknown',
      };
    }
  }
}
