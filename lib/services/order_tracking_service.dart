import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase_service.dart';
import '../config/feature_flags.dart';

/// Order Tracking Service for Phase 1.1 implementation
/// 
/// This service provides order history and tracking functionality for customers
/// using the existing order infrastructure without modifying core services.
/// 
/// Key principles:
/// - Uses composition over modification (leverages existing SupabaseService)
/// - No database schema changes (uses existing orders and order_items tables)
/// - Zero risk to existing functionality
/// - Feature flag protected for gradual rollout
class OrderTrackingService {
  static final OrderTrackingService _instance = OrderTrackingService._internal();
  factory OrderTrackingService() => _instance;
  OrderTrackingService._internal();

  // Use existing services through composition (not modification)
  final SupabaseService _supabaseService = SupabaseService();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get complete order history for a customer
  /// 
  /// This method leverages the existing SupabaseService.getOrders() method
  /// and enhances it with additional order tracking information
  Future<List<Map<String, dynamic>>> getCustomerOrderHistory(String customerId) async {
    try {
      // Feature flag check
      if (!FeatureFlags.isEnabled('order_history')) {
        return [];
      }

      FeatureFlags.logFeatureUsage('order_history', 'get_customer_orders');

      print('📦 ORDER TRACKING - Loading order history for customer: $customerId');

      // Use existing service method through composition
      final orders = await _supabaseService.getOrders(
        customerId: customerId,
        limit: 100, // Get last 100 orders
      );

      // Enhance orders with tracking information
      final enhancedOrders = <Map<String, dynamic>>[];
      
      for (final order in orders) {
        final enhancedOrder = await _enhanceOrderWithTrackingInfo(order);
        enhancedOrders.add(enhancedOrder);
      }

      // Sort by creation date (newest first)
      enhancedOrders.sort((a, b) {
        final aDate = DateTime.parse(a['created_at']);
        final bDate = DateTime.parse(b['created_at']);
        return bDate.compareTo(aDate);
      });

      print('📦 ORDER TRACKING - Found ${enhancedOrders.length} orders for customer');
      return enhancedOrders;

    } catch (e) {
      print('❌ ORDER TRACKING - Error loading customer order history: $e');
      return [];
    }
  }

  /// Get detailed information for a specific order
  /// 
  /// Provides comprehensive order details including items, status history,
  /// and tracking information
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      // Feature flag check
      if (!FeatureFlags.isEnabled('order_history')) {
        return null;
      }

      FeatureFlags.logFeatureUsage('order_history', 'get_order_details');

      print('📦 ORDER TRACKING - Loading details for order: $orderId');

