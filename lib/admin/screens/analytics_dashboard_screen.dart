import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/business_intelligence_service.dart';
import '../services/mobile_analytics_service.dart';
import '../services/anomaly_detection_service.dart';
import '../widgets/analytics_card.dart';
import '../widgets/analytics_chart.dart';

/// Phase 3 Analytics Dashboard Screen
/// Provides comprehensive business intelligence and system monitoring
///
/// Zero-risk implementation that adds new analytics capabilities
/// without modifying existing admin panel functionality
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final BusinessIntelligenceService _biService = BusinessIntelligenceService();
  final MobileAnalyticsService _mobileService = MobileAnalyticsService();
  final AnomalyDetectionService _anomalyService = AnomalyDetectionService();

  Map<String, dynamic>? _businessData;
  Map<String, dynamic>? _mobileData;
  Map<String, dynamic>? _anomalyData;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all analytics data in parallel
      final futures = await Future.wait([
        _biService.getBusinessDashboard(timeWindow: const Duration(days: 30)),
        _mobileService.getMobileAppMetrics(
          timeWindow: const Duration(hours: 24),
        ),
        _anomalyService.detectTrafficAnomalies(
          analysisWindow: const Duration(hours: 24),
          baselineWindow: const Duration(days: 7),
        ),
      ]);

      if (mounted) {
        setState(() {
          _businessData = futures[0];
          _mobileData = futures[1];
          _anomalyData = futures[2];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ANALYTICS_DASHBOARD - Error loading data: $e');
      }
      if (mounted) {
        setState(() {
          _error = e.toString();
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
          'Analytics Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF059669), // emerald-600
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAnalyticsData,
            tooltip: 'Refresh Analytics',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Business'),
            Tab(icon: Icon(Icons.mobile_friendly), text: 'Mobile'),
            Tab(icon: Icon(Icons.warning), text: 'Anomalies'),
            Tab(icon: Icon(Icons.insights), text: 'Insights'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF059669),
                  ), // emerald-600
                  SizedBox(height: 16),
                  Text('Loading Analytics...'),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Analytics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAnalyticsData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669), // emerald-600
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBusinessTab(),
                _buildMobileTab(),
                _buildAnomaliesTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  Widget _buildBusinessTab() {
    if (_businessData == null || _businessData!['success'] != true) {
      return const Center(child: Text('No business data available'));
    }

    final data = _businessData!['data'] as Map<String, dynamic>;
    final revenue = data['revenue'] as Map<String, dynamic>? ?? {};
    final userGrowth = data['user_growth'] as Map<String, dynamic>? ?? {};
    final operations = data['operations'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business Intelligence',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Revenue Metrics
          Row(
            children: [
              Expanded(
                child: AnalyticsCard(
                  title: 'Total Revenue',
                  value: '₹${revenue['total_revenue'] ?? 0}',
                  icon: Icons.currency_rupee,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnalyticsCard(
                  title: 'Average Order Value',
                  value: '₹${revenue['average_order_value'] ?? 0}',
                  icon: Icons.shopping_cart,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // User Growth Metrics
          Row(
            children: [
              Expanded(
                child: AnalyticsCard(
                  title: 'New Customers',
                  value: '${userGrowth['new_customers'] ?? 0}',
                  icon: Icons.person_add,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnalyticsCard(
                  title: 'New Sellers',
                  value: '${userGrowth['new_sellers'] ?? 0}',
                  icon: Icons.store,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Operational Metrics
          Row(
            children: [
              Expanded(
                child: AnalyticsCard(
                  title: 'System Uptime',
                  value: '${operations['uptime_percentage'] ?? 0}%',
                  icon: Icons.check_circle,
                  color: const Color(0xFF059669), // emerald-600
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnalyticsCard(
                  title: 'API Requests',
                  value: '${operations['total_requests'] ?? 0}',
                  icon: Icons.api,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTab() {
    if (_mobileData == null || _mobileData!['success'] != true) {
      return const Center(child: Text('No mobile data available'));
    }

    final data = _mobileData!['data'] as Map<String, dynamic>;
    final performance = data['performance'] as Map<String, dynamic>? ?? {};
    final usage = data['usage'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mobile App Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Performance Metrics
          Row(
            children: [
              Expanded(
                child: AnalyticsCard(
                  title: 'Success Rate',
                  value: '${performance['success_rate'] ?? 0}%',
                  icon: Icons.check,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnalyticsCard(
                  title: 'Avg Latency',
                  value: '${performance['average_latency'] ?? 0}ms',
                  icon: Icons.speed,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Usage Metrics
          Row(
            children: [
              Expanded(
                child: AnalyticsCard(
                  title: 'Total Requests',
                  value: '${usage['total_requests'] ?? 0}',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnalyticsCard(
                  title: 'Peak Hour',
                  value: '${usage['peak_hour'] ?? 'N/A'}',
                  icon: Icons.schedule,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesTab() {
    if (_anomalyData == null || _anomalyData!['success'] != true) {
      return const Center(child: Text('No anomaly data available'));
    }

    final anomalies = _anomalyData!['data'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Anomalies',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (anomalies.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No anomalies detected'),
                ],
              ),
            )
          else
            ...anomalies.map(
              (anomaly) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.warning,
                    color: anomaly['severity'] == 'critical'
                        ? Colors.red
                        : Colors.orange,
                  ),
                  title: Text(anomaly['endpoint'] ?? 'Unknown'),
                  subtitle: Text(anomaly['description'] ?? ''),
                  trailing: Chip(
                    label: Text(anomaly['severity'] ?? 'unknown'),
                    backgroundColor: anomaly['severity'] == 'critical'
                        ? Colors.red[100]
                        : Colors.orange[100],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsTab() {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business Insights',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Recommendations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Monitor peak usage hours for capacity planning'),
                  Text('• Focus on mobile app performance optimization'),
                  Text('• Track user acquisition trends for growth strategies'),
                  Text('• Implement proactive anomaly alerting'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
