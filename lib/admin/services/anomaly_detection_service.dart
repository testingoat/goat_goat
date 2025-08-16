import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

/// Service for detecting anomalies in system traffic and behavior
/// Zero-risk implementation using statistical analysis for pattern detection
class AnomalyDetectionService {
  static final AnomalyDetectionService _instance = AnomalyDetectionService._internal();
  factory AnomalyDetectionService() => _instance;
  AnomalyDetectionService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Feature flag for anomaly detection
  static const bool _enableAnomalyDetection = true;

  /// Check if anomaly detection is available
  bool get isAvailable => _enableAnomalyDetection;

  // =====================================================
  // TRAFFIC ANOMALY DETECTION
  // =====================================================

  /// Detect traffic anomalies using statistical analysis
  Future<Map<String, dynamic>> detectTrafficAnomalies({
    Duration analysisWindow = const Duration(hours: 24),
    Duration baselineWindow = const Duration(days: 7),
  }) async {
    try {
      if (kDebugMode) {
        print('🔍 ANOMALY_DETECTION - Analyzing traffic patterns...');
      }

      final now = DateTime.now();
      final analysisStart = now.subtract(analysisWindow);
      final baselineStart = now.subtract(baselineWindow);

      // Get recent traffic data
      final recentTraffic = await _supabase
          .from('edge_function_logs')
          .select('endpoint, status, latency_ms, ts, api_call_count')
          .gte('ts', analysisStart.toIso8601String())
          .order('ts', ascending: true);

      // Get baseline traffic data
      final baselineTraffic = await _supabase
          .from('edge_function_logs')
          .select('endpoint, status, latency_ms, ts, api_call_count')
          .gte('ts', baselineStart.toIso8601String())
          .lt('ts', analysisStart.toIso8601String())
          .order('ts', ascending: true);

      final anomalies = <Map<String, dynamic>>[];

      // Analyze traffic volume anomalies
      final volumeAnomalies = await _detectVolumeAnomalies(recentTraffic, baselineTraffic);
      anomalies.addAll(volumeAnomalies);

      // Analyze error rate anomalies
      final errorAnomalies = await _detectErrorRateAnomalies(recentTraffic, baselineTraffic);
      anomalies.addAll(errorAnomalies);

      // Analyze latency anomalies
      final latencyAnomalies = await _detectLatencyAnomalies(recentTraffic, baselineTraffic);
      anomalies.addAll(latencyAnomalies);

      // Sort by severity
      anomalies.sort((a, b) => _getSeverityScore(b).compareTo(_getSeverityScore(a)));

      if (kDebugMode) {
        print('✅ ANOMALY_DETECTION - Found ${anomalies.length} anomalies');
      }

      return {
        'success': true,
        'data': anomalies,
        'analysis_period': {
          'recent_window_hours': analysisWindow.inHours,
          'baseline_window_days': baselineWindow.inDays,
          'total_recent_requests': recentTraffic.length,
          'total_baseline_requests': baselineTraffic.length,
        },
        'summary': {
          'total_anomalies': anomalies.length,
          'critical': anomalies.where((a) => a['severity'] == 'critical').length,
          'warning': anomalies.where((a) => a['severity'] == 'warning').length,
          'info': anomalies.where((a) => a['severity'] == 'info').length,
        },
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ ANOMALY_DETECTION - Error detecting anomalies: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': [],
      };
    }
  }