      // Get order with related data using existing database structure
      final orderResponse = await _supabase
          .from('orders')
          .select('''
            *,
            customers(full_name, phone_number, address),
            order_items(
              *,
              meat_products(
                name,
                price,
                meat_product_images(image_url)
              )
            )
          ''')
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        print('📦 ORDER TRACKING - Order not found: $orderId');
        return null;
      }

      // Enhance with tracking information
      final enhancedOrder = await _enhanceOrderWithTrackingInfo(orderResponse);
      
      print('📦 ORDER TRACKING - Order details loaded successfully');
      return enhancedOrder;

    } catch (e) {
      print('❌ ORDER TRACKING - Error loading order details: $e');
      return null;
    }
  }

  /// Get order status history and tracking timeline
  /// 
  /// Creates a timeline of order status changes for tracking display
  Future<List<Map<String, dynamic>>> getOrderStatusHistory(String orderId) async {
    try {
      // Feature flag check
      if (!FeatureFlags.isEnabled('order_history')) {
        return [];
      }

      FeatureFlags.logFeatureUsage('order_history', 'get_status_history');

      print('📦 ORDER TRACKING - Loading status history for order: $orderId');

      // Get order basic info
      final order = await _supabase
          .from('orders')
          .select('order_status, created_at, estimated_delivery')
          .eq('id', orderId)
          .maybeSingle();

      if (order == null) {
        return [];
      }

      // Create status timeline based on existing order data
      // Note: This uses existing fields and creates a logical timeline
      final statusHistory = <Map<String, dynamic>>[];

      // Order placed (always first)
      statusHistory.add({
        'status': 'placed',
        'title': 'Order Placed',
        'description': 'Your order has been received and is being processed',
        'timestamp': order['created_at'],
        'is_completed': true,
        'icon': 'check_circle',
        'color': 'green',
      });

      // Current status
      final currentStatus = order['order_status'] as String? ?? 'pending';
      
      // Add status based on current order status
      switch (currentStatus.toLowerCase()) {
        case 'confirmed':
        case 'processing':
          statusHistory.add({
            'status': 'confirmed',
            'title': 'Order Confirmed',
            'description': 'Your order has been confirmed and is being prepared',
            'timestamp': _estimateStatusTime(order['created_at'], 1),
            'is_completed': true,
            'icon': 'assignment_turned_in',
            'color': 'blue',
          });
          break;
        
        case 'shipped':
        case 'out_for_delivery':
          statusHistory.addAll([
            {
              'status': 'confirmed',
              'title': 'Order Confirmed',
              'description': 'Your order has been confirmed and prepared',
              'timestamp': _estimateStatusTime(order['created_at'], 1),
              'is_completed': true,
              'icon': 'assignment_turned_in',
              'color': 'blue',
            },
            {
              'status': 'shipped',
              'title': 'Order Shipped',
              'description': 'Your order is on the way to your location',
              'timestamp': _estimateStatusTime(order['created_at'], 2),
              'is_completed': true,
              'icon': 'local_shipping',
              'color': 'orange',
            },
          ]);
          break;
        
        case 'delivered':
          statusHistory.addAll([
            {
              'status': 'confirmed',
              'title': 'Order Confirmed',
              'description': 'Your order has been confirmed and prepared',
              'timestamp': _estimateStatusTime(order['created_at'], 1),
              'is_completed': true,
              'icon': 'assignment_turned_in',
              'color': 'blue',
            },
            {
              'status': 'shipped',
              'title': 'Order Shipped',
              'description': 'Your order was dispatched for delivery',
              'timestamp': _estimateStatusTime(order['created_at'], 2),
              'is_completed': true,
              'icon': 'local_shipping',
              'color': 'orange',
            },
            {
              'status': 'delivered',
              'title': 'Order Delivered',
              'description': 'Your order has been successfully delivered',
              'timestamp': _estimateStatusTime(order['created_at'], 3),
              'is_completed': true,
              'icon': 'done_all',
              'color': 'green',
            },
          ]);
          break;
        
        case 'cancelled':
          statusHistory.add({
            'status': 'cancelled',
            'title': 'Order Cancelled',
            'description': 'Your order has been cancelled',
            'timestamp': _estimateStatusTime(order['created_at'], 1),
            'is_completed': true,
            'icon': 'cancel',
            'color': 'red',
          });
          break;
        
        default:
          // Pending status
          statusHistory.add({
            'status': 'pending',
            'title': 'Processing Order',
            'description': 'Your order is being processed',
            'timestamp': null,
            'is_completed': false,
            'icon': 'hourglass_empty',
            'color': 'grey',
          });
      }

      print('📦 ORDER TRACKING - Status history created with ${statusHistory.length} entries');
      return statusHistory;

    } catch (e) {
      print('❌ ORDER TRACKING - Error loading status history: $e');
      return [];
    }
  }

  /// Get order summary statistics for customer
  /// 
  /// Provides useful statistics about customer's order history
  Future<Map<String, dynamic>> getOrderSummaryStats(String customerId) async {
    try {
      // Feature flag check
      if (!FeatureFlags.isEnabled('order_history')) {
        return _getEmptyStats();
      }

      FeatureFlags.logFeatureUsage('order_history', 'get_summary_stats');

      final orders = await getCustomerOrderHistory(customerId);
      
      if (orders.isEmpty) {
        return _getEmptyStats();
      }

      // Calculate statistics
      final totalOrders = orders.length;
      final totalSpent = orders.fold<double>(0.0, (sum, order) {
        return sum + ((order['total_amount'] as num?)?.toDouble() ?? 0.0);
      });

      final deliveredOrders = orders.where((order) => 
        (order['order_status'] as String?)?.toLowerCase() == 'delivered'
      ).length;

      final pendingOrders = orders.where((order) => 
        (order['order_status'] as String?)?.toLowerCase() == 'pending'
      ).length;

      final averageOrderValue = totalOrders > 0 ? totalSpent / totalOrders : 0.0;

      // Find most recent order
      final mostRecentOrder = orders.isNotEmpty ? orders.first : null;

      return {
        'total_orders': totalOrders,
        'total_spent': totalSpent,
        'delivered_orders': deliveredOrders,
        'pending_orders': pendingOrders,
        'average_order_value': averageOrderValue,
        'most_recent_order': mostRecentOrder,
        'success': true,
      };

    } catch (e) {
      print('❌ ORDER TRACKING - Error calculating summary stats: $e');
      return _getEmptyStats();
    }
  }

  /// Enhance order with additional tracking information
  /// 
  /// Private method to add tracking-specific data to existing order data
  Future<Map<String, dynamic>> _enhanceOrderWithTrackingInfo(Map<String, dynamic> order) async {
    try {
      // Create enhanced order with additional tracking fields
      final enhanced = Map<String, dynamic>.from(order);

      // Add tracking-specific fields
      enhanced['tracking_status'] = _getTrackingStatus(order['order_status']);
      enhanced['status_color'] = _getStatusColor(order['order_status']);
      enhanced['status_icon'] = _getStatusIcon(order['order_status']);
      enhanced['can_track'] = _canTrackOrder(order['order_status']);
      enhanced['estimated_delivery_formatted'] = _formatEstimatedDelivery(order['estimated_delivery']);
      
      // Calculate order item count
      final orderItems = order['order_items'] as List? ?? [];
      enhanced['total_items'] = orderItems.fold<int>(0, (sum, item) {
        return sum + ((item['quantity'] as int?) ?? 0);
      });

      // Add order age
      final createdAt = DateTime.parse(order['created_at']);
      enhanced['order_age_days'] = DateTime.now().difference(createdAt).inDays;

      return enhanced;

    } catch (e) {
      print('❌ ORDER TRACKING - Error enhancing order: $e');
      return order;
    }
  }

  /// Get user-friendly tracking status
  String _getTrackingStatus(String? orderStatus) {
    switch (orderStatus?.toLowerCase()) {
      case 'pending': return 'Order Received';
      case 'confirmed': return 'Order Confirmed';
      case 'processing': return 'Being Prepared';
      case 'shipped': return 'On the Way';
      case 'out_for_delivery': return 'Out for Delivery';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return 'Processing';
    }
  }

  /// Get status color for UI display
  String _getStatusColor(String? orderStatus) {
    switch (orderStatus?.toLowerCase()) {
      case 'delivered': return 'green';
      case 'shipped':
      case 'out_for_delivery': return 'orange';
      case 'cancelled': return 'red';
      case 'confirmed':
      case 'processing': return 'blue';
      default: return 'grey';
    }
  }

  /// Get status icon for UI display
  String _getStatusIcon(String? orderStatus) {
    switch (orderStatus?.toLowerCase()) {
      case 'delivered': return 'done_all';
      case 'shipped':
      case 'out_for_delivery': return 'local_shipping';
      case 'cancelled': return 'cancel';
      case 'confirmed':
      case 'processing': return 'assignment_turned_in';
      default: return 'hourglass_empty';
    }
  }

  /// Check if order can be tracked
  bool _canTrackOrder(String? orderStatus) {
    const trackableStatuses = ['confirmed', 'processing', 'shipped', 'out_for_delivery'];
    return trackableStatuses.contains(orderStatus?.toLowerCase());
  }

  /// Format estimated delivery date
  String? _formatEstimatedDelivery(String? estimatedDelivery) {
    if (estimatedDelivery == null) return null;
    
    try {
      final date = DateTime.parse(estimatedDelivery);
      final now = DateTime.now();
      final difference = date.difference(now).inDays;
      
      if (difference == 0) return 'Today';
      if (difference == 1) return 'Tomorrow';
      if (difference > 1) return 'In $difference days';
      if (difference < 0) return 'Overdue';
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Estimate status timestamp based on order creation time
  String _estimateStatusTime(String createdAt, int hoursOffset) {
    final created = DateTime.parse(createdAt);
    final estimated = created.add(Duration(hours: hoursOffset));
    return estimated.toIso8601String();
  }

  /// Get empty statistics object
  Map<String, dynamic> _getEmptyStats() {
    return {
      'total_orders': 0,
      'total_spent': 0.0,
      'delivered_orders': 0,
      'pending_orders': 0,
      'average_order_value': 0.0,
      'most_recent_order': null,
      'success': false,
    };
  }
}
