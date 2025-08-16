import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for business intelligence and advanced analytics
/// Zero-risk implementation providing insights for business decision making
class BusinessIntelligenceService {
  static final BusinessIntelligenceService _instance = BusinessIntelligenceService._internal();
  factory BusinessIntelligenceService() => _instance;
  BusinessIntelligenceService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Feature flag for business intelligence
  static const bool _enableBusinessIntelligence = true;

  /// Check if business intelligence is available
  bool get isAvailable => _enableBusinessIntelligence;

  // =====================================================
  // BUSINESS METRICS & KPIs
  // =====================================================

  /// Get comprehensive business dashboard metrics
  Future<Map<String, dynamic>> getBusinessDashboard({
    Duration timeWindow = const Duration(days: 30),
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 BUSINESS_INTELLIGENCE - Generating business dashboard...');
      }

      final startTime = DateTime.now().subtract(timeWindow);

      // Get all key metrics in parallel
      final results = await Future.wait([
        _getRevenueMetrics(startTime),
        _getUserGrowthMetrics(startTime),
        _getSellerPerformanceMetrics(startTime),
        _getProductCatalogMetrics(startTime),
        _getOperationalMetrics(startTime),
      ]);

      final dashboard = {
        'revenue': results[0],
        'user_growth': results[1],
        'seller_performance': results[2],
        'product_catalog': results[3],
        'operations': results[4],
        'time_window_days': timeWindow.inDays,
        'generated_at': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('✅ BUSINESS_INTELLIGENCE - Business dashboard generated');
      }

      return {
        'success': true,
        'data': dashboard,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ BUSINESS_INTELLIGENCE - Error generating dashboard: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }

  /// Get revenue and financial metrics
  Future<Map<String, dynamic>> _getRevenueMetrics(DateTime startTime) async {
    try {
      // Get order data for revenue calculation
      final orders = await _supabase
          .from('orders')
          .select('id, total_amount, status, created_at, delivery_fee')
          .gte('created_at', startTime.toIso8601String());

      final completedOrders = orders.where((order) => order['status'] == 'completed').toList();
      
      double totalRevenue = 0.0;
      double totalDeliveryFees = 0.0;
      
      for (final order in completedOrders) {
        totalRevenue += (order['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalDeliveryFees += (order['delivery_fee'] as num?)?.toDouble() ?? 0.0;
      }

      final averageOrderValue = completedOrders.isNotEmpty 
          ? totalRevenue / completedOrders.length 
          : 0.0;

      return {
        'total_revenue': totalRevenue.toStringAsFixed(2),
        'total_orders': orders.length,
        'completed_orders': completedOrders.length,
        'average_order_value': averageOrderValue.toStringAsFixed(2),
        'total_delivery_fees': totalDeliveryFees.toStringAsFixed(2),
        'completion_rate': orders.isNotEmpty 
            ? ((completedOrders.length / orders.length) * 100).toStringAsFixed(1)
            : '0.0',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ BUSINESS_INTELLIGENCE - Error getting revenue metrics: $e');
      }
      return {
        'total_revenue': '0.00',
        'total_orders': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get user growth and engagement metrics
  Future<Map<String, dynamic>> _getUserGrowthMetrics(DateTime startTime) async {
    try {
      // Get customer data
      final customers = await _supabase
          .from('customers')
          .select('id, created_at, phone_number')
          .gte('created_at', startTime.toIso8601String());

      // Get seller data
      final sellers = await _supabase
          .from('sellers')
          .select('id, created_at, approval_status')
          .gte('created_at', startTime.toIso8601String());

      final activeSellers = sellers.where((seller) => seller['approval_status'] == 'approved').length;

      // Calculate daily growth trends
      final dailyCustomerGrowth = <String, int>{};
      final dailySellerGrowth = <String, int>{};

      for (final customer in customers) {
        final date = DateTime.parse(customer['created_at'] as String);
        final dateKey = _formatDate(date);
        dailyCustomerGrowth[dateKey] = (dailyCustomerGrowth[dateKey] ?? 0) + 1;
      }

      for (final seller in sellers) {
        final date = DateTime.parse(seller['created_at'] as String);
        final dateKey = _formatDate(date);
        dailySellerGrowth[dateKey] = (dailySellerGrowth[dateKey] ?? 0) + 1;
      }

      return {
        'new_customers': customers.length,
        'new_sellers': sellers.length,
        'active_sellers': activeSellers,
        'seller_approval_rate': sellers.isNotEmpty 
            ? ((activeSellers / sellers.length) * 100).toStringAsFixed(1)
            : '0.0',
        'daily_customer_growth': dailyCustomerGrowth,
        'daily_seller_growth': dailySellerGrowth,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ BUSINESS_INTELLIGENCE - Error getting user growth metrics: $e');
      }
      return {
        'new_customers': 0,
        'new_sellers': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get seller performance metrics
  Future<Map<String, dynamic>> _getSellerPerformanceMetrics(DateTime startTime) async {
    try {
      // Get product data by seller
      final products = await _supabase
          .from('meat_products')
          .select('id, seller_id, approval_status, created_at, name')
          .gte('created_at', startTime.toIso8601String());

      // Group products by seller
      final productsBySeller = <String, List<dynamic>>{};
      for (final product in products) {
        final sellerId = product['seller_id'] as String;
        productsBySeller[sellerId] ??= [];
        productsBySeller[sellerId]!.add(product);
      }

      // Calculate seller metrics
      final sellerMetrics = <String, Map<String, dynamic>>{};
      for (final entry in productsBySeller.entries) {
        final sellerId = entry.key;
        final sellerProducts = entry.value;
        
        final approvedProducts = sellerProducts.where((p) => p['approval_status'] == 'approved').length;
        final totalProducts = sellerProducts.length;
        
        sellerMetrics[sellerId] = {
          'total_products': totalProducts,
          'approved_products': approvedProducts,
          'approval_rate': totalProducts > 0 
              ? ((approvedProducts / totalProducts) * 100).toStringAsFixed(1)
              : '0.0',
        };
      }

      // Find top performing sellers
      final topSellers = sellerMetrics.entries.toList()
        ..sort((a, b) => (b.value['approved_products'] as int).compareTo(a.value['approved_products'] as int));

      return {
        'total_active_sellers': productsBySeller.length,
        'total_products_submitted': products.length,
        'average_products_per_seller': productsBySeller.isNotEmpty 
            ? (products.length / productsBySeller.length).toStringAsFixed(1)
            : '0.0',
        'top_sellers': Map.fromEntries(topSellers.take(5)),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ BUSINESS_INTELLIGENCE - Error getting seller performance: $e');
      }
      return {
        'total_active_sellers': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get product catalog metrics
  Future<Map<String, dynamic>> _getProductCatalogMetrics(DateTime startTime) async {
    try {
      // Get product data
      final products = await _supabase
          .from('meat_products')
          .select('id, approval_status, created_at, category, price')
          .gte('created_at', startTime.toIso8601String());

      // Calculate status distribution
      final statusDistribution = <String, int>{};
      final categoryDistribution = <String, int>{};
      double totalValue = 0.0;

      for (final product in products) {
        final status = product['approval_status'] as String? ?? 'unknown';
        final category = product['category'] as String? ?? 'uncategorized';
        final price = (product['price'] as num?)?.toDouble() ?? 0.0;

        statusDistribution[status] = (statusDistribution[status] ?? 0) + 1;
        categoryDistribution[category] = (categoryDistribution[category] ?? 0) + 1;
        totalValue += price;
      }

      final averagePrice = products.isNotEmpty ? totalValue / products.length : 0.0;

      return {
        'total_products': products.length,
        'status_distribution': statusDistribution,
        'category_distribution': categoryDistribution,
        'average_price': averagePrice.toStringAsFixed(2),
        'total_catalog_value': totalValue.toStringAsFixed(2),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ BUSINESS_INTELLIGENCE - Error getting product catalog metrics: $e');
      }
      return {
        'total_products': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get operational metrics
  Future<Map<String, dynamic>> _getOperationalMetrics(DateTime startTime) async {
    try {
      // Get system health metrics from edge function logs
      final systemLogs = await _supabase
          .from('edge_function_logs')
          .select('endpoint, status, latency_ms, ts')
          .gte('ts', startTime.toIso8601String());

      final totalRequests = systemLogs.length;
      final errorRequests = systemLogs.where((log) => log['status'] >= 400).length;
      final systemUptime = totalRequests > 0 
          ? ((totalRequests - errorRequests) / totalRequests) * 100 
          : 100.0;

      // Calculate average response time
      final latencies = systemLogs
          .map((log) => log['latency_ms'] as int? ?? 0)
          .where((latency) => latency > 0)
          .toList();

      final averageResponseTime = latencies.isNotEmpty 
          ? latencies.reduce((a, b) => a + b) / latencies.length 
          : 0.0;

      // Get endpoint usage
      final endpointUsage = <String, int>{};
      for (final log in systemLogs) {
        final endpoint = log['endpoint'] as String;
        endpointUsage[endpoint] = (endpointUsage[endpoint] ?? 0) + 1;
      }

      return {
        'system_uptime': systemUptime.toStringAsFixed(2),
        'total_api_requests': totalRequests,
        'error_requests': errorRequests,
        'average_response_time': averageResponseTime.toStringAsFixed(0),
        'most_used_endpoints': endpointUsage,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ BUSINESS_INTELLIGENCE - Error getting operational metrics: $e');
      }
      return {
        'system_uptime': '100.00',
        'total_api_requests': 0,
        'error': e.toString(),
      };
    }
  }

  /// Format date for grouping
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // =====================================================
  // FEATURE USAGE ANALYTICS
  // =====================================================

  /// Get feature usage patterns and adoption rates
  Future<Map<String, dynamic>> getFeatureUsageAnalytics() async {
    try {
      if (kDebugMode) {
        print('🔍 BUSINESS_INTELLIGENCE - Analyzing feature usage...');
      }

      // Get feature flag data to understand feature adoption
      final featureFlags = await _supabase
          .from('feature_flags')
          .select('feature_name, enabled, target_user_percentage, updated_at');

      // Get feature flag change history
      final flagChanges = await _supabase
          .from('feature_flag_changes')
          .select('flag_name, old_value, new_value, created_at')
          .order('created_at', ascending: false)
          .limit(100);

      // Calculate feature adoption metrics
      final enabledFeatures = featureFlags.where((flag) => flag['enabled'] == true).length;
      final totalFeatures = featureFlags.length;
      
      final featureAdoptionRate = totalFeatures > 0 
          ? (enabledFeatures / totalFeatures) * 100 
          : 0.0;

      // Analyze feature toggle frequency
      final toggleFrequency = <String, int>{};
      for (final change in flagChanges) {
        final flagName = change['flag_name'] as String;
        toggleFrequency[flagName] = (toggleFrequency[flagName] ?? 0) + 1;
      }

      return {
        'success': true,
        'data': {
          'feature_overview': {
            'total_features': totalFeatures,
            'enabled_features': enabledFeatures,
            'adoption_rate': featureAdoptionRate.toStringAsFixed(1),
          },
          'feature_flags': featureFlags,
          'toggle_frequency': toggleFrequency,
          'recent_changes': flagChanges.take(10).toList(),
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ BUSINESS_INTELLIGENCE - Error analyzing feature usage: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }
}