  /// Detect volume anomalies using statistical analysis
  Future<List<Map<String, dynamic>>> _detectVolumeAnomalies(
    List<dynamic> recentTraffic,
    List<dynamic> baselineTraffic,
  ) async {
    final anomalies = <Map<String, dynamic>>[];

    // Group by endpoint
    final recentByEndpoint = _groupByEndpoint(recentTraffic);
    final baselineByEndpoint = _groupByEndpoint(baselineTraffic);

    for (final endpoint in recentByEndpoint.keys) {
      final recentCalls = recentByEndpoint[endpoint]!;
      final baselineCalls = baselineByEndpoint[endpoint] ?? [];

      if (baselineCalls.isEmpty) continue;

      // Calculate hourly averages
      final recentHourlyAvg = recentCalls.length / 24.0; // Last 24 hours
      final baselineHourlyAvg = baselineCalls.length / (7 * 24.0); // Last 7 days

      // Detect significant increases (more than 3x baseline)
      if (recentHourlyAvg > baselineHourlyAvg * 3 && recentHourlyAvg > 10) {
        final increasePercent = ((recentHourlyAvg - baselineHourlyAvg) / baselineHourlyAvg) * 100;
        
        anomalies.add({
          'type': 'traffic_spike',
          'endpoint': endpoint,
          'severity': increasePercent > 500 ? 'critical' : 'warning',
          'message': 'Traffic spike detected: ${increasePercent.toStringAsFixed(0)}% increase',
          'details': {
            'recent_hourly_avg': recentHourlyAvg.toStringAsFixed(1),
            'baseline_hourly_avg': baselineHourlyAvg.toStringAsFixed(1),
            'increase_percent': increasePercent.toStringAsFixed(1),
          },
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      // Detect significant decreases (less than 0.3x baseline)
      if (recentHourlyAvg < baselineHourlyAvg * 0.3 && baselineHourlyAvg > 5) {
        final decreasePercent = ((baselineHourlyAvg - recentHourlyAvg) / baselineHourlyAvg) * 100;
        
        anomalies.add({
          'type': 'traffic_drop',
          'endpoint': endpoint,
          'severity': decreasePercent > 80 ? 'warning' : 'info',
          'message': 'Traffic drop detected: ${decreasePercent.toStringAsFixed(0)}% decrease',
          'details': {
            'recent_hourly_avg': recentHourlyAvg.toStringAsFixed(1),
            'baseline_hourly_avg': baselineHourlyAvg.toStringAsFixed(1),
            'decrease_percent': decreasePercent.toStringAsFixed(1),
          },
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    return anomalies;
  }

  /// Detect error rate anomalies
  Future<List<Map<String, dynamic>>> _detectErrorRateAnomalies(
    List<dynamic> recentTraffic,
    List<dynamic> baselineTraffic,
  ) async {
    final anomalies = <Map<String, dynamic>>[];

    // Group by endpoint
    final recentByEndpoint = _groupByEndpoint(recentTraffic);
    final baselineByEndpoint = _groupByEndpoint(baselineTraffic);

    for (final endpoint in recentByEndpoint.keys) {
      final recentCalls = recentByEndpoint[endpoint]!;
      final baselineCalls = baselineByEndpoint[endpoint] ?? [];

      if (recentCalls.length < 10 || baselineCalls.length < 50) continue; // Need sufficient data

      // Calculate error rates
      final recentErrors = recentCalls.where((call) => call['status'] >= 400).length;
      final baselineErrors = baselineCalls.where((call) => call['status'] >= 400).length;

      final recentErrorRate = (recentErrors / recentCalls.length) * 100;
      final baselineErrorRate = (baselineErrors / baselineCalls.length) * 100;

      // Detect significant error rate increases
      if (recentErrorRate > baselineErrorRate + 5 && recentErrorRate > 10) {
        final increase = recentErrorRate - baselineErrorRate;
        
        anomalies.add({
          'type': 'error_rate_spike',
          'endpoint': endpoint,
          'severity': recentErrorRate > 25 ? 'critical' : 'warning',
          'message': 'Error rate spike: ${recentErrorRate.toStringAsFixed(1)}% (baseline: ${baselineErrorRate.toStringAsFixed(1)}%)',
          'details': {
            'recent_error_rate': recentErrorRate.toStringAsFixed(1),
            'baseline_error_rate': baselineErrorRate.toStringAsFixed(1),
            'increase': increase.toStringAsFixed(1),
            'recent_total_calls': recentCalls.length,
            'recent_error_calls': recentErrors,
          },
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    return anomalies;
  }

  /// Detect latency anomalies
  Future<List<Map<String, dynamic>>> _detectLatencyAnomalies(
    List<dynamic> recentTraffic,
    List<dynamic> baselineTraffic,
  ) async {
    final anomalies = <Map<String, dynamic>>[];

    // Group by endpoint
    final recentByEndpoint = _groupByEndpoint(recentTraffic);
    final baselineByEndpoint = _groupByEndpoint(baselineTraffic);

    for (final endpoint in recentByEndpoint.keys) {
      final recentCalls = recentByEndpoint[endpoint]!;
      final baselineCalls = baselineByEndpoint[endpoint] ?? [];

      if (recentCalls.length < 10 || baselineCalls.length < 50) continue;

      // Calculate average latencies
      final recentLatencies = recentCalls
          .map((call) => call['latency_ms'] as int? ?? 0)
          .where((latency) => latency > 0)
          .toList();
      
      final baselineLatencies = baselineCalls
          .map((call) => call['latency_ms'] as int? ?? 0)
          .where((latency) => latency > 0)
          .toList();

      if (recentLatencies.isEmpty || baselineLatencies.isEmpty) continue;

      final recentAvgLatency = recentLatencies.reduce((a, b) => a + b) / recentLatencies.length;
      final baselineAvgLatency = baselineLatencies.reduce((a, b) => a + b) / baselineLatencies.length;

      // Detect significant latency increases (more than 2x baseline)
      if (recentAvgLatency > baselineAvgLatency * 2 && recentAvgLatency > 1000) {
        final increasePercent = ((recentAvgLatency - baselineAvgLatency) / baselineAvgLatency) * 100;
        
        anomalies.add({
          'type': 'latency_spike',
          'endpoint': endpoint,
          'severity': recentAvgLatency > 5000 ? 'critical' : 'warning',
          'message': 'Latency spike: ${recentAvgLatency.toStringAsFixed(0)}ms (baseline: ${baselineAvgLatency.toStringAsFixed(0)}ms)',
          'details': {
            'recent_avg_latency': recentAvgLatency.toStringAsFixed(0),
            'baseline_avg_latency': baselineAvgLatency.toStringAsFixed(0),
            'increase_percent': increasePercent.toStringAsFixed(1),
            'recent_p95_latency': _calculatePercentile(recentLatencies, 0.95).toStringAsFixed(0),
          },
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }

    return anomalies;
  }

  /// Group traffic data by endpoint
  Map<String, List<dynamic>> _groupByEndpoint(List<dynamic> traffic) {
    final grouped = <String, List<dynamic>>{};
    for (final call in traffic) {
      final endpoint = call['endpoint'] as String;
      grouped[endpoint] ??= [];
      grouped[endpoint]!.add(call);
    }
    return grouped;
  }

  /// Calculate percentile value
  double _calculatePercentile(List<int> values, double percentile) {
    if (values.isEmpty) return 0.0;
    
    final sorted = List<int>.from(values)..sort();
    final index = (sorted.length * percentile).floor();
    return sorted[math.min(index, sorted.length - 1)].toDouble();
  }

  /// Get severity score for sorting
  int _getSeverityScore(Map<String, dynamic> anomaly) {
    switch (anomaly['severity']) {
      case 'critical':
        return 3;
      case 'warning':
        return 2;
      case 'info':
        return 1;
      default:
        return 0;
    }
  }

  // =====================================================
  // PATTERN ANALYSIS
  // =====================================================

  /// Analyze traffic patterns for unusual behavior
  Future<Map<String, dynamic>> analyzeTrafficPatterns() async {
    try {
      final now = DateTime.now();
      final last24Hours = now.subtract(const Duration(hours: 24));

      final traffic = await _supabase
          .from('edge_function_logs')
          .select('endpoint, status, ts, user_agent')
          .gte('ts', last24Hours.toIso8601String())
          .order('ts', ascending: true);

      final patterns = <String, dynamic>{};

      // Analyze hourly distribution
      final hourlyDistribution = <int, int>{};
      for (final call in traffic) {
        final timestamp = DateTime.parse(call['ts'] as String);
        final hour = timestamp.hour;
        hourlyDistribution[hour] = (hourlyDistribution[hour] ?? 0) + 1;
      }

      // Find unusual hours (significantly different from average)
      final avgHourlyTraffic = hourlyDistribution.values.isEmpty 
          ? 0.0 
          : hourlyDistribution.values.reduce((a, b) => a + b) / 24.0;
      
      final unusualHours = <Map<String, dynamic>>[];
      for (final entry in hourlyDistribution.entries) {
        if (entry.value > avgHourlyTraffic * 3) {
          unusualHours.add({
            'hour': entry.key,
            'requests': entry.value,
            'avg_requests': avgHourlyTraffic.toStringAsFixed(1),
            'multiplier': (entry.value / avgHourlyTraffic).toStringAsFixed(1),
          });
        }
      }

      patterns['hourly_distribution'] = hourlyDistribution;
      patterns['unusual_hours'] = unusualHours;
      patterns['avg_hourly_traffic'] = avgHourlyTraffic;

      return {
        'success': true,
        'data': patterns,
        'analysis_period_hours': 24,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ ANOMALY_DETECTION - Error analyzing patterns: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
        'data': {},
      };
    }
  }
}
