import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Individual review card for moderation
///
/// Displays:
/// - Review content and rating
/// - Customer and product information
/// - Moderation actions (approve/reject)
/// - Selection checkbox for bulk operations
class ReviewModerationCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final bool isSelected;
  final bool isSelectMode;
  final VoidCallback onToggleSelection;
  final VoidCallback? onApprove;
  final Function(String reason)? onReject;

  const ReviewModerationCard({
    super.key,
    required this.review,
    required this.isSelected,
    required this.isSelectMode,
    required this.onToggleSelection,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final customer = review['customers'] as Map<String, dynamic>? ?? {};
    final product = review['meat_products'] as Map<String, dynamic>? ?? {};
    final seller = product['sellers'] as Map<String, dynamic>? ?? {};

    final rating = review['rating'] as int? ?? 0;
    final reviewTitle = review['review_title'] as String? ?? '';
    final reviewText = review['review_text'] as String? ?? '';
    final isVerifiedPurchase = review['is_verified_purchase'] as bool? ?? false;
    final moderationStatus =
        review['moderation_status'] as String? ?? 'pending';
    final createdAt = review['created_at'] as String?;
    final moderatedAt = review['moderated_at'] as String?;
    final moderationReason = review['moderation_reason'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue.shade300 : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with selection and status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(moderationStatus).withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Selection checkbox
                if (isSelectMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelection(),
                    activeColor: Colors.blue.shade600,
                  ),

                // Customer info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            customer['full_name'] ?? 'Unknown Customer',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (isVerifiedPurchase) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Verified',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer['phone_number'] ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(moderationStatus),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    moderationStatus.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Review content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product info
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        product['name'] ?? 'Unknown Product',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (seller['seller_name'] != null) ...[
                      Text(
                        'by ${seller['seller_name']}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 12),

                // Rating
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber.shade600,
                        size: 18,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '$rating/5',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                // Review title
                if (reviewTitle.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    reviewTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                // Review text
                if (reviewText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    reviewText,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Timestamps
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'Submitted ${_formatDate(createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (moderatedAt != null) ...[
                      const SizedBox(width: 16),
                      Icon(
                        Icons.admin_panel_settings,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Moderated ${_formatDate(moderatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),

                // Moderation reason (for rejected reviews)
                if (moderationReason != null &&
                    moderationReason.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Rejection reason: $moderationReason',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons (only for pending reviews)
          if (moderationStatus == 'pending' &&
              (onApprove != null || onReject != null))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  if (onApprove != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                  if (onApprove != null && onReject != null)
                    const SizedBox(width: 12),

                  if (onReject != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showRejectDialog(context),
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Reject'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cancel, color: Colors.red),
              SizedBox(width: 8),
              Text('Reject Review'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please provide a reason for rejecting this review:'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter rejection reason...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please provide a rejection reason'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(context).pop();
                onReject?.call(reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade600;
      case 'approved':
        return Colors.green.shade600;
      case 'rejected':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return DateFormat('MMM d, y').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
  }
}
