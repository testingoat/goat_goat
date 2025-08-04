import 'package:supabase_flutter/supabase_flutter.dart';

/// Product Review Service
///
/// Handles all product review operations including:
/// - Verified purchase checking
/// - Review submission and management
/// - Review statistics and analytics
/// - Helpfulness voting
/// - Admin moderation support
///
/// Follows zero-risk implementation pattern with no modifications to existing services
class ProductReviewService {
  static final ProductReviewService _instance =
      ProductReviewService._internal();
  factory ProductReviewService() => _instance;
  ProductReviewService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if customer can review a specific product
  /// Requires verified purchase (product in customer's order history)
  Future<Map<String, dynamic>> canCustomerReview({
    required String customerId,
    required String productId,
  }) async {
    try {
      print(
        '🔍 Checking if customer $customerId can review product $productId',
      );

      // Check if customer has purchased this product
      final purchaseCheck = await _supabase
          .from('order_items')
          .select('''
            id,
            order_id,
            orders!inner(
              id,
              customer_id,
              status
            )
          ''')
          .eq('product_id', productId)
          .eq('orders.customer_id', customerId)
          .or(
            'orders.status.eq.confirmed,orders.status.eq.delivered,orders.status.eq.completed',
          );

      if (purchaseCheck.isEmpty) {
        return {
          'canReview': false,
          'reason': 'no_purchase',
          'message': 'You can only review products you have purchased',
        };
      }

      // Check if customer has already reviewed this product
      final existingReview = await _supabase
          .from('product_reviews')
          .select('id, moderation_status')
          .eq('product_id', productId)
          .eq('customer_id', customerId)
          .maybeSingle();

      if (existingReview != null) {
        return {
          'canReview': false,
          'reason': 'already_reviewed',
          'message': 'You have already reviewed this product',
          'existingReview': existingReview,
        };
      }

      // Customer can review - return purchase details
      final orderItem = purchaseCheck.first;
      return {
        'canReview': true,
        'orderId': orderItem['order_id'],
        'orderItemId': orderItem['id'],
        'message': 'You can review this product',
      };
    } catch (e) {
      print('❌ Error checking review eligibility: $e');
      return {
        'canReview': false,
        'reason': 'error',
        'message': 'Unable to verify purchase history',
      };
    }
  }

  /// Submit a new product review
  Future<Map<String, dynamic>> submitReview({
    required String customerId,
    required String productId,
    required int rating,
    String? reviewTitle,
    String? reviewText,
    String? orderId,
    String? orderItemId,
  }) async {
    try {
      print(
        '📝 Submitting review for product $productId by customer $customerId',
      );

      // Validate rating
      if (rating < 1 || rating > 5) {
        return {
          'success': false,
          'message': 'Rating must be between 1 and 5 stars',
        };
      }

      // Check if customer can review this product
      final eligibilityCheck = await canCustomerReview(
        customerId: customerId,
        productId: productId,
      );

      if (!eligibilityCheck['canReview']) {
        return {'success': false, 'message': eligibilityCheck['message']};
      }

      // Use order details from eligibility check if not provided
      final finalOrderId = orderId ?? eligibilityCheck['orderId'];
      final finalOrderItemId = orderItemId ?? eligibilityCheck['orderItemId'];

      // Insert review
      final reviewData = {
        'product_id': productId,
        'customer_id': customerId,
        'order_id': finalOrderId,
        'order_item_id': finalOrderItemId,
        'rating': rating,
        'review_title': reviewTitle?.trim(),
        'review_text': reviewText?.trim(),
        'is_verified_purchase': true, // Always true since we verified purchase
        'moderation_status': 'pending', // Requires admin approval
      };

      final result = await _supabase
          .from('product_reviews')
          .insert(reviewData)
          .select()
          .single();

      print('✅ Review submitted successfully: ${result['id']}');

      return {
        'success': true,
        'message': 'Review submitted successfully and is pending approval',
        'reviewId': result['id'],
        'review': result,
      };
    } catch (e) {
      print('❌ Error submitting review: $e');
      return {
        'success': false,
        'message': 'Failed to submit review. Please try again.',
      };
    }
  }

