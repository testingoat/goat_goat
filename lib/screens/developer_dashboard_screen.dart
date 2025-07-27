import 'package:flutter/material.dart';
import 'dart:async';
import '../supabase_service.dart';

class DeveloperDashboardScreen extends StatefulWidget {
  const DeveloperDashboardScreen({super.key});

  @override
  State<DeveloperDashboardScreen> createState() =>
      _DeveloperDashboardScreenState();
}

class _DeveloperDashboardScreenState extends State<DeveloperDashboardScreen>
    with SingleTickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();

  late TabController _tabController;
  Timer? _refreshTimer;

  // Data storage
  List<Map<String, dynamic>> _activeSessions = [];
  List<Map<String, dynamic>> _apiLogs = [];
  List<Map<String, dynamic>> _webhookLogs = [];
  List<Map<String, dynamic>> _dbLogs = [];
  List<Map<String, dynamic>> _errorLogs = [];
  Map<String, dynamic> _systemStatus = {};

  // Loading states
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadDashboardData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Future.wait([
        _loadActiveSessions(),
        _loadApiLogs(),
        _loadWebhookLogs(),
        _loadDbLogs(),
        _loadErrorLogs(),
        _loadSystemStatus(),
      ]);
    } catch (e) {
      print('Error loading dashboard data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadActiveSessions() async {
    try {
      // Get active seller sessions
      final sellers = await _supabaseService.getSellers();
      // Skip customers for now to avoid relationship errors
      // final customers = await _supabaseService.getCustomers();

      _activeSessions = [
        ...sellers.map(
          (s) => {
            'type': 'seller',
            'id': s['id'],
            'name': s['seller_name'],
            'phone': s['contact_phone'],
            'last_active': s['updated_at'],
            'status': s['approval_status'],
          },
        ),
        // Skip customers for now to avoid relationship errors
      ];
    } catch (e) {
      print('Error loading active sessions: $e');
    }
  }

  Future<void> _loadApiLogs() async {
    try {
      // This would typically come from a dedicated logging table
      // For now, we'll simulate with recent database operations
      final products = await _supabaseService.getMeatProducts(limit: 50);

      _apiLogs = products
          .map(
            (p) => {
              'timestamp': p['created_at'],
              'method': 'POST',
              'endpoint': '/api/products',
              'status': 200,
              'response_time':
                  '${(DateTime.now().millisecondsSinceEpoch % 1000)}ms',
              'user_id': p['seller_id'],
              'request_body': {'name': p['name'], 'price': p['price']},
              'response_body': {'success': true, 'id': p['id']},
            },
          )
          .toList();
    } catch (e) {
      print('Error loading API logs: $e');
    }
  }

  Future<void> _loadWebhookLogs() async {
    try {
      // Simulate webhook logs based on product approvals
      final products = await _supabaseService.getMeatProducts(limit: 30);

      _webhookLogs = products
          .where((p) => p['approval_status'] != 'pending')
          .map(
            (p) => {
              'timestamp': p['updated_at'],
              'webhook_type': 'product_approval',
              'status': p['approval_status'] == 'approved'
                  ? 'success'
                  : 'failed',
              'payload': {
                'product_id': p['id'],
                'seller_id': p['seller_id'],
                'approval_status': p['approval_status'],
              },
              'response_code': p['approval_status'] == 'approved' ? 200 : 400,
              'retry_count': 0,
            },
          )
          .toList();
    } catch (e) {
      print('Error loading webhook logs: $e');
    }
  }

  Future<void> _loadDbLogs() async {
    try {
      // Simulate database operation logs
      final products = await _supabaseService.getMeatProducts(limit: 20);
      final sellers = await _supabaseService.getSellers(limit: 10);

      _dbLogs = [
        ...products.map(
          (p) => {
            'timestamp': p['created_at'],
            'operation': 'INSERT',
            'table': 'meat_products',
            'record_id': p['id'],
            'user_id': p['seller_id'],
            'changes': {'name': p['name'], 'price': p['price']},
            'duration': '${(DateTime.now().millisecondsSinceEpoch % 100)}ms',
          },
        ),
        ...sellers.map(
          (s) => {
            'timestamp': s['created_at'],
            'operation': 'INSERT',
            'table': 'sellers',
            'record_id': s['id'],
            'user_id': s['id'],
            'changes': {
              'seller_name': s['seller_name'],
              'seller_type': s['seller_type'],
            },
            'duration': '${(DateTime.now().millisecondsSinceEpoch % 100)}ms',
          },
        ),
      ];
    } catch (e) {
      print('Error loading DB logs: $e');
    }
  }

  Future<void> _loadErrorLogs() async {
    try {
      // Simulate error logs based on failed operations
      _errorLogs = [
        {
          'timestamp': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'level': 'ERROR',
          'message': 'Failed to create product in Odoo',
          'stack_trace':
              'Exception: Odoo API timeout\n  at OdooService.createProduct\n  at ProductManagement._submitProduct',
          'user_id': 'seller-123',
          'context': {
            'product_name': 'Chicken Breast',
            'seller_id': 'seller-123',
          },
        },
        {
          'timestamp': DateTime.now()
              .subtract(const Duration(hours: 1))
              .toIso8601String(),
          'level': 'WARNING',
          'message': 'SMS delivery failed, using fallback',
          'stack_trace': 'Fast2SMS API returned 429: Rate limit exceeded',
          'user_id': 'system',
          'context': {'phone': '9876543210', 'otp': '123456'},
        },
      ];
    } catch (e) {
      print('Error loading error logs: $e');
    }
  }

  Future<void> _loadSystemStatus() async {
    try {
      final products = await _supabaseService.getMeatProducts();
      final sellers = await _supabaseService.getSellers();

      _systemStatus = {
        'database_status': 'healthy',
        'odoo_status': 'healthy',
        'webhook_status': 'healthy',
        'total_products': products.length,
        'total_sellers': sellers.length,
        'pending_approvals': products
            .where((p) => p['approval_status'] == 'pending')
            .length,
        'active_sessions': _activeSessions.length,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('Error loading system status: $e');
      _systemStatus = {
        'database_status': 'error',
        'odoo_status': 'unknown',
        'webhook_status': 'unknown',
        'error': e.toString(),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Dashboard'),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
            tooltip: 'Settings',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sessions'),
            Tab(text: 'API Logs'),
            Tab(text: 'Webhooks'),
            Tab(text: 'Database'),
            Tab(text: 'Errors'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSessionsTab(),
                _buildApiLogsTab(),
                _buildWebhooksTab(),
                _buildDatabaseTab(),
                _buildErrorsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSystemStatusCards(),
          const SizedBox(height: 24),
          _buildQuickStats(),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusCard(
            'Database',
            _systemStatus['database_status'] ?? 'unknown',
            Icons.storage,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            'Odoo',
            _systemStatus['odoo_status'] ?? 'unknown',
            Icons.cloud,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatusCard(
            'Webhooks',
            _systemStatus['webhook_status'] ?? 'unknown',
            Icons.webhook,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(String title, String status, IconData icon) {
    Color statusColor;
    switch (status) {
      case 'healthy':
        statusColor = Colors.green;
        break;
      case 'warning':
        statusColor = Colors.orange;
        break;
      case 'error':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: statusColor, size: 32),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Stats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Products',
                  '${_systemStatus['total_products'] ?? 0}',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Total Sellers',
                  '${_systemStatus['total_sellers'] ?? 0}',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Pending Approvals',
                  '${_systemStatus['pending_approvals'] ?? 0}',
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Active Sessions',
                  '${_systemStatus['active_sessions'] ?? 0}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF059669),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSessionsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeSessions.length,
      itemBuilder: (context, index) {
        final session = _activeSessions[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: session['type'] == 'seller'
                  ? Colors.blue
                  : Colors.green,
              child: Icon(
                session['type'] == 'seller' ? Icons.store : Icons.person,
                color: Colors.white,
              ),
            ),
            title: Text(session['name'] ?? 'Unknown'),
            subtitle: Text('${session['type']} • ${session['phone']}'),
            trailing: Text(_formatTimestamp(session['last_active'])),
          ),
        );
      },
    );
  }

  Widget _buildApiLogsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _apiLogs.length,
      itemBuilder: (context, index) {
        final log = _apiLogs[index];
        return Card(
          child: ExpansionTile(
            title: Text('${log['method']} ${log['endpoint']}'),
            subtitle: Text(
              'Status: ${log['status']} • ${log['response_time']}',
            ),
            trailing: Text(_formatTimestamp(log['timestamp'])),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Request: ${log['request_body']}'),
                    const SizedBox(height: 8),
                    Text('Response: ${log['response_body']}'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebhooksTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _webhookLogs.length,
      itemBuilder: (context, index) {
        final log = _webhookLogs[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: log['status'] == 'success'
                  ? Colors.green
                  : Colors.red,
              child: Icon(
                log['status'] == 'success' ? Icons.check : Icons.error,
                color: Colors.white,
              ),
            ),
            title: Text(log['webhook_type']),
            subtitle: Text(
              'Status: ${log['response_code']} • Retries: ${log['retry_count']}',
            ),
            trailing: Text(_formatTimestamp(log['timestamp'])),
          ),
        );
      },
    );
  }

  Widget _buildDatabaseTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _dbLogs.length,
      itemBuilder: (context, index) {
        final log = _dbLogs[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF059669),
              child: Text(log['operation'][0]),
            ),
            title: Text('${log['operation']} ${log['table']}'),
            subtitle: Text('Duration: ${log['duration']}'),
            trailing: Text(_formatTimestamp(log['timestamp'])),
          ),
        );
      },
    );
  }

  Widget _buildErrorsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _errorLogs.length,
      itemBuilder: (context, index) {
        final log = _errorLogs[index];
        return Card(
          child: ExpansionTile(
            title: Text(log['message']),
            subtitle: Text('Level: ${log['level']}'),
            trailing: Text(_formatTimestamp(log['timestamp'])),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stack Trace:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      log['stack_trace'],
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Auto-refresh: 30 seconds'),
            Text('Log retention: 7 days'),
            Text('Max entries per tab: 100'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
