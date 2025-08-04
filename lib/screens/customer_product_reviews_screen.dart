import 'package:flutter/material.dart';
import '../services/product_review_service.dart';
import '../widgets/product_review_widget.dart';
import 'customer_review_submission_screen.dart';

/// Customer Product Reviews Screen
///
/// Displays all reviews for a specific product with sorting and filtering options
/// Allows customers to view reviews and submit their own if eligible
class CustomerProductReviewsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic>? customer;

  const CustomerProductReviewsScreen({
    super.key,
    required this.product,
    this.customer,
  });

  @override
  State<CustomerProductReviewsScreen> createState() =>
      _CustomerProductReviewsScreenState();
}

class _CustomerProductReviewsScreenState
    extends State<CustomerProductReviewsScreen> {
  final ProductReviewService _reviewService = ProductReviewService();

  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  bool _hasMore = true;
  String _sortBy = 'newest';
  String? _errorMessage;
  int _currentOffset = 0;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _reviews.clear();
        _currentOffset = 0;
        _hasMore = true;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await _reviewService.getProductReviews(
        productId: widget.product['id'],
        limit: _limit,
        offset: _currentOffset,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          if (result['success']) {
            if (refresh) {
              _reviews = List<Map<String, dynamic>>.from(result['reviews']);
            } else {
              _reviews.addAll(
                List<Map<String, dynamic>>.from(result['reviews']),
              );
            }
            _hasMore = result['hasMore'] ?? false;
            _currentOffset += (result['count'] ?? 0) as int;
          } else {
            _errorMessage = result['message'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load reviews';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Product Reviews',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF059669),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.customer != null)
            IconButton(
              icon: const Icon(Icons.rate_review),
              onPressed: _navigateToReviewSubmission,
              tooltip: 'Write a Review',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSortingOptions(),
          Expanded(child: _buildReviewsList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Product image placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: Colors.grey, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.product['name'] ?? 'Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProductReviewSummary(
                      productId: widget.product['id'],
                      showFullStats: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.customer != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToReviewSubmission,
                icon: const Icon(Icons.rate_review),
                label: const Text('Write a Review'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortingOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Text(
            'Sort by:',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Newest', 'newest'),
                  _buildSortChip('Oldest', 'oldest'),
                  _buildSortChip('Highest Rated', 'highest_rated'),
                  _buildSortChip('Lowest Rated', 'lowest_rated'),
                  _buildSortChip('Most Helpful', 'most_helpful'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          if (selected && _sortBy != value) {
            setState(() {
              _sortBy = value;
            });
            _loadReviews(refresh: true);
          }
        },
        selectedColor: const Color(0xFF059669),
        backgroundColor: Colors.grey[100],
        side: BorderSide(
          color: isSelected ? const Color(0xFF059669) : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    if (_isLoading && _reviews.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadReviews(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
              ),
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
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No reviews yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to review this product!',
              style: TextStyle(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (widget.customer != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _navigateToReviewSubmission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Write the First Review'),
              ),
            ],
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                ),
              ),
            );
          }

          return ReviewCard(
            review: _reviews[index],
            currentCustomerId: widget.customer?['id'],
            onHelpfulnessChanged: () {
              // Refresh the current review to update helpfulness counts
              _loadReviews(refresh: true);
            },
          );
        },
      ),
    );
  }

  Future<void> _navigateToReviewSubmission() async {
    if (widget.customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to write a review'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerReviewSubmissionScreen(
          product: widget.product,
          customer: widget.customer!,
        ),
      ),
    );

    // If review was submitted, refresh the reviews list
    if (result == true) {
      _loadReviews(refresh: true);
    }
  }
}
