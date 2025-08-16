import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for mobile app analytics and performance metrics
/// Zero-risk implementation focusing on user behavior and app performance
class MobileAnalyticsService {
  static final MobileAnalyticsService _instance = MobileAnalyticsService._internal();
  factory MobileAnalyticsService() => _instance;
  MobileAnalyticsService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Feature flag for mobile analytics
  static const bool _enableMobileAnalytics = true;

  /// Check if mobile analytics is available
  bool get isAvailable => _enableMobileAnalytics;

  // =====================================================
  // MOBILE APP PERFORMANCE METRICS
  // =====================================================

  /// Get mobile app performance metrics from edge function logs
  Future<Map<String, dynamic>> getMobileAppMetrics({
    Duration timeWindow = const Duration(hours: 24),
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 MOBILE_ANALYTICS - Analyzing mobile app metrics...');
      }

      final startTime = DateTime.now().subtract(timeWindow);

      // Get mobile app traffic (filter by user agent)
      final mobileTraffic = await _supabase
          .from('edge_function_logs')
          .select('endpoint, status, latency_ms, user_agent, ts, api_call_count')
          .gte('ts', startTime.toIso8601String())
          .like('user_agent', '%GoatGoat-Mobile%')
          .order('ts', ascending: false);

      if (mobileTraffic.isEmpty) {
        return {
          'success': true,
          'data': {
            'total_requests': 0,
            'message': 'No mobile app traffic found in the specified time window',
          },
        };
      }

      // Calculate basic metrics
      final totalRequests = mobileTraffic.length;
      final successfulRequests = mobileTraffic.where((req) => req['status'] < 400).length;
      final errorRequests = mobileTraffic.where((req) => req['status'] >= 400).length;
      final successRate = (successfulRequests / totalRequests) * 100;

      // Calculate latency metrics
      final latencies = mobileTraffic
          .map((req) => req['latency_ms'] as int? ?? 0)
          .where((latency) => latency > 0)
          .toList();

      double avgLatency = 0.0;
      double p95Latency = 0.0;
      double p99Latency = 0.0;

      if (latencies.isNotEmpty) {
        avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
        latencies.sort();
        p95Latency = _calculatePercentile(latencies, 0.95);
        p99Latency = _calculatePercentile(latencies, 0.99);
      }

      // Analyze endpoint usage
      final endpointUsage = <String, int>{};
      for (final req in mobileTraffic) {
        final endpoint = req['endpoint'] as String;
        endpointUsage[endpoint] = (endpointUsage[endpoint] ?? 0) + 1;
      }

      // Sort endpoints by usage
      final sortedEndpoints = endpointUsage.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Analyze hourly distribution
      final hourlyDistribution = <int, int>{};
      for (final req in mobileTraffic) {
        final timestamp = DateTime.parse(req['ts'] as String);
        final hour = timestamp.hour;
        hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
      }

      if (kDebugMode) {
        print('✅ MOBILE_ANALYTICS - Analyzed $totalRequests mobile requests');
      }

      return {
        'success': true,
        'data': {
          'overview': {
            'total_requests': totalRequests,
            'successful_requests': successfulRequests,
            'error_requests': errorRequests,
            'success_rate': successRate,
            'time_window_hours': timeWindow.inHours,
          },
          'performance': {
            'avg_latency_ms': avgLatency.toStringAsFixed(0),
            'p95_latency_ms': p95Latency.toStringAsFixed(0),
            'p99_latency_ms': p99Latency.toStringAsFixed(0),
            'total_latency_samples': latencies.length,
          },
          'endpoint_usage': Map.fromEntries(sortedEndpoints.take(10)),
          'hourly_distribution': hourlyDistribution,
          'peak_hour': hourlyDistribution.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ MOBILE_ANALYTICS - Error analyzing mobile metrics: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }

  /// Get user behavior analytics from various data sources
  Future<Map<String, dynamic>> getUserBehaviorAnalytics({
    Duration timeWindow = const Duration(days: 7),
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 MOBILE_ANALYTICS - Analyzing user behavior...');
      }

      final startTime = DateTime.now().subtract(timeWindow);

      // Get customer activity data
      final customerActivity = await _supabase
          .from('customers')
          .select('id, created_at, updated_at, phone_number')
          .gte('created_at', startTime.toIso8601String());

      // Get seller activity data
      final sellerActivity = await _supabase
          .from('sellers')
          .select('id, created_at, updated_at, phone_number')
          .gte('created_at', startTime.toIso8601String());

      // Get order activity
      final orderActivity = await _supabase
          .from('orders')
          .select('id, created_at, status, customer_id')
          .gte('created_at', startTime.toIso8601String());

      // Calculate user metrics
      final newCustomers = customerActivity.length;
      final newSellers = sellerActivity.length;
      final totalOrders = orderActivity.length;

      // Analyze order status distribution
      final orderStatusDistribution = <String, int>{};
      for (final order in orderActivity) {
        final status = order['status'] as String? ?? 'unknown';
        orderStatusDistribution[status] = (orderStatusDistribution[status] ?? 0) + 1;
      }

      // Calculate daily registration trends
      final dailyCustomerRegistrations = <String, int>{};
      final dailySellerRegistrations = <String, int>{};

      for (final customer in customerActivity) {
        final date = DateTime.parse(customer['created_at'] as String);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailyCustomerRegistrations[dateKey] = (dailyCustomerRegistrations[dateKey] ?? 0) + 1;
      }

      for (final seller in sellerActivity) {
        final date = DateTime.parse(seller['created_at'] as String);
        final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dailySellerRegistrations[dateKey] = (dailySellerRegistrations[dateKey] ?? 0) + 1;
      }

      if (kDebugMode) {
        print('✅ MOBILE_ANALYTICS - Analyzed user behavior: $newCustomers customers, $newSellers sellers, $totalOrders orders');
      }

      return {
        'success': true,
        'data': {
          'user_growth': {
            'new_customers': newCustomers,
            'new_sellers': newSellers,
            'total_orders': totalOrders,
            'time_window_days': timeWindow.inDays,
          },
          'order_analytics': {
            'status_distribution': orderStatusDistribution,
            'completion_rate': orderStatusDistribution['completed'] != null
                ? ((orderStatusDistribution['completed']! / totalOrders) * 100).toStringAsFixed(1)
                : '0.0',
          },
          'registration_trends': {
            'daily_customer_registrations': dailyCustomerRegistrations,
            'daily_seller_registrations': dailySellerRegistrations,
          },
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ MOBILE_ANALYTICS - Error analyzing user behavior: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }

  /// Get product adoption analytics
  Future<Map<String, dynamic>> getProductAdoptionAnalytics({
    Duration timeWindow = const Duration(days: 30),
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 MOBILE_ANALYTICS - Analyzing product adoption...');
      }

      final startTime = DateTime.now().subtract(timeWindow);

      // Get product data
      final products = await _supabase
          .from('meat_products')
          .select('id, name, approval_status, created_at, seller_id')
          .gte('created_at', startTime.toIso8601String());

      // Get order items for product popularity
      final orderItems = await _supabase
          .from('order_items')
          .select('product_id, quantity, created_at')
          .gte('created_at', startTime.toIso8601String());

      // Calculate product metrics
      final totalProducts = products.length;
      final approvedProducts = products.where((p) => p['approval_status'] == 'approved').length;
      final pendingProducts = products.where((p) => p['approval_status'] == 'pending').length;
      final rejectedProducts = products.where((p) => p['approval_status'] == 'rejected').length;

      // Calculate product popularity
      final productPopularity = <String, int>{};
      for (final item in orderItems) {
        final productId = item['product_id'] as String;
        final quantity = item['quantity'] as int? ?? 1;
        productPopularity[productId] = (productPopularity[productId] ?? 0) + quantity;
      }

      // Get top products
      final topProducts = productPopularity.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return {
        'success': true,
        'data': {
          'product_overview': {
            'total_products': totalProducts,
            'approved_products': approvedProducts,
            'pending_products': pendingProducts,
            'rejected_products': rejectedProducts,
            'approval_rate': totalProducts > 0 
                ? ((approvedProducts / totalProducts) * 100).toStringAsFixed(1)
                : '0.0',
          },
          'product_popularity': Map.fromEntries(topProducts.take(10)),
          'total_orders_analyzed': orderItems.length,
          'time_window_days': timeWindow.inDays,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ MOBILE_ANALYTICS - Error analyzing product adoption: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }

  /// Calculate percentile value
  double _calculatePercentile(List<int> values, double percentile) {
    if (values.isEmpty) return 0.0;
    
    final sorted = List<int>.from(values)..sort();
    final index = (sorted.length * percentile).floor();
    return sorted[index.clamp(0, sorted.length - 1)].toDouble();
  }
}
