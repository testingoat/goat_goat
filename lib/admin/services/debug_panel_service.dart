import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_logs_service.dart';
import 'feature_flag_service.dart';
import 'anomaly_detection_service.dart';
import 'admin_auth_service.dart';

/// Service for Admin Debug Panel data operations
/// Implements zero-risk pattern with read-only operations and proper error handling
class DebugPanelService {
  static final DebugPanelService _instance = DebugPanelService._internal();
  factory DebugPanelService() => _instance;
  DebugPanelService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final SupabaseLogsService _supabaseLogsService = SupabaseLogsService();

  // Feature flag for debug panel
  static const bool _enableDebugPanel = true; // Feature flag

  /// Check if debug panel is available
  bool get isAvailable => _enableDebugPanel;

  /// Check authentication status and permissions
  Future<Map<String, dynamic>> checkAuthenticationStatus() async {
    try {
      // Check admin authentication (custom system)
      final adminAuth = AdminAuthService();
      final isAdminAuthenticated = await adminAuth.isAuthenticated();
      final currentAdmin = adminAuth.currentAdmin;

      // Also check Supabase auth for comparison
      final user = _supabase.auth.currentUser;
      final session = _supabase.auth.currentSession;

      if (kDebugMode) {
        print('🔍 DEBUG_PANEL_SERVICE - Checking authentication...');
        print('  - Admin authenticated: $isAdminAuthenticated');
        print('  - Admin ID: ${adminAuth.currentAdminId ?? 'null'}');
        print('  - Admin email: ${currentAdmin?['email'] ?? 'null'}');
        print('  - Supabase User ID: ${user?.id ?? 'null'}');
        print('  - Supabase User email: ${user?.email ?? 'null'}');
        print('  - Supabase Session valid: ${session != null}');
      }

      // Test a simple query to check permissions (with RLS disabled, this should work)
      Map<String, dynamic> testQueryResult = {};
      bool canQueryLogs = false;

      try {
        final testQuery = await _supabase
            .from('edge_function_logs')
            .select('count(*)')
            .limit(1);
        testQueryResult = {'query_result': testQuery};
        canQueryLogs = true;
      } catch (queryError) {
        testQueryResult = {'query_error': queryError.toString()};
        canQueryLogs = false;
      }

      return {
        'success': true,
        'admin_authenticated': isAdminAuthenticated,
        'admin_user_id': adminAuth.currentAdminId,
        'admin_email': currentAdmin?['email'],
        'admin_role': currentAdmin?['role'],
        'supabase_authenticated': user != null,
        'supabase_user_id': user?.id,
        'supabase_user_email': user?.email,
        'supabase_session_valid': session != null,
        'supabase_session_expires_at': session?.expiresAt,
        'can_query_logs': canQueryLogs,
        'test_query_result': testQueryResult,
        'rls_disabled': true, // We disabled RLS for testing
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL_SERVICE - Auth check failed: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'admin_authenticated': false,
        'supabase_authenticated': false,
        'can_query_logs': false,
      };
    }
  }

  // =====================================================
  // TRAFFIC EXPLORER METHODS
  // =====================================================

