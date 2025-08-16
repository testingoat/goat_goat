import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for accessing Supabase native logs via Management API
/// Integrates with Supabase's built-in logging system to show real traffic data
/// 
/// Zero-risk implementation that supplements existing debug panel functionality
/// without modifying core business logic or critical system files.
class SupabaseLogsService {
  static const String _baseUrl = 'https://api.supabase.com/v1';
  static const String _projectRef = 'oaynfzqjielnsipttzbs'; // GOATGOAT project
  
  // Personal Access Token for Supabase Management API
  // This should be set via environment variable or secure configuration
  static const String? _accessToken = String.fromEnvironment('SUPABASE_MANAGEMENT_TOKEN');
  
  /// Check if the service is properly configured
  bool get isConfigured => _accessToken != null && _accessToken!.isNotEmpty;
  
  /// Get edge function logs from Supabase native logging system
  Future<Map<String, dynamic>> getEdgeFunctionLogs({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      if (!isConfigured) {
        return {
          'success': false,
          'error': 'Supabase Management API token not configured',
          'data': [],
        };
      }

      // Default to last hour if no time range specified
      final now = DateTime.now();
      final start = startTime ?? now.subtract(const Duration(hours: 1));
      final end = endTime ?? now;
      
      // Validate time range (max 24 hours as per API docs)
      final duration = end.difference(start);
      if (duration.inHours > 24) {
        return {
          'success': false,
          'error': 'Time range cannot exceed 24 hours',
          'data': [],
        };
      }

      // SQL query to get edge function logs
      final sql = '''
        SELECT 
          timestamp,
          event_message,
          metadata,
          level
        FROM edge_logs 
        WHERE timestamp >= '${start.toIso8601String()}'
          AND timestamp <= '${end.toIso8601String()}'
          AND event_message LIKE '%edge-runtime%'
        ORDER BY timestamp DESC
        LIMIT $limit
      ''';

      final response = await _makeApiCall(
        'GET',
        '/projects/$_projectRef/analytics/endpoints/logs.all',
        queryParams: {
          'sql': sql,
          'iso_timestamp_start': start.toIso8601String(),
          'iso_timestamp_end': end.toIso8601String(),
        },
      );

      if (response['success']) {
        final logs = response['data']['result'] as List? ?? [];
        return {
          'success': true,
          'data': logs.map((log) => _parseEdgeFunctionLog(log)).toList(),
          'total': logs.length,
        };
      } else {
        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SUPABASE_LOGS - Error fetching edge function logs: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Get database logs from Supabase native logging system
  Future<Map<String, dynamic>> getDatabaseLogs({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      if (!isConfigured) {
        return {
          'success': false,
          'error': 'Supabase Management API token not configured',
          'data': [],
        };
      }

      final now = DateTime.now();
      final start = startTime ?? now.subtract(const Duration(hours: 1));
      final end = endTime ?? now;
      
      final duration = end.difference(start);
      if (duration.inHours > 24) {
        return {
          'success': false,
          'error': 'Time range cannot exceed 24 hours',
          'data': [],
        };
      }

      // SQL query to get database logs
      final sql = '''
        SELECT 
          timestamp,
          event_message,
          metadata,
          level
        FROM postgres_logs 
        WHERE timestamp >= '${start.toIso8601String()}'
          AND timestamp <= '${end.toIso8601String()}'
        ORDER BY timestamp DESC
        LIMIT $limit
      ''';

      final response = await _makeApiCall(
        'GET',
        '/projects/$_projectRef/analytics/endpoints/logs.all',
        queryParams: {
          'sql': sql,
          'iso_timestamp_start': start.toIso8601String(),
          'iso_timestamp_end': end.toIso8601String(),
        },
      );

      if (response['success']) {
        final logs = response['data']['result'] as List? ?? [];
        return {
          'success': true,
          'data': logs.map((log) => _parseDatabaseLog(log)).toList(),
          'total': logs.length,
        };
      } else {
        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SUPABASE_LOGS - Error fetching database logs: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Get API Gateway logs (REST API calls)
  Future<Map<String, dynamic>> getApiGatewayLogs({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      if (!isConfigured) {
        return {
          'success': false,
          'error': 'Supabase Management API token not configured',
          'data': [],
        };
      }

      final now = DateTime.now();
      final start = startTime ?? now.subtract(const Duration(hours: 1));
      final end = endTime ?? now;
      
      final duration = end.difference(start);
      if (duration.inHours > 24) {
        return {
          'success': false,
          'error': 'Time range cannot exceed 24 hours',
          'data': [],
        };
      }

      // SQL query to get API gateway logs
      final sql = '''
        SELECT 
          timestamp,
          event_message,
          metadata,
          level
        FROM api_logs 
        WHERE timestamp >= '${start.toIso8601String()}'
          AND timestamp <= '${end.toIso8601String()}'
        ORDER BY timestamp DESC
        LIMIT $limit
      ''';

      final response = await _makeApiCall(
        'GET',
        '/projects/$_projectRef/analytics/endpoints/logs.all',
        queryParams: {
          'sql': sql,
          'iso_timestamp_start': start.toIso8601String(),
          'iso_timestamp_end': end.toIso8601String(),
        },
      );

      if (response['success']) {
        final logs = response['data']['result'] as List? ?? [];
        return {
          'success': true,
          'data': logs.map((log) => _parseApiGatewayLog(log)).toList(),
          'total': logs.length,
        };
      } else {
        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SUPABASE_LOGS - Error fetching API gateway logs: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Get comprehensive system logs (all types combined)
  Future<Map<String, dynamic>> getSystemLogs({
    DateTime? startTime,
    DateTime? endTime,
    int limit = 100,
  }) async {
    try {
      if (!isConfigured) {
        return {
          'success': false,
          'error': 'Supabase Management API token not configured',
          'data': [],
        };
      }

      final now = DateTime.now();
      final start = startTime ?? now.subtract(const Duration(hours: 1));
      final end = endTime ?? now;
      
      final duration = end.difference(start);
      if (duration.inHours > 24) {
        return {
          'success': false,
          'error': 'Time range cannot exceed 24 hours',
          'data': [],
        };
      }

      // SQL query to get all system logs
      final sql = '''
        SELECT 
          timestamp,
          event_message,
          metadata,
          level,
          'system' as log_type
        FROM (
          SELECT timestamp, event_message, metadata, level FROM edge_logs
          UNION ALL
          SELECT timestamp, event_message, metadata, level FROM postgres_logs
          UNION ALL
          SELECT timestamp, event_message, metadata, level FROM api_logs
        ) combined_logs
        WHERE timestamp >= '${start.toIso8601String()}'
          AND timestamp <= '${end.toIso8601String()}'
        ORDER BY timestamp DESC
        LIMIT $limit
      ''';

      final response = await _makeApiCall(
        'GET',
        '/projects/$_projectRef/analytics/endpoints/logs.all',
        queryParams: {
          'sql': sql,
          'iso_timestamp_start': start.toIso8601String(),
          'iso_timestamp_end': end.toIso8601String(),
        },
      );

      if (response['success']) {
        final logs = response['data']['result'] as List? ?? [];
        return {
          'success': true,
          'data': logs.map((log) => _parseSystemLog(log)).toList(),
          'total': logs.length,
        };
      } else {
        return response;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ SUPABASE_LOGS - Error fetching system logs: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Make API call to Supabase Management API
  Future<Map<String, dynamic>> _makeApiCall(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final finalUri = queryParams != null 
          ? uri.replace(queryParameters: queryParams)
          : uri;

      final headers = {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

      late http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(finalUri, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            finalUri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'API call failed',
          'status_code': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Parse edge function log entry
  Map<String, dynamic> _parseEdgeFunctionLog(dynamic log) {
    return {
      'timestamp': log['timestamp'],
      'message': log['event_message'],
      'level': log['level'],
      'metadata': log['metadata'],
      'type': 'edge_function',
    };
  }

  /// Parse database log entry
  Map<String, dynamic> _parseDatabaseLog(dynamic log) {
    return {
      'timestamp': log['timestamp'],
      'message': log['event_message'],
      'level': log['level'],
      'metadata': log['metadata'],
      'type': 'database',
    };
  }

  /// Parse API gateway log entry
  Map<String, dynamic> _parseApiGatewayLog(dynamic log) {
    return {
      'timestamp': log['timestamp'],
      'message': log['event_message'],
      'level': log['level'],
      'metadata': log['metadata'],
      'type': 'api_gateway',
    };
  }

  /// Parse system log entry
  Map<String, dynamic> _parseSystemLog(dynamic log) {
    return {
      'timestamp': log['timestamp'],
      'message': log['event_message'],
      'level': log['level'],
      'metadata': log['metadata'],
      'type': log['log_type'] ?? 'system',
    };
  }
}
