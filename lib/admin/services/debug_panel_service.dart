import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for Admin Debug Panel data operations
/// Implements zero-risk pattern with read-only operations and proper error handling
class DebugPanelService {
  static final DebugPanelService _instance = DebugPanelService._internal();
  factory DebugPanelService() => _instance;
  DebugPanelService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Feature flag for debug panel
  static const bool _enableDebugPanel = true; // Feature flag

  /// Check if debug panel is available
  bool get isAvailable => _enableDebugPanel;

  // =====================================================
  // TRAFFIC EXPLORER METHODS
  // =====================================================

  /// Get edge function logs with filtering and pagination
  Future<Map<String, dynamic>> getEdgeFunctionLogs({
    int page = 1,
    int limit = 50,
    String? endpoint,
    int? statusCode,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Fetching edge function logs...');
      }

      // Build query with filters
      var queryBuilder = _supabase.from('edge_function_logs').select('*');

      // Apply filters
      if (endpoint != null && endpoint.isNotEmpty) {
        queryBuilder = queryBuilder.eq('endpoint', endpoint);
      }

      if (statusCode != null) {
        queryBuilder = queryBuilder.eq('status', statusCode);
      }

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('ts', startDate.toIso8601String());
      }

      if (endDate != null) {
        queryBuilder = queryBuilder.lte('ts', endDate.toIso8601String());
      }

      // Apply search in request/response (simplified - skip for now)
      // Note: Complex search queries can be added later

      // Apply pagination and ordering
      final offset = (page - 1) * limit;
      final response = await queryBuilder
          .order('ts', ascending: false)
          .range(offset, offset + limit - 1);

      // Get total count for pagination (simplified approach)
      var countQueryBuilder = _supabase.from('edge_function_logs').select('id');

      // Apply same filters to count query
      if (endpoint != null && endpoint.isNotEmpty) {
        countQueryBuilder = countQueryBuilder.eq('endpoint', endpoint);
      }
      if (statusCode != null) {
        countQueryBuilder = countQueryBuilder.eq('status', statusCode);
      }
      if (startDate != null) {
        countQueryBuilder = countQueryBuilder.gte(
          'ts',
          startDate.toIso8601String(),
        );
      }
      if (endDate != null) {
        countQueryBuilder = countQueryBuilder.lte(
          'ts',
          endDate.toIso8601String(),
        );
      }

      final countResponse = await countQueryBuilder;
      final totalCount = countResponse.length;

      if (kDebugMode) {
        print(
          '✅ DEBUG_PANEL - Found ${response.length} logs (total: $totalCount)',
        );
      }