  /// Test database connectivity and basic functionality
  Future<Map<String, dynamic>> testDatabaseConnection() async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL_SERVICE - Testing database connection...');
        print('  - Supabase client initialized: ${_supabase.toString()}');
        print(
          '  - Supabase auth user: ${_supabase.auth.currentUser?.id ?? 'null'}',
        );
        print('  - Supabase session: ${_supabase.auth.currentSession != null}');
        print('  - Admin auth: ${AdminAuthService().currentAdminId ?? 'null'}');
        print('  - RLS disabled: true (for testing)');
      }

      // Test basic query
      final testResponse = await _supabase
          .from('edge_function_logs')
          .select('id, endpoint, ts')
          .limit(1);

      if (kDebugMode) {
        print('✅ DEBUG_PANEL_SERVICE - Database test successful:');
        print('  - Response: $testResponse');
        print('  - Response type: ${testResponse.runtimeType}');
        print('  - Response length: ${testResponse.length}');
      }

      return {
        'success': true,
        'message': 'Database connection working',
        'sample_data': testResponse,
        'supabase_auth_user_id': _supabase.auth.currentUser?.id,
        'supabase_auth_session_valid': _supabase.auth.currentSession != null,
        'admin_auth_user_id': AdminAuthService().currentAdminId,
        'admin_authenticated': await AdminAuthService().isAuthenticated(),
        'rls_disabled': true,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL_SERVICE - Database test failed: $e');
        print('  - Error type: ${e.runtimeType}');
        print('  - Auth user: ${_supabase.auth.currentUser?.id ?? 'null'}');
      }
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Database connection failed',
        'supabase_auth_user_id': _supabase.auth.currentUser?.id,
        'supabase_auth_session_valid': _supabase.auth.currentSession != null,
        'admin_auth_user_id': AdminAuthService().currentAdminId,
        'rls_disabled': true,
      };
    }
  }

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
        print('🔍 DEBUG_PANEL_SERVICE - Fetching edge function logs...');
        print(
          '  - Filters: endpoint=$endpoint, status=$statusCode, start=$startDate, end=$endDate',
        );
        print('  - Pagination: page=$page, limit=$limit');
        print(
          '  - Supabase auth user: ${_supabase.auth.currentUser?.id ?? 'null'}',
        );
        print(
          '  - Supabase session valid: ${_supabase.auth.currentSession != null}',
        );
        print('  - Admin auth: ${AdminAuthService().currentAdminId ?? 'null'}');
        print('  - RLS disabled: true (for testing)');
      }

      // Build query with filters
      var queryBuilder = _supabase.from('edge_function_logs').select('*');

      // Apply filters
      if (endpoint != null && endpoint.isNotEmpty) {
        queryBuilder = queryBuilder.eq('endpoint', endpoint);
        if (kDebugMode) print('  - Applied endpoint filter: $endpoint');
      }

      if (statusCode != null) {
        queryBuilder = queryBuilder.eq('status', statusCode);
        if (kDebugMode) print('  - Applied status filter: $statusCode');
      }

      if (startDate != null) {
        queryBuilder = queryBuilder.gte('ts', startDate.toIso8601String());
        if (kDebugMode) {
          print(
            '  - Applied start date filter: ${startDate.toIso8601String()}',
          );
        }
      }

      if (endDate != null) {
        queryBuilder = queryBuilder.lte('ts', endDate.toIso8601String());
        if (kDebugMode) {
          print('  - Applied end date filter: ${endDate.toIso8601String()}');
        }
      }

      // Apply search in request/response (simplified - skip for now)
      // Note: Complex search queries can be added later

      // Apply pagination and ordering
      final offset = (page - 1) * limit;
      if (kDebugMode) {
        print(
          '  - Applying pagination: offset=$offset, range=$offset-${offset + limit - 1}',
        );
      }

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
        print('✅ DEBUG_PANEL_SERVICE - Query executed successfully:');
        print('  - Response length: ${response.length}');
        print('  - Total count: $totalCount');
        print('  - Response type: ${response.runtimeType}');
        if (response.isNotEmpty) {
          print(
            '  - First item keys: ${(response.first as Map).keys.toList()}',
          );
          print('  - Sample data: ${response.first}');
        }
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

      // Use the dedicated feature flag service
      final flagService = FeatureFlagService();
      final result = await flagService.getAllFeatureFlags();

      if (result['success']) {
        // Convert to the format expected by the debug panel
        final flagData = result['data'] as Map<String, dynamic>;
        final flagStates = <String, bool>{};

        for (final entry in flagData.entries) {
          final flagInfo = entry.value as Map<String, dynamic>;
          flagStates[entry.key] = flagInfo['enabled'] as bool? ?? false;
        }

        return {
          'success': true,
          'data': flagStates,
          'source': result['source'],
          'note': result['note'],
        };
      } else {
        return result;
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

  // =====================================================
  // PHASE 2 FEATURES - ADVANCED ANALYTICS & ALERTS
  // =====================================================

  /// Get advanced traffic analytics with trends and patterns
  Future<Map<String, dynamic>> getAdvancedTrafficAnalytics({
    Duration timeWindow = const Duration(hours: 24),
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Calculating advanced traffic analytics...');
      }

      final startTime = DateTime.now().subtract(timeWindow);

      // Get all logs in time window with detailed info
      final logs = await _supabase
          .from('edge_function_logs')
          .select(
            'endpoint, status, latency_ms, ts, user_agent, api_call_count',
          )
          .gte('ts', startTime.toIso8601String())
          .order('ts', ascending: true);

      // Calculate hourly traffic patterns
      final hourlyTraffic = <int, Map<String, int>>{};
      final endpointTrends = <String, List<Map<String, dynamic>>>{};
      final peakUsageTimes = <String, int>{};

      for (final log in logs) {
        final timestamp = DateTime.parse(log['ts'] as String);
        final hour = timestamp.hour;
        final endpoint = log['endpoint'] as String;
        final status = log['status'] as int;
        final callCount = log['api_call_count'] as int? ?? 1;

        // Hourly traffic aggregation
        hourlyTraffic[hour] ??= {'total': 0, 'errors': 0};
        hourlyTraffic[hour]!['total'] =
            hourlyTraffic[hour]!['total']! + callCount;
        if (status >= 400) {
          hourlyTraffic[hour]!['errors'] =
              hourlyTraffic[hour]!['errors']! + callCount;
        }

        // Endpoint trends
        endpointTrends[endpoint] ??= [];
        endpointTrends[endpoint]!.add({
          'timestamp': timestamp.millisecondsSinceEpoch,
          'status': status,
          'latency': log['latency_ms'] ?? 0,
          'calls': callCount,
        });

        // Peak usage tracking
        final timeSlot = '${hour.toString().padLeft(2, '0')}:00';
        peakUsageTimes[timeSlot] = (peakUsageTimes[timeSlot] ?? 0) + callCount;
      }

      // Find peak usage hour
      final peakHour = peakUsageTimes.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );

      // Calculate trends for each endpoint
      final endpointAnalytics = <String, Map<String, dynamic>>{};
      for (final endpoint in endpointTrends.keys) {
        final trends = endpointTrends[endpoint]!;
        if (trends.length >= 2) {
          final firstHalf = trends.take(trends.length ~/ 2).toList();
          final secondHalf = trends.skip(trends.length ~/ 2).toList();

          final firstHalfAvgLatency = firstHalf.isEmpty
              ? 0.0
              : firstHalf
                        .map((t) => t['latency'] as int)
                        .reduce((a, b) => a + b) /
                    firstHalf.length;
          final secondHalfAvgLatency = secondHalf.isEmpty
              ? 0.0
              : secondHalf
                        .map((t) => t['latency'] as int)
                        .reduce((a, b) => a + b) /
                    secondHalf.length;

          final latencyTrend = secondHalfAvgLatency - firstHalfAvgLatency;

          endpointAnalytics[endpoint] = {
            'total_calls': trends.length,
            'avg_latency':
                trends.map((t) => t['latency'] as int).reduce((a, b) => a + b) /
                trends.length,
            'latency_trend': latencyTrend,
            'trend_direction': latencyTrend > 10
                ? 'increasing'
                : latencyTrend < -10
                ? 'decreasing'
                : 'stable',
            'error_rate':
                trends.where((t) => t['status'] >= 400).length /
                trends.length *
                100,
          };
        }
      }

      if (kDebugMode) {
        print(
          '✅ DEBUG_PANEL - Advanced analytics calculated for ${endpointAnalytics.length} endpoints',
        );
      }

      return {
        'success': true,
        'data': {
          'hourly_traffic': hourlyTraffic,
          'endpoint_analytics': endpointAnalytics,
          'peak_usage': {'time': peakHour.key, 'requests': peakHour.value},
          'time_window_hours': timeWindow.inHours,
          'total_endpoints': endpointTrends.length,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error calculating advanced analytics: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }

  /// Get system alerts based on thresholds and patterns
  Future<Map<String, dynamic>> getSystemAlerts() async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Checking system alerts...');
      }

      final alerts = <Map<String, dynamic>>[];
      final now = DateTime.now();
      final lastHour = now.subtract(const Duration(hours: 1));

      // Check error rate alerts (threshold: 5%)
      final statsResult = await getEndpointStatistics(
        timeWindow: const Duration(hours: 1),
      );
      if (statsResult['success']) {
        final stats = statsResult['data'] as Map<String, dynamic>;
        for (final endpoint in stats.keys) {
          final endpointStats = stats[endpoint] as Map<String, dynamic>;
          final errorRate = endpointStats['error_rate'] as double;

          if (errorRate > 5.0) {
            alerts.add({
              'type': 'error_rate',
              'severity': errorRate > 15.0 ? 'critical' : 'warning',
              'endpoint': endpoint,
              'message':
                  'High error rate detected: ${errorRate.toStringAsFixed(1)}%',
              'value': errorRate,
              'threshold': 5.0,
              'timestamp': now.toIso8601String(),
            });
          }
        }
      }

      // Check latency alerts (threshold: 2000ms)
      final recentLogs = await _supabase
          .from('edge_function_logs')
          .select('endpoint, latency_ms')
          .gte('ts', lastHour.toIso8601String())
          .gte('latency_ms', 2000);

      final latencyAlerts = <String, List<int>>{};
      for (final log in recentLogs) {
        final endpoint = log['endpoint'] as String;
        final latency = log['latency_ms'] as int;
        latencyAlerts[endpoint] ??= [];
        latencyAlerts[endpoint]!.add(latency);
      }

      for (final endpoint in latencyAlerts.keys) {
        final latencies = latencyAlerts[endpoint]!;
        final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;

        alerts.add({
          'type': 'high_latency',
          'severity': avgLatency > 5000 ? 'critical' : 'warning',
          'endpoint': endpoint,
          'message':
              'High latency detected: ${avgLatency.toStringAsFixed(0)}ms avg',
          'value': avgLatency,
          'threshold': 2000,
          'occurrences': latencies.length,
          'timestamp': now.toIso8601String(),
        });
      }

      // Check for authentication failures spike
      final authFailures = await _supabase
          .from('odoo_session_logs')
          .select('failure_reason')
          .eq('success', false)
          .gte('attempt_timestamp', lastHour.toIso8601String());

      if (authFailures.length > 10) {
        alerts.add({
          'type': 'auth_failures',
          'severity': authFailures.length > 20 ? 'critical' : 'warning',
          'endpoint': 'odoo-auth',
          'message':
              'High authentication failure rate: ${authFailures.length} failures in last hour',
          'value': authFailures.length,
          'threshold': 10,
          'timestamp': now.toIso8601String(),
        });
      }

      // Sort alerts by severity (critical first)
      alerts.sort((a, b) {
        final severityOrder = {'critical': 0, 'warning': 1, 'info': 2};
        return (severityOrder[a['severity']] ?? 2).compareTo(
          severityOrder[b['severity']] ?? 2,
        );
      });

      if (kDebugMode) {
        print('✅ DEBUG_PANEL - Found ${alerts.length} system alerts');
      }

      return {
        'success': true,
        'data': alerts,
        'summary': {
          'total_alerts': alerts.length,
          'critical': alerts.where((a) => a['severity'] == 'critical').length,
          'warnings': alerts.where((a) => a['severity'] == 'warning').length,
          'last_checked': now.toIso8601String(),
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error checking system alerts: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
        'summary': {'total_alerts': 0, 'critical': 0, 'warnings': 0},
      };
    }
  }

  /// Get performance insights and recommendations
  Future<Map<String, dynamic>> getPerformanceInsights() async {
    try {
      final insights = <Map<String, dynamic>>[];
      final recommendations = <String>[];

      // Get recent performance data
      final statsResult = await getEndpointStatistics(
        timeWindow: const Duration(hours: 24),
      );
      if (statsResult['success']) {
        final stats = statsResult['data'] as Map<String, dynamic>;

        // Analyze each endpoint
        for (final endpoint in stats.keys) {
          final endpointStats = stats[endpoint] as Map<String, dynamic>;
          final avgLatency = endpointStats['avg_latency'] as double;
          final errorRate = endpointStats['error_rate'] as double;
          final totalCalls = endpointStats['total_calls'] as int;

          // Performance insights
          if (avgLatency > 1000) {
            insights.add({
              'type': 'performance',
              'endpoint': endpoint,
              'issue': 'High average latency',
              'value': avgLatency,
              'impact': 'User experience degradation',
              'priority': avgLatency > 2000 ? 'high' : 'medium',
            });

            recommendations.add(
              'Optimize $endpoint endpoint - current avg latency: ${avgLatency.toStringAsFixed(0)}ms',
            );
          }

          if (errorRate > 2.0 && totalCalls > 10) {
            insights.add({
              'type': 'reliability',
              'endpoint': endpoint,
              'issue': 'Elevated error rate',
              'value': errorRate,
              'impact': 'Service reliability concerns',
              'priority': errorRate > 10.0 ? 'high' : 'medium',
            });

            recommendations.add(
              'Investigate $endpoint errors - current error rate: ${errorRate.toStringAsFixed(1)}%',
            );
          }

          if (totalCalls > 1000) {
            insights.add({
              'type': 'usage',
              'endpoint': endpoint,
              'issue': 'High traffic volume',
              'value': totalCalls.toDouble(),
              'impact': 'Potential scaling needs',
              'priority': 'low',
            });
          }
        }
      }

      return {
        'success': true,
        'data': {
          'insights': insights,
          'recommendations': recommendations,
          'analysis_period': '24 hours',
          'generated_at': DateTime.now().toIso8601String(),
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error generating performance insights: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': {'insights': [], 'recommendations': []},
      };
    }
  }

  // =====================================================
  // PHASE 3 FEATURES - ANOMALY DETECTION & ANALYTICS
  // =====================================================

  /// Get anomaly detection results (Phase 3)
  Future<Map<String, dynamic>> getAnomalyDetectionResults() async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Running anomaly detection...');
      }

      final anomalyService = AnomalyDetectionService();
      if (!anomalyService.isAvailable) {
        return {
          'success': false,
          'error': 'Anomaly detection service not available',
          'data': [],
        };
      }

      final result = await anomalyService.detectTrafficAnomalies();

      if (kDebugMode) {
        print('✅ DEBUG_PANEL - Anomaly detection completed');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error running anomaly detection: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Get traffic pattern analysis (Phase 3)
  Future<Map<String, dynamic>> getTrafficPatternAnalysis() async {
    try {
      final anomalyService = AnomalyDetectionService();
      return await anomalyService.analyzeTrafficPatterns();
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error analyzing traffic patterns: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': {}};
    }
  }

  /// Get comprehensive traffic logs combining custom logs and Supabase native logs
  /// This provides a unified view of all system activity
  Future<Map<String, dynamic>> getComprehensiveTrafficLogs({
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
        print('🔍 DEBUG_PANEL - Fetching comprehensive traffic logs...');
      }

      // Get both custom logs and Supabase native logs in parallel
      final futures = await Future.wait([
        // Custom edge function logs from our table
        getEdgeFunctionLogs(
          page: page,
          limit: limit ~/ 2, // Split the limit
          endpoint: endpoint,
          statusCode: statusCode,
          startDate: startDate,
          endDate: endDate,
          searchQuery: searchQuery,
        ),
        // Supabase native logs
        _supabaseLogsService.getEdgeFunctionLogs(
          startTime:
              startDate ?? DateTime.now().subtract(const Duration(hours: 1)),
          endTime: endDate ?? DateTime.now(),
          limit: limit ~/ 2, // Split the limit
        ),
      ]);

      final customLogs = futures[0];
      final nativeLogs = futures[1];

      // Combine and merge the logs
      final List<Map<String, dynamic>> combinedLogs = [];

      // Add custom logs
      if (customLogs['success'] == true) {
        final logs = customLogs['data'] as List;
        for (final log in logs) {
          combinedLogs.add({
            ...log,
            'source': 'custom_logging',
            'log_type': 'edge_function_custom',
          });
        }
      }

      // Add native logs
      if (nativeLogs['success'] == true) {
        final logs = nativeLogs['data'] as List;
        for (final log in logs) {
          combinedLogs.add({
            ...log,
            'source': 'supabase_native',
            'log_type': 'edge_function_native',
          });
        }
      }

      // Sort by timestamp (most recent first)
      combinedLogs.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['timestamp'] ?? a['ts'] ?? '') ??
            DateTime.now();
        final bTime =
            DateTime.tryParse(b['timestamp'] ?? b['ts'] ?? '') ??
            DateTime.now();
        return bTime.compareTo(aTime);
      });

      // Apply limit to combined results
      final limitedLogs = combinedLogs.take(limit).toList();

      return {
        'success': true,
        'data': limitedLogs,
        'total': limitedLogs.length,
        'custom_logs_available': customLogs['success'] == true,
        'native_logs_available': nativeLogs['success'] == true,
        'supabase_logs_configured': _supabaseLogsService.isConfigured,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching comprehensive logs: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Get Supabase native system logs (database, API gateway, etc.)
  Future<Map<String, dynamic>> getSupabaseSystemLogs({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Fetching Supabase system logs...');
      }

      if (!_supabaseLogsService.isConfigured) {
        return {
          'success': false,
          'error':
              'Supabase Management API not configured. Set SUPABASE_MANAGEMENT_TOKEN environment variable.',
          'data': [],
          'configuration_required': true,
        };
      }

      // Get comprehensive system logs from Supabase
      final result = await _supabaseLogsService.getSystemLogs(
        startTime:
            startTime ?? DateTime.now().subtract(const Duration(hours: 1)),
        endTime: endTime ?? DateTime.now(),
        limit: limit,
      );

      return {...result, 'source': 'supabase_native'};
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching Supabase system logs: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Get database-specific logs from Supabase native logging
  Future<Map<String, dynamic>> getSupabaseDatabaseLogs({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Fetching Supabase database logs...');
      }

      if (!_supabaseLogsService.isConfigured) {
        return {
          'success': false,
          'error': 'Supabase Management API not configured',
          'data': [],
          'configuration_required': true,
        };
      }

      final result = await _supabaseLogsService.getDatabaseLogs(
        startTime:
            startTime ?? DateTime.now().subtract(const Duration(hours: 1)),
        endTime: endTime ?? DateTime.now(),
        limit: limit,
      );

      return {...result, 'source': 'supabase_native'};
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching database logs: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }

  /// Get API Gateway logs from Supabase native logging
  Future<Map<String, dynamic>> getSupabaseApiLogs({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 DEBUG_PANEL - Fetching Supabase API logs...');
      }

      if (!_supabaseLogsService.isConfigured) {
        return {
          'success': false,
          'error': 'Supabase Management API not configured',
          'data': [],
          'configuration_required': true,
        };
      }

      final result = await _supabaseLogsService.getApiGatewayLogs(
        startTime:
            startTime ?? DateTime.now().subtract(const Duration(hours: 1)),
        endTime: endTime ?? DateTime.now(),
        limit: limit,
      );

      return {...result, 'source': 'supabase_native'};
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error fetching API logs: $e');
      }
      return {'success': false, 'error': e.toString(), 'data': []};
    }
  }
}
