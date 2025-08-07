import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/product_review_service.dart';
import '../services/product_review_cache.dart'; // Phase 4I: Performance optimization

/// Product Review Summary Widget
///
/// Displays review statistics and rating breakdown for a product
/// Used in product catalog and product detail views
class ProductReviewSummary extends StatefulWidget {
  final String productId;
  final bool showFullStats;

  const ProductReviewSummary({
    super.key,
    required this.productId,
    this.showFullStats = false,
  });

  @override
  State<ProductReviewSummary> createState() => _ProductReviewSummaryState();
}

class _ProductReviewSummaryState extends State<ProductReviewSummary> {
  final ProductReviewService _reviewService = ProductReviewService();
  final ProductReviewCache _reviewCache =
      ProductReviewCache(); // Phase 4I: Performance optimization
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviewStats();
  }

  /// Phase 4I: Optimized review stats loading with caching
  Future<void> _loadReviewStats() async {
    // Check cache first
    final cachedStats = _reviewCache.getCachedReviewStats(widget.productId);
    if (cachedStats != null) {
      if (mounted) {
        setState(() {
          _stats = cachedStats;
          _isLoading = false;
        });
      }
      return;
    }

    // Fetch from API if not cached
    final result = await _reviewService.getProductReviewStats(widget.productId);
    if (mounted) {
      final stats = result['success'] ? result['stats'] : null;

      // Cache the result
      if (stats != null) {
        _reviewCache.cacheReviewStats(widget.productId, stats);
      }

      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 20,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_stats == null || _stats!['total_reviews'] == 0) {
      return const Row(
        children: [
          Icon(Icons.star_border, color: Colors.grey, size: 16),
          SizedBox(width: 4),
          Text(
            'No reviews yet',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      );
    }

    final totalReviews = _stats!['total_reviews'] ?? 0;
    final averageRating = (_stats!['average_rating'] ?? 0.0).toDouble();

    if (widget.showFullStats) {
      return _buildFullStats(totalReviews, averageRating);
    } else {
      return _buildCompactStats(totalReviews, averageRating);
    }
  }

  Widget _buildCompactStats(int totalReviews, double averageRating) {
    return Row(
      children: [
        _buildStarRating(averageRating, size: 16),
        const SizedBox(width: 4),
        Text(
          averageRating.toStringAsFixed(1),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          '($totalReviews)',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFullStats(int totalReviews, double averageRating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildStarRating(averageRating, size: 20),
            const SizedBox(width: 8),
            Text(
              averageRating.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(
              '$totalReviews review${totalReviews != 1 ? 's' : ''}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRatingBreakdown(),
      ],
    );
  }

  Widget _buildRatingBreakdown() {
    final totalReviews = _stats!['total_reviews'] ?? 0;
    if (totalReviews == 0) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 5; i >= 1; i--)
          _buildRatingBar(i, _stats!['rating_${i}_count'] ?? 0, totalReviews),
      ],
    );
  }

  Widget _buildRatingBar(int stars, int count, int total) {
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$stars', style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.amber, size: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        IconData iconData;
        Color color;

        if (rating >= starValue) {
          iconData = Icons.star;
          color = Colors.amber;
        } else if (rating >= starValue - 0.5) {
          iconData = Icons.star_half;
          color = Colors.amber;
        } else {
          iconData = Icons.star_border;
          color = Colors.grey;
        }

        return Icon(iconData, color: color, size: size);
      }),
    );
  }
}

/// Star Rating Input Widget
///
/// Allows users to select a rating from 1-5 stars
class StarRatingInput extends StatefulWidget {
  final int initialRating;
  final ValueChanged<int> onRatingChanged;
  final double size;

  const StarRatingInput({
    super.key,
    this.initialRating = 0,
    required this.onRatingChanged,
    this.size = 32,
  });

  @override
  State<StarRatingInput> createState() => _StarRatingInputState();
}

class _StarRatingInputState extends State<StarRatingInput> {
  int _currentRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return GestureDetector(
          onTap: () {
            setState(() {
              _currentRating = starValue;
            });
            widget.onRatingChanged(starValue);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              starValue <= _currentRating ? Icons.star : Icons.star_border,
              color: starValue <= _currentRating ? Colors.amber : Colors.grey,
              size: widget.size,
            ),
          ),
        );
      }),
    );
  }
}

/// Review Card Widget
///
/// Displays an individual review with rating, text, and helpfulness voting
class ReviewCard extends StatefulWidget {
  final Map<String, dynamic> review;
  final String? currentCustomerId;
  final VoidCallback? onHelpfulnessChanged;

  const ReviewCard({
    super.key,
    required this.review,
    this.currentCustomerId,
    this.onHelpfulnessChanged,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  final ProductReviewService _reviewService = ProductReviewService();
  bool _isVoting = false;

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final customerName = review['customers']?['name'] ?? 'Anonymous';
    final rating = review['rating'] ?? 0;
    final reviewTitle = review['review_title'];
    final reviewText = review['review_text'];
    final isVerified = review['is_verified_purchase'] ?? false;
    final helpfulCount = review['helpful_count'] ?? 0;
    final unhelpfulCount = review['unhelpful_count'] ?? 0;
    final createdAt = DateTime.parse(review['created_at']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with rating and customer info
            Row(
              children: [
                _buildStarRating(rating.toDouble()),
                const SizedBox(width: 8),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Verified Purchase',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer name
            Text(
              customerName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),

            // Review title
            if (reviewTitle != null && reviewTitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                reviewTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ],

            // Review text
            if (reviewText != null && reviewText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(reviewText, style: const TextStyle(fontSize: 14)),
            ],

            // Helpfulness voting
            if (widget.currentCustomerId != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Was this helpful?',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  _buildHelpfulnessButton(true, helpfulCount),
                  const SizedBox(width: 8),
                  _buildHelpfulnessButton(false, unhelpfulCount),
                ],
              ),
            ] else if (helpfulCount > 0 || unhelpfulCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.thumb_up, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$helpfulCount',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.thumb_down, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$unhelpfulCount',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating ? Colors.amber : Colors.grey,
          size: 16,
        );
      }),
    );
  }

  Widget _buildHelpfulnessButton(bool isHelpful, int count) {
    return GestureDetector(
      onTap: _isVoting ? null : () => _voteHelpfulness(isHelpful),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isHelpful ? Icons.thumb_up : Icons.thumb_down,
              size: 14,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _voteHelpfulness(bool isHelpful) async {
    if (widget.currentCustomerId == null) return;

    setState(() {
      _isVoting = true;
    });

    final result = await _reviewService.voteReviewHelpfulness(
      reviewId: widget.review['id'],
      customerId: widget.currentCustomerId!,
      isHelpful: isHelpful,
    );

    if (mounted) {
      setState(() {
        _isVoting = false;
      });

      if (result['success']) {
        widget.onHelpfulnessChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  }
}