      return {
        'success': true,
        'data': response,
        'pagination': {
          'page': page,
          'limit': limit,
          'total': totalCount,
          'totalPages': (totalCount / limit).ceil(),
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching logs: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
        'pagination': {
          'page': page,
          'limit': limit,
          'total': 0,
          'totalPages': 0,
        },
      };
    }
  }

  /// Get endpoint statistics with error rates and volume metrics
  Future<Map<String, dynamic>> getEndpointStatistics({
    Duration timeWindow = const Duration(hours: 24),
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Calculating endpoint statistics...');
      }

      final startTime = DateTime.now().subtract(timeWindow);

      // Get all logs in time window
      final logs = await _supabase
          .from('edge_function_logs')
          .select('endpoint, status, latency_ms, api_call_count')
          .gte('ts', startTime.toIso8601String())
          .order('ts', ascending: false);

      // Calculate statistics per endpoint
      final Map<String, Map<String, dynamic>> stats = {};

      for (final log in logs) {
        final endpoint = log['endpoint'] as String;
        final status = log['status'] as int;
        final latency = log['latency_ms'] as int? ?? 0;
        final callCount = log['api_call_count'] as int? ?? 1;

        if (!stats.containsKey(endpoint)) {
          stats[endpoint] = {
            'total_calls': 0,
            'error_calls': 0,
            'total_latency': 0,
            'min_latency': latency,
            'max_latency': latency,
            'error_rate': 0.0,
            'avg_latency': 0.0,
            'has_alerts': false,
          };
        }

        final endpointStats = stats[endpoint]!;
        endpointStats['total_calls'] += callCount;
        endpointStats['total_latency'] += latency * callCount;

        if (status >= 400) {
          endpointStats['error_calls'] += callCount;
        }

        // Update latency bounds
        if (latency < endpointStats['min_latency']) {
          endpointStats['min_latency'] = latency;
        }
        if (latency > endpointStats['max_latency']) {
          endpointStats['max_latency'] = latency;
        }
      }

      // Calculate final metrics
      for (final endpoint in stats.keys) {
        final endpointStats = stats[endpoint]!;
        final totalCalls = endpointStats['total_calls'] as int;
        final errorCalls = endpointStats['error_calls'] as int;
        final totalLatency = endpointStats['total_latency'] as int;

        if (totalCalls > 0) {
          endpointStats['error_rate'] = (errorCalls / totalCalls) * 100;
          endpointStats['avg_latency'] = totalLatency / totalCalls;
          endpointStats['has_alerts'] = endpointStats['error_rate'] > 5.0;
        }
      }

      if (kDebugMode) {
        print('✅ DEBUG_PANEL - Calculated stats for ${stats.length} endpoints');
      }

      return {
        'success': true,
        'data': stats,
        'time_window_hours': timeWindow.inHours,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error calculating statistics: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }

  /// Get unique endpoints for filtering
  Future<List<String>> getAvailableEndpoints() async {
    try {
      final response = await _supabase
          .from('edge_function_logs')
          .select('endpoint')
          .order('endpoint');

      final endpoints = response
          .map((log) => log['endpoint'] as String)
          .toSet()
          .toList();

      return endpoints;
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching endpoints: $e');
      }
      return [];
    }
  }

  // =====================================================
  // ODOO SESSION MONITOR METHODS
  // =====================================================

  /// Get recent Odoo authentication attempts
  Future<Map<String, dynamic>> getOdooSessionLogs({int limit = 100}) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Fetching Odoo session logs...');
      }

      final logs = await _supabase
          .from('odoo_session_logs')
          .select('*')
          .order('attempt_timestamp', ascending: false)
          .limit(limit);

      // Calculate success rate
      final totalAttempts = logs.length;
      final successfulAttempts = logs
          .where((log) => log['success'] == true)
          .length;
      final successRate = totalAttempts > 0
          ? (successfulAttempts / totalAttempts) * 100
          : 0.0;

      // Group failures by reason
      final failureReasons = <String, int>{};
      for (final log in logs) {
        if (log['success'] == false && log['failure_reason'] != null) {
          final reason = log['failure_reason'] as String;
          failureReasons[reason] = (failureReasons[reason] ?? 0) + 1;
        }
      }

      // Calculate cookie presence rate
      final cookiePresent = logs
          .where((log) => log['set_cookie_seen'] == true)
          .length;
      final cookieRate = totalAttempts > 0
          ? (cookiePresent / totalAttempts) * 100
          : 0.0;

      if (kDebugMode) {
        print(
          '✅ DEBUG_PANEL - Found $totalAttempts session attempts (${successRate.toStringAsFixed(1)}% success)',
        );
      }

      return {
        'success': true,
        'data': logs,
        'statistics': {
          'total_attempts': totalAttempts,
          'successful_attempts': successfulAttempts,
          'success_rate': successRate,
          'cookie_presence_rate': cookieRate,
          'failure_reasons': failureReasons,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching session logs: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
        'statistics': {},
      };
    }
  }

  /// Get current feature flag states
  Future<Map<String, dynamic>> getFeatureFlagStates() async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Fetching feature flag states...');
      }

      // Get from feature_flags table if it exists, otherwise return defaults
      try {
        final flags = await _supabase
            .from('feature_flags')
            .select('*')
            .order('flag_name');

        final flagStates = <String, bool>{};
        for (final flag in flags) {
          flagStates[flag['flag_name']] = flag['is_enabled'] ?? false;
        }

        return {'success': true, 'data': flagStates};
      } catch (e) {
        // If feature_flags table doesn't exist, return hardcoded states
        return {
          'success': true,
          'data': {
            'FORCE_V2_WEBHOOKS': true,
            'ENABLE_PRODUCT_DUP_CHECK': false,
            'ENABLE_AUTO_ACTIVATE_ON_APPROVAL': true,
            'AUTO_SYNC_STATUS_ON_OPEN': true,
          },
          'note': 'Using hardcoded values - feature_flags table not available',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching feature flags: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }

  /// Get user agent breakdown for debugging
  Future<Map<String, dynamic>> getUserAgentBreakdown({
    Duration timeWindow = const Duration(hours: 24),
  }) async {
    try {
      final startTime = DateTime.now().subtract(timeWindow);

      final logs = await _supabase
          .from('edge_function_logs')
          .select('user_agent, api_call_count')
          .gte('ts', startTime.toIso8601String());

      final userAgentStats = <String, int>{};
      for (final log in logs) {
        final userAgent = log['user_agent'] as String? ?? 'Unknown';
        final callCount = log['api_call_count'] as int? ?? 1;

        // Categorize user agents
        String category;
        if (userAgent.contains('GoatGoat-Mobile')) {
          category = 'Mobile App';
        } else if (userAgent.contains('GoatGoat-Admin')) {
          category = 'Admin Panel';
        } else if (userAgent.contains('GoatGoat-Webhook')) {
          category = 'Webhook';
        } else {
          category = 'Other';
        }

        userAgentStats[category] = (userAgentStats[category] ?? 0) + callCount;
      }

      return {
        'success': true,
        'data': userAgentStats,
        'time_window_hours': timeWindow.inHours,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error getting user agent breakdown: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }

  // =====================================================
  // PRODUCT/WEBHOOK STATUS METHODS
  // =====================================================

  /// Get recent product approval events
  Future<Map<String, dynamic>> getProductApprovalEvents({
    int limit = 50,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Fetching product approval events...');
      }

      final events = await _supabase
          .from('product_webhook_events')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      // Get product status counts from meat_products table
      final productCounts = await _supabase
          .from('meat_products')
          .select('approval_status')
          .eq('approval_status', 'pending');

      final pendingCount = productCounts.length;

      final approvedCounts = await _supabase
          .from('meat_products')
          .select('approval_status')
          .eq('approval_status', 'approved');

      final approvedCount = approvedCounts.length;

      final rejectedCounts = await _supabase
          .from('meat_products')
          .select('approval_status')
          .eq('approval_status', 'rejected');

      final rejectedCount = rejectedCounts.length;

      if (kDebugMode) {
        print(
          '✅ DEBUG_PANEL - Found ${events.length} events, Products: $pendingCount pending, $approvedCount approved, $rejectedCount rejected',
        );
      }

      return {
        'success': true,
        'data': events,
        'product_counts': {
          'pending': pendingCount,
          'approved': approvedCount,
          'rejected': rejectedCount,
          'total': pendingCount + approvedCount + rejectedCount,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching product events: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
        'product_counts': {
          'pending': 0,
          'approved': 0,
          'rejected': 0,
          'total': 0,
        },
      };
    }
  }

  /// Get duplicate prevention events
  Future<Map<String, dynamic>> getDuplicatePreventionEvents({
    int limit = 25,
  }) async {
    try {
      final events = await _supabase
          .from('product_webhook_events')
          .select('*')
          .eq('duplicate_prevented', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return {'success': true, 'data': events};
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching duplicate prevention events: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Get dry-run events with captured JSON-RPC bodies
  Future<Map<String, dynamic>> getDryRunEvents({int limit = 25}) async {
    try {
      final events = await _supabase
          .from('product_webhook_events')
          .select('*')
          .eq('event_type', 'dry_run')
          .order('created_at', ascending: false)
          .limit(limit);

      return {'success': true, 'data': events};
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching dry-run events: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }

  // =====================================================
  // UTILITY METHODS
  // =====================================================

  /// Get system health overview
  Future<Map<String, dynamic>> getSystemHealthOverview() async {
    try {
      final now = DateTime.now();
      final lastHour = now.subtract(const Duration(hours: 1));

      // Get recent activity counts
      final recentLogs = await _supabase
          .from('edge_function_logs')
          .select('status')
          .gte('ts', lastHour.toIso8601String());

      final recentErrors = await _supabase
          .from('edge_function_logs')
          .select('status')
          .gte('ts', lastHour.toIso8601String())
          .gte('status', 400);

      final totalRecent = recentLogs.length;
      final errorRecent = recentErrors.length;
      final currentErrorRate = totalRecent > 0
          ? (errorRecent / totalRecent) * 100
          : 0.0;

      return {
        'success': true,
        'data': {
          'last_hour_requests': totalRecent,
          'last_hour_errors': errorRecent,
          'current_error_rate': currentErrorRate,
          'system_status': currentErrorRate > 5.0 ? 'degraded' : 'healthy',
          'last_updated': now.toIso8601String(),
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error getting system health: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }
}