  /// Get reviews for a specific product
  Future<Map<String, dynamic>> getProductReviews({
    required String productId,
    int limit = 20,
    int offset = 0,
    String sortBy =
        'newest', // newest, oldest, highest_rated, lowest_rated, most_helpful
  }) async {
    try {
      print('📖 Fetching reviews for product $productId');

      // Build order clause based on sort preference
      String orderClause;
      switch (sortBy) {
        case 'oldest':
          orderClause = 'created_at.asc';
          break;
        case 'highest_rated':
          orderClause = 'rating.desc,created_at.desc';
          break;
        case 'lowest_rated':
          orderClause = 'rating.asc,created_at.desc';
          break;
        case 'most_helpful':
          orderClause = 'helpful_count.desc,created_at.desc';
          break;
        case 'newest':
        default:
          orderClause = 'created_at.desc';
          break;
      }

      // Fetch approved reviews with customer details
      final reviews = await _supabase
          .from('product_reviews')
          .select('''
            id,
            rating,
            review_title,
            review_text,
            is_verified_purchase,
            helpful_count,
            unhelpful_count,
            created_at,
            customers!inner(
              id,
              name
            )
          ''')
          .eq('product_id', productId)
          .eq('moderation_status', 'approved')
          .order(orderClause)
          .range(offset, offset + limit - 1);

      print('✅ Found ${reviews.length} reviews for product');

      return {
        'success': true,
        'reviews': reviews,
        'count': reviews.length,
        'hasMore': reviews.length == limit,
      };
    } catch (e) {
      print('❌ Error fetching product reviews: $e');
      return {
        'success': false,
        'message': 'Failed to load reviews',
        'reviews': [],
        'count': 0,
      };
    }
  }

  /// Get review statistics for a product
  Future<Map<String, dynamic>> getProductReviewStats(String productId) async {
    try {
      print('📊 Fetching review stats for product $productId');

      final stats = await _supabase
          .from('product_review_stats')
          .select('*')
          .eq('product_id', productId)
          .maybeSingle();

      if (stats == null) {
        // No reviews yet
        return {
          'success': true,
          'stats': {
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
        };
      }

      return {'success': true, 'stats': stats};
    } catch (e) {
      print('❌ Error fetching review stats: $e');
      return {'success': false, 'message': 'Failed to load review statistics'};
    }
  }

  /// Get customer's review for a specific product
  Future<Map<String, dynamic>?> getCustomerReview({
    required String customerId,
    required String productId,
  }) async {
    try {
      final review = await _supabase
          .from('product_reviews')
          .select('*')
          .eq('product_id', productId)
          .eq('customer_id', customerId)
          .maybeSingle();

      return review;
    } catch (e) {
      print('❌ Error fetching customer review: $e');
      return null;
    }
  }

  /// Vote on review helpfulness
  Future<Map<String, dynamic>> voteReviewHelpfulness({
    required String reviewId,
    required String customerId,
    required bool isHelpful,
  }) async {
    try {
      print('👍 Voting on review $reviewId helpfulness: $isHelpful');

      // Upsert helpfulness vote
      await _supabase.from('review_helpfulness').upsert({
        'review_id': reviewId,
        'customer_id': customerId,
        'is_helpful': isHelpful,
      });

      // Update helpfulness counts on the review
      await _updateReviewHelpfulnessCounts(reviewId);

      return {'success': true, 'message': 'Thank you for your feedback!'};
    } catch (e) {
      print('❌ Error voting on review helpfulness: $e');
      return {'success': false, 'message': 'Failed to record your vote'};
    }
  }

  /// Update helpfulness counts for a review
  Future<void> _updateReviewHelpfulnessCounts(String reviewId) async {
    try {
      // Get helpfulness counts
      final helpfulCount = await _supabase
          .from('review_helpfulness')
          .select('id')
          .eq('review_id', reviewId)
          .eq('is_helpful', true);

      final unhelpfulCount = await _supabase
          .from('review_helpfulness')
          .select('id')
          .eq('review_id', reviewId)
          .eq('is_helpful', false);

      // Update review with new counts
      await _supabase
          .from('product_reviews')
          .update({
            'helpful_count': helpfulCount.length,
            'unhelpful_count': unhelpfulCount.length,
          })
          .eq('id', reviewId);
    } catch (e) {
      print('❌ Error updating helpfulness counts: $e');
    }
  }
}
