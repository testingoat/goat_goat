import 'package:flutter/material.dart';
import '../services/order_tracking_service.dart';
import '../config/feature_flags.dart';

/// Customer Order History Screen for Phase 1.1 implementation
///
/// This screen provides customers with a comprehensive view of their order history
/// and tracking information using the existing emerald theme and design patterns.
///
/// Key features:
/// - Order history list with status indicators
/// - Order details view with tracking timeline
/// - Order summary statistics
/// - Follows existing UI patterns from the app
/// - Feature flag protected for gradual rollout
class CustomerOrderHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerOrderHistoryScreen({Key? key, required this.customer})
    : super(key: key);

  @override
  State<CustomerOrderHistoryScreen> createState() =>
      _CustomerOrderHistoryScreenState();
}

class _CustomerOrderHistoryScreenState
    extends State<CustomerOrderHistoryScreen> {
  final OrderTrackingService _orderTrackingService = OrderTrackingService();

  List<Map<String, dynamic>> _orders = [];
  Map<String, dynamic>? _orderStats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrderHistory();

    // Log feature usage
    FeatureFlags.logFeatureUsage('order_history', 'screen_opened');
  }

  /// Load customer order history and statistics
  Future<void> _loadOrderHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Check feature flag
      if (!FeatureFlags.isEnabled('order_history')) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Order history feature is not available';
        });
        return;
      }

      final customerId = widget.customer['id'] as String;

      // Load orders and statistics concurrently
      final results = await Future.wait([
        _orderTrackingService.getCustomerOrderHistory(customerId),
        _orderTrackingService.getOrderSummaryStats(customerId),
      ]);

      setState(() {
        _orders = results[0] as List<Map<String, dynamic>>;
        _orderStats = results[1] as Map<String, dynamic>;
        _isLoading = false;
      });

      print('📦 ORDER HISTORY - Loaded ${_orders.length} orders for customer');
    } catch (e) {
      print('❌ ORDER HISTORY - Error loading data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load order history. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// Build app bar with emerald theme
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Order History',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.green[600],
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        // Beta indicator if feature is in beta
        if (FeatureFlags.isFeatureBeta('order_history'))
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange[600],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'BETA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// Build main body content
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOrderHistory,
      color: Colors.green[600],
      child: Column(
        children: [
          // Order statistics summary
          if (_orderStats != null) _buildOrderStatistics(),

          // Orders list
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your order history...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadOrderHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Orders Yet',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start shopping to see your orders here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build order statistics summary
  Widget _buildOrderStatistics() {
    final stats = _orderStats!;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green[200]!.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Orders',
                  '${stats['total_orders']}',
                  Icons.shopping_bag,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Spent',
                  '₹${(stats['total_spent'] as double).toStringAsFixed(0)}',
                  Icons.currency_rupee,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Delivered',
                  '${stats['delivered_orders']}',
                  Icons.done_all,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Pending',
                  '${stats['pending_orders']}',
                  Icons.hourglass_empty,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build individual statistic item
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
        ),
      ],
    );
  }

  /// Build orders list
  Widget _buildOrdersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  /// Build individual order card
  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['id'] as String;
    final orderIdShort = orderId.substring(0, 8);
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final createdAt = DateTime.parse(order['created_at']);
    final trackingStatus = order['tracking_status'] as String? ?? 'Processing';
    final statusColor = _getStatusColor(
      order['status_color'] as String? ?? 'grey',
    );
    final totalItems = order['total_items'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showOrderDetails(order),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #$orderIdShort',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        trackingStatus,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Order details
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.shopping_cart,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalItems items',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Amount and action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showOrderDetails(order),
                      child: Text(
                        'View Details',
                        style: TextStyle(color: Colors.green[600]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get color for status
  Color _getStatusColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green[600]!;
      case 'orange':
        return Colors.orange[600]!;
      case 'blue':
        return Colors.blue[600]!;
      case 'red':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference} days ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  /// Show order details dialog
  void _showOrderDetails(Map<String, dynamic> order) {
    FeatureFlags.logFeatureUsage('order_history', 'view_order_details');

    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(order: order),
    );
  }
}

/// Order Details Dialog
///
/// Shows detailed information about a specific order including tracking timeline
class OrderDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsDialog({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {
  final OrderTrackingService _orderTrackingService = OrderTrackingService();
  List<Map<String, dynamic>> _statusHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final orderId = widget.order['id'] as String;
      final statusHistory = await _orderTrackingService.getOrderStatusHistory(
        orderId,
      );

      setState(() {
        _statusHistory = statusHistory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green[600],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Order #${(widget.order['id'] as String).substring(0, 8)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order info
                          _buildOrderInfo(),
                          const SizedBox(height: 20),

                          // Tracking timeline
                          if (_statusHistory.isNotEmpty) ...[
                            const Text(
                              'Order Tracking',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTrackingTimeline(),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo() {
    final totalAmount =
        (widget.order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final createdAt = DateTime.parse(widget.order['created_at']);
    final totalItems = widget.order['total_items'] as int? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Amount:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '₹${totalAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Order Date:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('${createdAt.day}/${createdAt.month}/${createdAt.year}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Items:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('$totalItems items'),
          ],
        ),
      ],
    );
  }

  Widget _buildTrackingTimeline() {
    return Column(
      children: _statusHistory.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isLast = index == _statusHistory.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: status['is_completed']
                        ? _getStatusColor(status['color'])
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(status['icon']),
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                if (!isLast)
                  Container(width: 2, height: 40, color: Colors.grey[300]),
              ],
            ),
            const SizedBox(width: 12),

            // Status content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: status['is_completed']
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status['description'],
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (status['timestamp'] != null)
                      Text(
                        _formatTimestamp(status['timestamp']),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getStatusColor(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green[600]!;
      case 'orange':
        return Colors.orange[600]!;
      case 'blue':
        return Colors.blue[600]!;
      case 'red':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  IconData _getStatusIcon(String iconName) {
    switch (iconName) {
      case 'check_circle':
        return Icons.check_circle;
      case 'assignment_turned_in':
        return Icons.assignment_turned_in;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'done_all':
        return Icons.done_all;
      case 'cancel':
        return Icons.cancel;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return '${date.day}/${date.month} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
