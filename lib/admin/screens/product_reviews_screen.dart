import 'package:flutter/material.dart';
import '../services/product_review_service.dart';
import '../widgets/admin_layout.dart';
import '../widgets/review_moderation_card.dart';
import '../widgets/review_statistics_widget.dart';
import '../widgets/bulk_action_bar.dart';

/// Product Reviews Management Screen for Admin Panel
///
/// Features:
/// - Review moderation queue
/// - Bulk approval/rejection
/// - Review statistics and analytics
/// - Search and filtering capabilities
/// - Zero-risk implementation with feature flags
class ProductReviewsScreen extends StatefulWidget {
  const ProductReviewsScreen({super.key});

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen>
    with TickerProviderStateMixin {
  final ProductReviewService _reviewService = ProductReviewService();

  // Tab controller for different views
  late TabController _tabController;

  // Data state
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = false;
  String? _error;

  // Filtering and pagination
  String _currentFilter = 'pending';
  int _currentPage = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;

  // Selection state for bulk operations
  final Set<String> _selectedReviewIds = {};
  bool _isSelectMode = false;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedReviewIds.clear();
        _isSelectMode = false;
      });

      switch (_tabController.index) {
        case 0:
          _setFilter('pending');
          break;
        case 1:
          _setFilter('approved');
          break;
        case 2:
          _setFilter('rejected');
          break;
      }
    }
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadReviews(reset: true), _loadStatistics()]);
  }

  Future<void> _loadReviews({bool reset = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (reset) {
        _reviews.clear();
        _currentPage = 0;
        _hasMore = true;
      }
      _error = null;
    });

    try {
      final result = await _reviewService.getReviews(
        moderationStatus: _currentFilter,
        limit: _pageSize,
        offset: reset ? 0 : _currentPage * _pageSize,
        orderBy: 'created_at',
        ascending: _currentFilter == 'pending', // Oldest first for pending
      );

      if (result['success']) {
        setState(() {
          if (reset) {
            _reviews = List<Map<String, dynamic>>.from(result['reviews']);
          } else {
            _reviews.addAll(List<Map<String, dynamic>>.from(result['reviews']));
          }
          _hasMore = result['has_more'] ?? false;
          if (!reset) _currentPage++;
        });
      } else {
        setState(() {
          _error = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load reviews: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatistics() async {
    try {
      final result = await _reviewService.getReviewStatistics();
      if (result['success']) {
        setState(() {
          _statistics = result;
        });
      }
    } catch (e) {
      print('Failed to load statistics: $e');
    }
  }

  void _setFilter(String filter) {
    if (_currentFilter != filter) {
      setState(() {
        _currentFilter = filter;
        _selectedReviewIds.clear();
        _isSelectMode = false;
      });
      _loadReviews(reset: true);
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      if (!_isSelectMode) {
        _selectedReviewIds.clear();
      }
    });
  }

  void _toggleReviewSelection(String reviewId) {
    setState(() {
      if (_selectedReviewIds.contains(reviewId)) {
        _selectedReviewIds.remove(reviewId);
      } else {
        _selectedReviewIds.add(reviewId);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      for (final review in _reviews) {
        _selectedReviewIds.add(review['id']);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedReviewIds.clear();
    });
  }

  Future<void> _handleSingleReviewAction(
    String reviewId,
    String action, {
    String? reason,
  }) async {
    try {
      Map<String, dynamic> result;

      if (action == 'approve') {
        result = await _reviewService.approveReview(reviewId);
      } else if (action == 'reject' && reason != null) {
        result = await _reviewService.rejectReview(reviewId, reason);
      } else {
        return;
      }

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviews(reset: true);
        _loadStatistics();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Action failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleBulkAction(String action, {String? reason}) async {
    if (_selectedReviewIds.isEmpty) return;

    try {
      Map<String, dynamic> result;

      if (action == 'approve') {
        result = await _reviewService.bulkApproveReviews(
          _selectedReviewIds.toList(),
        );
      } else if (action == 'reject' && reason != null) {
        result = await _reviewService.bulkRejectReviews(
          _selectedReviewIds.toList(),
          reason,
        );
      } else {
        return;
      }

      if (result['success']) {
        final successCount = result['successful_count'] ?? 0;
        final failedCount = result['failed_count'] ?? 0;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bulk $action completed: $successCount successful, $failedCount failed',
            ),
            backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
          ),
        );

        setState(() {
          _selectedReviewIds.clear();
          _isSelectMode = false;
        });

        _loadReviews(reset: true);
        _loadStatistics();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bulk action failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Product Reviews',
      child: Column(
        children: [
          // Statistics Overview
          if (_statistics.isNotEmpty)
            ReviewStatisticsWidget(statistics: _statistics),

          const SizedBox(height: 24),

          // Tab Bar and Controls
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Tab Bar
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pending_actions, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Pending (${_statistics['status_distribution']?['pending'] ?? 0})',
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Approved (${_statistics['status_distribution']?['approved'] ?? 0})',
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cancel, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Rejected (${_statistics['status_distribution']?['rejected'] ?? 0})',
                          ),
                        ],
                      ),
                    ),
                  ],
                  labelColor: Colors.green.shade600,
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: Colors.green.shade600,
                ),

                // Action Bar
                if (_currentFilter == 'pending')
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Search
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search reviews...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                              // TODO: Implement search functionality
                            },
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Select Mode Toggle
                        ElevatedButton.icon(
                          onPressed: _toggleSelectMode,
                          icon: Icon(
                            _isSelectMode ? Icons.close : Icons.checklist,
                          ),
                          label: Text(_isSelectMode ? 'Cancel' : 'Select'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSelectMode
                                ? Colors.grey.shade600
                                : Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bulk Action Bar
          if (_isSelectMode && _selectedReviewIds.isNotEmpty)
            BulkActionBar(
              selectedCount: _selectedReviewIds.length,
              onSelectAll: _selectAllVisible,
              onClearSelection: _clearSelection,
              onBulkApprove: () => _handleBulkAction('approve'),
              onBulkReject: (reason) =>
                  _handleBulkAction('reject', reason: reason),
            ),

          // Reviews List
          Expanded(child: _buildReviewsList()),
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_isLoading && _reviews.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error loading reviews',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadReviews(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${_currentFilter} reviews',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _currentFilter == 'pending'
                  ? 'All reviews have been moderated'
                  : 'No reviews found with this status',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (!_isLoading &&
            _hasMore &&
            scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
          _loadReviews();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reviews.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _reviews.length) {
            // Loading indicator for pagination
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            );
          }

          final review = _reviews[index];
          final isSelected = _selectedReviewIds.contains(review['id']);

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ReviewModerationCard(
              review: review,
              isSelected: isSelected,
              isSelectMode: _isSelectMode,
              onToggleSelection: () => _toggleReviewSelection(review['id']),
              onApprove: _currentFilter == 'pending'
                  ? () => _handleSingleReviewAction(review['id'], 'approve')
                  : null,
              onReject: _currentFilter == 'pending'
                  ? (reason) => _handleSingleReviewAction(
                      review['id'],
                      'reject',
                      reason: reason,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
