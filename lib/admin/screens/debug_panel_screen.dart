import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../services/debug_panel_service.dart';

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
    final result = await _debugService.getEdgeFunctionLogs(
      page: _currentPage,
      limit: _pageSize,
      endpoint: _selectedEndpoint,
      statusCode: _selectedStatusCode,
      startDate: _startDate,
      endDate: _endDate,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
    );

    if (result['success']) {
      setState(() {
        _trafficData = result;
      });
    }

    // Also load endpoint statistics
    final statsResult = await _debugService.getEndpointStatistics();
    if (statsResult['success']) {
      setState(() {
        _trafficData['statistics'] = statsResult['data'];
      });
    }
  }

  Future<void> _loadSessionData() async {
    final sessionResult = await _debugService.getOdooSessionLogs();
    final flagsResult = await _debugService.getFeatureFlagStates();
    final userAgentResult = await _debugService.getUserAgentBreakdown();

    if (sessionResult['success']) {
      setState(() {
        _sessionData = sessionResult;
      });
    }

    if (flagsResult['success']) {
      setState(() {
        _sessionData['flags'] = flagsResult['data'];
      });
    }

    if (userAgentResult['success']) {
      setState(() {
        _sessionData['user_agents'] = userAgentResult['data'];
      });
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
            color: Colors.grey.withOpacity(0.1),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: statusColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Text(
            'System Status: ${status.toUpperCase()}',
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
            scrollDirection: Axis.horizontal,
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
    return const Center(child: Text('Odoo Session Monitor - Coming Soon'));
  }

  Widget _buildProductStatusTracker() {
    return const Center(child: Text('Product Status Tracker - Coming Soon'));
  }

  Widget _buildFeatureFlagsViewer() {
    return const Center(child: Text('Feature Flags Viewer - Coming Soon'));
  }
}
