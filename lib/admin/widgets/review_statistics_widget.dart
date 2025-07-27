import 'package:flutter/material.dart';

/// Widget to display review statistics and analytics
///
/// Shows key metrics like:
/// - Total reviews by status
/// - Rating distribution
/// - Recent activity
/// - Moderation queue priority
class ReviewStatisticsWidget extends StatelessWidget {
  final Map<String, dynamic> statistics;

  const ReviewStatisticsWidget({super.key, required this.statistics});

  @override
  Widget build(BuildContext context) {
    final statusDistribution =
        statistics['status_distribution'] as Map<String, dynamic>? ?? {};
    final ratingDistribution =
        statistics['rating_distribution'] as Map<String, dynamic>? ?? {};
    final totalReviews = statistics['total_reviews'] as int? ?? 0;
    final recentReviewsCount = statistics['recent_reviews_count'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Colors.green.shade600,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Review Analytics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '$totalReviews Total Reviews',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Statistics Grid
          Row(
            children: [
              // Status Distribution
              Expanded(
                flex: 2,
                child: _buildStatusDistribution(context, statusDistribution),
              ),

              const SizedBox(width: 24),

              // Rating Distribution
              Expanded(
                flex: 2,
                child: _buildRatingDistribution(context, ratingDistribution),
              ),

              const SizedBox(width: 24),

              // Recent Activity
              Expanded(
                child: _buildRecentActivity(context, recentReviewsCount),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistribution(
    BuildContext context,
    Map<String, dynamic> statusDistribution,
  ) {
    final pending = statusDistribution['pending'] as int? ?? 0;
    final approved = statusDistribution['approved'] as int? ?? 0;
    final rejected = statusDistribution['rejected'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Moderation Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),

          // Status Items
          _buildStatusItem(
            context,
            'Pending',
            pending,
            Colors.orange.shade600,
            Icons.pending_actions,
          ),
          const SizedBox(height: 8),
          _buildStatusItem(
            context,
            'Approved',
            approved,
            Colors.green.shade600,
            Icons.check_circle,
          ),
          const SizedBox(height: 8),
          _buildStatusItem(
            context,
            'Rejected',
            rejected,
            Colors.red.shade600,
            Icons.cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingDistribution(
    BuildContext context,
    Map<String, dynamic> ratingDistribution,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rating Distribution',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),

          // Rating bars
          for (int rating = 5; rating >= 1; rating--)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildRatingBar(
                context,
                rating,
                ratingDistribution[rating.toString()] as int? ?? 0,
                _getTotalRatings(ratingDistribution),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(
    BuildContext context,
    int rating,
    int count,
    int total,
  ) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Row(
      children: [
        // Stars
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            rating,
            (index) => Icon(Icons.star, size: 12, color: Colors.amber.shade600),
          ),
        ),
        const SizedBox(width: 8),

        // Progress bar
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.amber.shade600,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Count
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, int recentCount) {
    final priority = _getQueuePriority(recentCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),

          // Recent count
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Text(
                'Last 7 days',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            recentCount.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade600,
            ),
          ),

          const SizedBox(height: 12),

          // Priority indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: priority['color'].withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(priority['icon'], size: 12, color: priority['color']),
                const SizedBox(width: 4),
                Text(
                  priority['label'],
                  style: TextStyle(
                    color: priority['color'],
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getTotalRatings(Map<String, dynamic> ratingDistribution) {
    return ratingDistribution.values.whereType<int>().fold(
      0,
      (sum, count) => sum + count,
    );
  }

  Map<String, dynamic> _getQueuePriority(int recentCount) {
    if (recentCount > 20) {
      return {
        'label': 'High Activity',
        'color': Colors.red.shade600,
        'icon': Icons.trending_up,
      };
    } else if (recentCount > 10) {
      return {
        'label': 'Medium Activity',
        'color': Colors.orange.shade600,
        'icon': Icons.trending_flat,
      };
    } else {
      return {
        'label': 'Low Activity',
        'color': Colors.green.shade600,
        'icon': Icons.trending_down,
      };
    }
  }
}
