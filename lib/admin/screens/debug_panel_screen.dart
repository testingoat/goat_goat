import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../services/debug_panel_service.dart';
import '../services/feature_flag_service.dart';

/// Admin Debug Panel Screen - Phase 1 Implementation
/// Zero-risk implementation with read-only operations and comprehensive logging
class DebugPanelScreen extends StatefulWidget {
  const DebugPanelScreen({super.key});

  @override
  State<DebugPanelScreen> createState() => _DebugPanelScreenState();
}

class _DebugPanelScreenState extends State<DebugPanelScreen>
    with TickerProviderStateMixin {
  final DebugPanelService _debugService = DebugPanelService();
  late TabController _tabController;

  // Tab indices
  static const int _trafficTab = 0;
  static const int _odooSessionTab = 1;
  static const int _productStatusTab = 2;
  static const int _featureFlagsTab = 3;

  // Loading states
  bool _isLoading = false;
  String? _errorMessage;

  // Data
  Map<String, dynamic> _trafficData = {};
  Map<String, dynamic> _sessionData = {};
  Map<String, dynamic> _productData = {};
  Map<String, dynamic> _flagsData = {};
  Map<String, dynamic> _systemHealth = {};
  Map<String, dynamic> _systemAlerts = {};
  Map<String, dynamic> _advancedAnalytics = {};

  // Filters for traffic explorer
  String? _selectedEndpoint;
  int? _selectedStatusCode;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';
  int _currentPage = 1;
  final int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadTabData(_tabController.index);
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load system health overview first
      final healthResult = await _debugService.getSystemHealthOverview();
      if (healthResult['success']) {
        _systemHealth = healthResult['data'];
      }

      // Load system alerts (Phase 2)
      final alertsResult = await _debugService.getSystemAlerts();
      if (alertsResult['success']) {
        _systemAlerts = alertsResult;
      }

      // Load data for current tab
      await _loadTabData(_tabController.index);
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error loading initial data: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load debug panel data: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTabData(int tabIndex) async {
    try {
      switch (tabIndex) {
        case _trafficTab:
          await _loadTrafficData();
          break;
        case _odooSessionTab:
          await _loadSessionData();
          break;
        case _productStatusTab:
          await _loadProductData();
          break;
        case _featureFlagsTab:
          await _loadFlagsData();
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL - Error loading tab data: $e');
      }
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
    }
  }

  Future<void> _loadTrafficData() async {
    if (kDebugMode) {
      print('🔍 DEBUG_PANEL_SCREEN - Loading traffic data with filters:');
      print('  - page: $_currentPage, limit: $_pageSize');
      print('  - endpoint: $_selectedEndpoint');
      print('  - statusCode: $_selectedStatusCode');
      print('  - startDate: $_startDate');
      print('  - endDate: $_endDate');
      print(
        '  - searchQuery: ${_searchQuery.isNotEmpty ? _searchQuery : 'null'}',
      );
    }

    try {
      final result = await _debugService.getEdgeFunctionLogs(
        page: _currentPage,
        limit: _pageSize,
        endpoint: _selectedEndpoint,
        statusCode: _selectedStatusCode,
        startDate: _startDate,
        endDate: _endDate,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (kDebugMode) {
        print('🔍 DEBUG_PANEL_SCREEN - Traffic data result:');
        print('  - success: ${result['success']}');
        print('  - data length: ${(result['data'] as List?)?.length ?? 0}');
        print('  - error: ${result['error'] ?? 'none'}');
      }

      if (result['success']) {
        setState(() {
          _trafficData = result;
        });
      } else {
        if (kDebugMode) {
          print(
            '❌ DEBUG_PANEL_SCREEN - Failed to load traffic data: ${result['error']}',
          );
        }
        setState(() {
          _trafficData = {
            'success': false,
            'error': result['error'],
            'data': [],
          };
        });
      }

      // Also load endpoint statistics
      final statsResult = await _debugService.getEndpointStatistics();
      if (statsResult['success']) {
        setState(() {
          _trafficData['statistics'] = statsResult['data'];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL_SCREEN - Exception loading traffic data: $e');
      }
      setState(() {
        _trafficData = {'success': false, 'error': e.toString(), 'data': []};
      });
    }
  }

  Future<void> _loadSessionData() async {
    if (kDebugMode) {
      print('🔍 DEBUG_PANEL_SCREEN - Loading session data...');
    }

    try {
      final sessionResult = await _debugService.getOdooSessionLogs();
      final flagsResult = await _debugService.getFeatureFlagStates();
      final userAgentResult = await _debugService.getUserAgentBreakdown();

      if (kDebugMode) {
        print('🔍 DEBUG_PANEL_SCREEN - Session data results:');
        print('  - session success: ${sessionResult['success']}');
        print('  - flags success: ${flagsResult['success']}');
        print('  - user agents success: ${userAgentResult['success']}');
      }

      if (sessionResult['success']) {
        setState(() {
          _sessionData = sessionResult;
        });
      } else {
        if (kDebugMode) {
          print(
            '❌ DEBUG_PANEL_SCREEN - Session data failed: ${sessionResult['error']}',
          );
        }
      }

      if (flagsResult['success']) {
        setState(() {
          _sessionData['flags'] = flagsResult['data'];
        });
      } else {
        if (kDebugMode) {
          print(
            '❌ DEBUG_PANEL_SCREEN - Flags data failed: ${flagsResult['error']}',
          );
        }
      }

      if (userAgentResult['success']) {
        setState(() {
          _sessionData['user_agents'] = userAgentResult['data'];
        });
      } else {
        if (kDebugMode) {
          print(
            '❌ DEBUG_PANEL_SCREEN - User agents data failed: ${userAgentResult['error']}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL_SCREEN - Exception loading session data: $e');
      }
    }
  }

  Future<void> _loadProductData() async {
    final eventsResult = await _debugService.getProductApprovalEvents();
    final duplicatesResult = await _debugService.getDuplicatePreventionEvents();
    final dryRunResult = await _debugService.getDryRunEvents();

    if (eventsResult['success']) {
      setState(() {
        _productData = eventsResult;
      });
    }

    if (duplicatesResult['success']) {
      setState(() {
        _productData['duplicates'] = duplicatesResult['data'];
      });
    }

    if (dryRunResult['success']) {
      setState(() {
        _productData['dry_runs'] = dryRunResult['data'];
      });
    }
  }

  Future<void> _loadFlagsData() async {
    final result = await _debugService.getFeatureFlagStates();
    if (result['success']) {
      setState(() {
        _flagsData = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_debugService.isAvailable) {
      return const Center(
        child: Text(
          'Debug Panel is not available',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          _buildSystemHealthBar(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? _buildErrorWidget()
                : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report, size: 28, color: Colors.green),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug Panel (Logs)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                'System observability and troubleshooting',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _testAuthentication,
            icon: const Icon(Icons.security, size: 18),
            label: const Text('Test Auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _testDatabaseConnection,
            icon: const Icon(Icons.bug_report, size: 18),
            label: const Text('Test DB'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _forceReloadTrafficData,
            icon: const Icon(Icons.refresh_outlined, size: 18),
            label: const Text('Force Reload'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _refreshCurrentTab,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealthBar() {
    if (_systemHealth.isEmpty) return const SizedBox.shrink();

    final status = _systemHealth['system_status'] as String? ?? 'unknown';
    final errorRate = _systemHealth['current_error_rate'] as double? ?? 0.0;
    final lastHourRequests = _systemHealth['last_hour_requests'] as int? ?? 0;

    // Get alerts info (Phase 2)
    final alertsSummary =
        _systemAlerts['summary'] as Map<String, dynamic>? ?? {};
    final totalAlerts = alertsSummary['total_alerts'] as int? ?? 0;
    final criticalAlerts = alertsSummary['critical'] as int? ?? 0;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'healthy':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'degraded':
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    // Override status color if there are critical alerts
    if (criticalAlerts > 0) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: statusColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'System Status: ${criticalAlerts > 0 ? 'CRITICAL' : status.toUpperCase()}',
            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
          ),
          const SizedBox(width: 16),
          Text(
            'Error Rate: ${errorRate.toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          Text(
            'Last Hour: $lastHourRequests requests',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          // Alerts indicator (Phase 2)
          if (totalAlerts > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: criticalAlerts > 0 ? Colors.red : Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$totalAlerts Alert${totalAlerts > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          Text(
            'Last Updated: ${DateTime.now().toString().substring(11, 19)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.green[600],
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.green[600],
        tabs: const [
          Tab(text: 'Traffic Explorer'),
          Tab(text: 'Odoo Sessions'),
          Tab(text: 'Product Status'),
          Tab(text: 'Feature Flags'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildTrafficExplorer(),
        _buildOdooSessionMonitor(),
        _buildProductStatusTracker(),
        _buildFeatureFlagsViewer(),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error Loading Debug Panel',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadInitialData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _refreshCurrentTab() {
    _loadTabData(_tabController.index);
  }

  Future<void> _forceReloadTrafficData() async {
    if (kDebugMode) {
      print('🔍 DEBUG_PANEL_SCREEN - Force reloading traffic data...');
      print('  - Current _trafficData state: $_trafficData');
      print(
        '  - Current filters: endpoint=$_selectedEndpoint, status=$_selectedStatusCode',
      );
      print('  - Current pagination: page=$_currentPage, limit=$_pageSize');
    }

    // Clear current data
    setState(() {
      _trafficData = {};
    });

    // Force reload with detailed logging
    await _loadTrafficData();

    if (kDebugMode) {
      print('🔍 DEBUG_PANEL_SCREEN - Force reload completed:');
      print('  - New _trafficData state: $_trafficData');
      print(
        '  - Data array length: ${(_trafficData['data'] as List?)?.length ?? 0}',
      );
    }
  }

  Future<void> _testAuthentication() async {
    if (kDebugMode) {
      print('🔍 DEBUG_PANEL_SCREEN - Testing authentication...');
    }

    try {
      final result = await _debugService.checkAuthenticationStatus();

      if (kDebugMode) {
        print('🔍 DEBUG_PANEL_SCREEN - Authentication test result: $result');
      }

      // Show result in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              result['success']
                  ? '✅ Authentication Test'
                  : '❌ Authentication Test',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status: ${result['success'] ? 'SUCCESS' : 'FAILED'}'),
                  const SizedBox(height: 8),
                  Text(
                    'Authenticated: ${result['authenticated'] ?? 'unknown'}',
                  ),
                  const SizedBox(height: 8),
                  Text('User ID: ${result['user_id'] ?? 'null'}'),
                  const SizedBox(height: 8),
                  Text('User Email: ${result['user_email'] ?? 'null'}'),
                  const SizedBox(height: 8),
                  Text(
                    'Session Valid: ${result['session_valid'] ?? 'unknown'}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Can Query Logs: ${result['can_query_logs'] ?? 'unknown'}',
                  ),
                  if (result['error'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Error: ${result['error']}'),
                  ],
                  if (result['test_query_result'] != null) ...[
                    const SizedBox(height: 8),
                    Text('Test Query: ${result['test_query_result']}'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL_SCREEN - Authentication test exception: $e');
      }
    }
  }

  Future<void> _testDatabaseConnection() async {
    if (kDebugMode) {
      print('🔍 DEBUG_PANEL_SCREEN - Testing database connection...');
    }

    try {
      final result = await _debugService.testDatabaseConnection();

      if (kDebugMode) {
        print('🔍 DEBUG_PANEL_SCREEN - Database test result: $result');
      }

      // Show result in a dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              result['success'] ? '✅ Database Test' : '❌ Database Test',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${result['success'] ? 'SUCCESS' : 'FAILED'}'),
                const SizedBox(height: 8),
                Text('Message: ${result['message']}'),
                if (result['error'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Error: ${result['error']}'),
                ],
                if (result['sample_data'] != null) ...[
                  const SizedBox(height: 8),
                  Text('Sample Data: ${result['sample_data']}'),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG_PANEL_SCREEN - Database test exception: $e');
      }
    }
  }

  // Traffic Explorer Implementation
  Widget _buildTrafficExplorer() {
    return Column(
      children: [
        _buildTrafficFilters(),
        _buildTrafficStatistics(),
        Expanded(child: _buildTrafficTable()),
      ],
    );
  }

  Widget _buildTrafficFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              // Endpoint filter
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedEndpoint,
                  decoration: const InputDecoration(
                    labelText: 'Endpoint',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Endpoints'),
                    ),
                    ...[
                      'odoo-api-proxy',
                      'product-sync-webhook',
                      'fast2sms-otp',
                      'send-push-notification',
                    ].map((e) => DropdownMenuItem(value: e, child: Text(e))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedEndpoint = value;
                      _currentPage = 1;
                    });
                    _loadTrafficData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Status code filter
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedStatusCode,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Status')),
                    DropdownMenuItem(value: 200, child: Text('200 OK')),
                    DropdownMenuItem(
                      value: 400,
                      child: Text('400 Bad Request'),
                    ),
                    DropdownMenuItem(
                      value: 401,
                      child: Text('401 Unauthorized'),
                    ),
                    DropdownMenuItem(
                      value: 500,
                      child: Text('500 Server Error'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusCode = value;
                      _currentPage = 1;
                    });
                    _loadTrafficData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Search field
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search in payload/response',
                    border: OutlineInputBorder(),
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onSubmitted: (value) {
                    setState(() {
                      _currentPage = 1;
                    });
                    _loadTrafficData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Date range filters
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          _startDate ??
                          DateTime.now().subtract(const Duration(days: 1)),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 30),
                      ),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _startDate = date;
                        _currentPage = 1;
                      });
                      _loadTrafficData();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      _startDate?.toString().substring(0, 10) ?? 'Select date',
                      style: TextStyle(
                        color: _startDate != null
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate:
                          _startDate ??
                          DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _endDate = date;
                        _currentPage = 1;
                      });
                      _loadTrafficData();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      _endDate?.toString().substring(0, 10) ?? 'Select date',
                      style: TextStyle(
                        color: _endDate != null
                            ? Colors.black
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedEndpoint = null;
                    _selectedStatusCode = null;
                    _startDate = null;
                    _endDate = null;
                    _searchQuery = '';
                    _currentPage = 1;
                  });
                  _loadTrafficData();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficStatistics() {
    final statistics =
        _trafficData['statistics'] as Map<String, dynamic>? ?? {};

    if (statistics.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: statistics.entries.map((entry) {
          final endpoint = entry.key;
          final stats = entry.value as Map<String, dynamic>;
          final errorRate = stats['error_rate'] as double? ?? 0.0;
          final totalCalls = stats['total_calls'] as int? ?? 0;
          final hasAlerts = stats['has_alerts'] as bool? ?? false;

          return Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            endpoint,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasAlerts)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'ALERT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Calls: $totalCalls'),
                    Text(
                      'Error Rate: ${errorRate.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: errorRate > 5.0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (stats['avg_latency'] != null)
                      Text(
                        'Avg Latency: ${(stats['avg_latency'] as double).toStringAsFixed(0)}ms',
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrafficTable() {
    final logs = _trafficData['data'] as List? ?? [];
    final pagination =
        _trafficData['pagination'] as Map<String, dynamic>? ?? {};

    if (logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No traffic logs found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Try adjusting your filters or date range',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            // Add vertical scrolling capability
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Timestamp')),
                    DataColumn(label: Text('Endpoint')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Latency')),
                    DataColumn(label: Text('User Agent')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: logs.map<DataRow>((log) {
                    final timestamp = DateTime.parse(log['ts'] as String);
                    final status = log['status'] as int;
                    final latency = log['latency_ms'] as int? ?? 0;
                    final userAgent = log['user_agent'] as String? ?? 'Unknown';

                    Color statusColor;
                    if (status >= 200 && status < 300) {
                      statusColor = Colors.green;
                    } else if (status >= 400 && status < 500) {
                      statusColor = Colors.orange;
                    } else if (status >= 500) {
                      statusColor = Colors.red;
                    } else {
                      statusColor = Colors.grey;
                    }

                    return DataRow(
                      cells: [
                        DataCell(Text(timestamp.toString().substring(11, 19))),
                        DataCell(Text(log['endpoint'] as String)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: statusColor),
                            ),
                            child: Text(
                              status.toString(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text('${latency}ms')),
                        DataCell(
                          Text(
                            userAgent.length > 20
                                ? '${userAgent.substring(0, 20)}...'
                                : userAgent,
                          ),
                        ),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () => _showLogDetails(log),
                            tooltip: 'View Details',
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        _buildPagination(pagination),
      ],
    );
  }

  Widget _buildPagination(Map<String, dynamic> pagination) {
    final currentPage = pagination['page'] as int? ?? 1;
    final totalPages = pagination['totalPages'] as int? ?? 1;
    final total = pagination['total'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Total: $total logs'),
          Row(
            children: [
              IconButton(
                onPressed: currentPage > 1
                    ? () => _changePage(currentPage - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('Page $currentPage of $totalPages'),
              IconButton(
                onPressed: currentPage < totalPages
                    ? () => _changePage(currentPage + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _changePage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadTrafficData();
  }

  void _showLogDetails(Map<String, dynamic> log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Details - ${log['endpoint']}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogDetailSection('Basic Info', {
                  'Timestamp': log['ts'],
                  'Status': log['status'].toString(),
                  'Latency': '${log['latency_ms'] ?? 0}ms',
                  'User Agent': log['user_agent'] ?? 'Unknown',
                  'Caller IP': log['caller_ip'] ?? 'Unknown',
                }),
                const SizedBox(height: 16),
                if (log['request'] != null)
                  _buildLogDetailSection('Request', log['request']),
                const SizedBox(height: 16),
                if (log['response'] != null)
                  _buildLogDetailSection('Response', log['response']),
                const SizedBox(height: 16),
                if (log['flags'] != null)
                  _buildLogDetailSection('Feature Flags', log['flags']),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _copyLogToClipboard(log),
            child: const Text('Copy JSON'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogDetailSection(String title, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            data is Map
                ? const JsonEncoder.withIndent('  ').convert(data)
                : data.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  void _copyLogToClipboard(Map<String, dynamic> log) {
    final jsonString = const JsonEncoder.withIndent('  ').convert(log);
    Clipboard.setData(ClipboardData(text: jsonString));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Log copied to clipboard')));
  }

  Widget _buildOdooSessionMonitor() {
    final sessionData = _sessionData['data'] as List? ?? [];
    final statistics =
        _sessionData['statistics'] as Map<String, dynamic>? ?? {};
    final flags = _sessionData['flags'] as Map<String, dynamic>? ?? {};
    final userAgents =
        _sessionData['user_agents'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Success Rate',
                  '${(statistics['success_rate'] as double? ?? 0.0).toStringAsFixed(1)}%',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Attempts',
                  '${statistics['total_attempts'] ?? 0}',
                  Icons.login,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Cookie Rate',
                  '${(statistics['cookie_presence_rate'] as double? ?? 0.0).toStringAsFixed(1)}%',
                  Icons.cookie,
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Feature Flags Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Feature Flags Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...flags.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            entry.value ? Icons.check_circle : Icons.cancel,
                            color: entry.value ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(entry.key),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: entry.value
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.value ? 'ENABLED' : 'DISABLED',
                              style: TextStyle(
                                color: entry.value ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // User Agent Breakdown
          if (userAgents.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Agent Breakdown (Last 24h)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...userAgents.entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(_getUserAgentIcon(entry.key), size: 20),
                            const SizedBox(width: 8),
                            Text(entry.key),
                            const Spacer(),
                            Text(
                              '${entry.value} calls',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Recent Session Attempts
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Session Attempts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (sessionData.isEmpty)
                    const Center(
                      child: Text(
                        'No session data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Time')),
                          DataColumn(label: Text('Success')),
                          DataColumn(label: Text('Endpoint')),
                          DataColumn(label: Text('Cookie')),
                          DataColumn(label: Text('UID')),
                          DataColumn(label: Text('Failure Reason')),
                        ],
                        rows: sessionData.take(10).map<DataRow>((session) {
                          final timestamp = DateTime.parse(
                            session['attempt_timestamp'] as String,
                          );
                          final success = session['success'] as bool;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(timestamp.toString().substring(11, 19)),
                              ),
                              DataCell(
                                Icon(
                                  success ? Icons.check_circle : Icons.error,
                                  color: success ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                              ),
                              DataCell(
                                Text(
                                  session['endpoint_called'] as String? ??
                                      'Unknown',
                                ),
                              ),
                              DataCell(
                                Icon(
                                  session['set_cookie_seen']
                                      ? Icons.check
                                      : Icons.close,
                                  color: session['set_cookie_seen']
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 16,
                                ),
                              ),
                              DataCell(
                                Icon(
                                  session['uid_present']
                                      ? Icons.check
                                      : Icons.close,
                                  color: session['uid_present']
                                      ? Colors.green
                                      : Colors.grey,
                                  size: 16,
                                ),
                              ),
                              DataCell(
                                Text(
                                  session['failure_reason'] as String? ?? '-',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getUserAgentIcon(String userAgent) {
    switch (userAgent) {
      case 'Mobile App':
        return Icons.phone_android;
      case 'Admin Panel':
        return Icons.admin_panel_settings;
      case 'Webhook':
        return Icons.webhook;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductStatusTracker() {
    final events = _productData['data'] as List? ?? [];
    final productCounts =
        _productData['product_counts'] as Map<String, dynamic>? ?? {};
    final duplicates = _productData['duplicates'] as List? ?? [];
    final dryRuns = _productData['dry_runs'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Status Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  '${productCounts['pending'] ?? 0}',
                  Icons.pending,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Approved',
                  '${productCounts['approved'] ?? 0}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Rejected',
                  '${productCounts['rejected'] ?? 0}',
                  Icons.cancel,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total',
                  '${productCounts['total'] ?? 0}',
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Recent Product Events
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Product Approval Events',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (events.isEmpty)
                    const Center(
                      child: Text(
                        'No product events available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Time')),
                          DataColumn(label: Text('Event Type')),
                          DataColumn(label: Text('Source')),
                          DataColumn(label: Text('Status Change')),
                          DataColumn(label: Text('Product ID')),
                        ],
                        rows: events.take(10).map<DataRow>((event) {
                          final timestamp = DateTime.parse(
                            event['created_at'] as String,
                          );
                          final eventType = event['event_type'] as String;
                          final source = event['event_source'] as String;
                          final oldStatus = event['old_status'] as String?;
                          final newStatus = event['new_status'] as String?;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(timestamp.toString().substring(11, 19)),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getEventTypeColor(
                                      eventType,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    eventType.toUpperCase(),
                                    style: TextStyle(
                                      color: _getEventTypeColor(eventType),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(Text(source)),
                              DataCell(
                                Text(
                                  oldStatus != null && newStatus != null
                                      ? '$oldStatus → $newStatus'
                                      : '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  event['product_id']?.toString().substring(
                                        0,
                                        8,
                                      ) ??
                                      '-',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Duplicate Prevention Events
          if (duplicates.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duplicate Prevention Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Time')),
                          DataColumn(label: Text('Field')),
                          DataColumn(label: Text('Value')),
                          DataColumn(label: Text('Prevented')),
                        ],
                        rows: duplicates.take(5).map<DataRow>((duplicate) {
                          final timestamp = DateTime.parse(
                            duplicate['created_at'] as String,
                          );

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(timestamp.toString().substring(11, 19)),
                              ),
                              DataCell(
                                Text(
                                  duplicate['duplicate_check_field']
                                          as String? ??
                                      '-',
                                ),
                              ),
                              DataCell(
                                Text(
                                  duplicate['duplicate_value'] as String? ??
                                      '-',
                                ),
                              ),
                              DataCell(
                                Icon(
                                  duplicate['duplicate_prevented']
                                      ? Icons.block
                                      : Icons.check,
                                  color: duplicate['duplicate_prevented']
                                      ? Colors.red
                                      : Colors.green,
                                  size: 20,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Dry Run Events
          if (dryRuns.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dry Run Events',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...dryRuns.take(3).map((dryRun) {
                      final timestamp = DateTime.parse(
                        dryRun['created_at'] as String,
                      );
                      final dryRunData =
                          dryRun['dry_run_data'] as Map<String, dynamic>? ?? {};

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          title: Text(
                            'Dry Run - ${timestamp.toString().substring(11, 19)}',
                          ),
                          subtitle: Text('Source: ${dryRun['event_source']}'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Text(
                                  dryRunData.isNotEmpty
                                      ? const JsonEncoder.withIndent(
                                          '  ',
                                        ).convert(dryRunData)
                                      : 'No dry run data available',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getEventTypeColor(String eventType) {
    switch (eventType) {
      case 'approval':
        return Colors.green;
      case 'rejection':
        return Colors.red;
      case 'sync':
        return Colors.blue;
      case 'duplicate_check':
        return Colors.orange;
      case 'dry_run':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFeatureFlagsViewer() {
    final flags = _flagsData['data'] as Map<String, dynamic>? ?? {};
    final note = _flagsData['note'] as String?;
    final source = _flagsData['source'] as String? ?? 'unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with note if available
          if (note != null)
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: const TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Feature Flags List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Feature Flags Management',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: source == 'database'
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          source == 'database' ? 'LIVE DATA' : 'READ-ONLY',
                          style: TextStyle(
                            color: source == 'database'
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${flags.length} flags',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (flags.isEmpty)
                    const Center(
                      child: Text(
                        'No feature flags available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ...flags.entries.map((entry) {
                      final flagName = entry.key;
                      final isEnabled = entry.value as bool;
                      final canToggle =
                          source ==
                          'database'; // Only allow toggles if we have database access

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Status Icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isEnabled
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  isEnabled ? Icons.check_circle : Icons.cancel,
                                  color: isEnabled ? Colors.green : Colors.red,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Flag Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      flagName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getFlagDescription(flagName),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Toggle Switch (Phase 3) or Status Badge
                              if (canToggle)
                                Switch(
                                  value: isEnabled,
                                  onChanged: (newValue) =>
                                      _toggleFeatureFlag(flagName, newValue),
                                  activeColor: Colors.green,
                                  inactiveThumbColor: Colors.red,
                                )
                              else
                                // Status Badge (read-only)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isEnabled
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isEnabled
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  child: Text(
                                    isEnabled ? 'ENABLED' : 'DISABLED',
                                    style: TextStyle(
                                      color: isEnabled
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Phase 3 Features Notice
          Card(
            color: Colors.green[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.new_releases, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Phase 3 Features Active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '✅ Interactive feature flag toggles with real-time updates',
                    style: TextStyle(color: Colors.green),
                  ),
                  const Text(
                    '✅ Audit logging for all flag changes',
                    style: TextStyle(color: Colors.green),
                  ),
                  const Text(
                    '✅ Safety checks to prevent critical system disruption',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFlagDescription(String flagName) {
    switch (flagName) {
      case 'FORCE_V2_WEBHOOKS':
        return 'Forces all webhooks to use v2 payload format';
      case 'ENABLE_PRODUCT_DUP_CHECK':
        return 'Enables duplicate product checking by default_code';
      case 'ENABLE_AUTO_ACTIVATE_ON_APPROVAL':
        return 'Automatically activates products when approved via webhook';
      case 'AUTO_SYNC_STATUS_ON_OPEN':
        return 'Automatically syncs product status when app opens';
      case 'ENABLE_DEBUG_LOGGING':
        return 'Enables debug panel logging for edge functions';
      default:
        return 'Feature flag for system configuration';
    }
  }

  /// Toggle a feature flag (Phase 3)
  Future<void> _toggleFeatureFlag(String flagName, bool newValue) async {
    if (!mounted) return;

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Updating feature flag...'),
            ],
          ),
        ),
      );

      final flagService = FeatureFlagService();
      final result = await flagService.toggleFeatureFlag(
        flagName,
        newValue,
        changedBy: 'admin_panel',
        reason: 'Manual toggle via debug panel',
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      if (result['success']) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['changed']
                  ? 'Feature flag $flagName ${newValue ? 'enabled' : 'disabled'}'
                  : 'Feature flag already has the requested value',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the flags data
        await _loadFlagsData();
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle feature flag: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling feature flag: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
