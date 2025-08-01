import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/admin_layout.dart';
import '../widgets/notification_template_editor.dart';

/// Notifications Management Screen for Admin Panel
///
/// Features:
/// - Notification dashboard with statistics
/// - Template management interface
/// - Bulk notification sending
/// - Recent notifications history
/// - Zero-risk implementation with feature flags
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();

  late TabController _tabController;

  // State variables
  Map<String, dynamic>? _analytics;
  List<Map<String, dynamic>> _recentNotifications = [];
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;
  String? _error;

  // History filtering state
  String _historyTypeFilter = 'all';
  String _historyStatusFilter = 'all';
  List<Map<String, dynamic>> _filteredNotifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load analytics, recent notifications, and templates in parallel
      final results = await Future.wait([
        _notificationService.getNotificationAnalytics(),
        _notificationService.getRecentNotifications(limit: 10),
        _notificationService.getNotificationTemplates(),
      ]);

      setState(() {
        if (results[0]['success']) {
          _analytics = results[0]['analytics'];
        }
        if (results[1]['success']) {
          _recentNotifications = List<Map<String, dynamic>>.from(
            results[1]['notifications'],
          );
          _applyHistoryFilters();
        }
        if (results[2]['success']) {
          _templates = List<Map<String, dynamic>>.from(results[2]['templates']);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
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
                Icon(Icons.notifications, size: 32, color: Colors.green[600]),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications Management',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                    ),
                    Text(
                      'Manage SMS notifications and templates',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'PHASE 1.3A',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.green[600],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.green[600],
              tabs: const [
                Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
                Tab(icon: Icon(Icons.send), text: 'Send Notification'),
                Tab(icon: Icon(Icons.description), text: 'Templates'),
                Tab(icon: Icon(Icons.history), text: 'History'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _buildErrorWidget()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDashboardTab(),
                      _buildSendNotificationTab(),
                      _buildTemplatesTab(),
                      _buildHistoryTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.red[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error occurred',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistics Cards
          if (_analytics != null) _buildStatisticsCards(),

          const SizedBox(height: 24),

          // Quick Actions
          _buildQuickActions(),

          const SizedBox(height: 24),

          // Recent Notifications
          _buildRecentNotifications(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final stats = _analytics!;

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Sent',
          stats['total_sent'].toString(),
          Icons.send,
          Colors.blue,
        ),
        _buildStatCard(
          'Delivered',
          stats['total_delivered'].toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Failed',
          stats['total_failed'].toString(),
          Icons.error,
          Colors.red,
        ),
        _buildStatCard(
          'Delivery Rate',
          '${stats['delivery_rate'].toStringAsFixed(1)}%',
          Icons.trending_up,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Send Custom SMS',
                  Icons.message,
                  Colors.blue,
                  () => _tabController.animateTo(1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  'Manage Templates',
                  Icons.description,
                  Colors.green,
                  () => _tabController.animateTo(2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  'View Analytics',
                  Icons.analytics,
                  Colors.orange,
                  () => _showAnalyticsDialog(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  'Bulk Operations',
                  Icons.group,
                  Colors.purple,
                  () => _showBulkOperationsDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentNotifications() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Notifications',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              TextButton(
                onPressed: () => _tabController.animateTo(3),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentNotifications.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No notifications sent yet',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentNotifications.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final notification = _recentNotifications[index];
                return _buildNotificationListItem(notification);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationListItem(Map<String, dynamic> notification) {
    final status = notification['delivery_status'] as String;
    final type = notification['notification_type'] as String;
    final title = notification['title'] as String;
    final createdAt = DateTime.parse(notification['created_at']);

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'sent':
      case 'delivered':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor, size: 20),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${type.toUpperCase()} • ${_formatDateTime(createdAt)}',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            color: statusColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSendNotificationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.send, color: Colors.green[700], size: 28),
              const SizedBox(width: 12),
              Text(
                'Send Notification',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Send Cards
          Row(
            children: [
              Expanded(
                child: _buildQuickSendCard(
                  'SMS Notification',
                  'Send SMS to customers/sellers',
                  Icons.sms,
                  Colors.blue,
                  () => _showSMSNotificationDialog(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickSendCard(
                  'Push Notification',
                  'Send push notification via FCM',
                  Icons.notifications,
                  Colors.orange,
                  () => _showPushNotificationDialog(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickSendCard(
                  'Combined Notification',
                  'Send both SMS and push notification',
                  Icons.campaign,
                  Colors.purple,
                  () => _showCombinedNotificationDialog(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildQuickSendCard(
                  'Template-Based',
                  'Use existing templates',
                  Icons.description,
                  Colors.green,
                  () => _showTemplateNotificationDialog(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Recent Notifications
          _buildRecentNotificationsSection(),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Create Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: Colors.green[700], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Notification Templates',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateTemplateDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Create Template'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Templates List
          if (_templates.isEmpty)
            _buildEmptyTemplatesState()
          else
            _buildTemplatesList(),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.history, color: Colors.green[700], size: 28),
              const SizedBox(width: 12),
              Text(
                'Notification History',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Types')),
                    DropdownMenuItem(value: 'sms', child: Text('SMS Only')),
                    DropdownMenuItem(value: 'push', child: Text('Push Only')),
                    DropdownMenuItem(
                      value: 'combined',
                      child: Text('Combined'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _historyTypeFilter = value ?? 'all';
                      _applyHistoryFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Status')),
                    DropdownMenuItem(value: 'sent', child: Text('Sent')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _historyStatusFilter = value ?? 'all';
                      _applyHistoryFilters();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // History List
          if (_filteredNotifications.isEmpty)
            _buildEmptyHistoryState()
          else
            _buildHistoryList(),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showAnalyticsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detailed Analytics'),
        content: const Text(
          'Advanced analytics interface coming soon in Phase 1.3B',
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

  void _showBulkOperationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Operations'),
        content: const Text('Bulk notification sending interface coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ===== SEND NOTIFICATION METHODS =====

  Widget _buildQuickSendCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentNotificationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Notifications',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_recentNotifications.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Center(
              child: Text(
                'No recent notifications',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentNotifications.length.clamp(0, 5),
            itemBuilder: (context, index) {
              final notification = _recentNotifications[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.notifications, color: Colors.green[700]),
                  ),
                  title: Text(notification['title'] ?? 'Notification'),
                  subtitle: Text(notification['message'] ?? ''),
                  trailing: Text(
                    _formatDateTime(
                      DateTime.parse(
                        notification['created_at'] ??
                            DateTime.now().toIso8601String(),
                      ),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _showSMSNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => _SMSNotificationDialog(
        notificationService: _notificationService,
        onSent: () {
          _loadData(); // Refresh data after sending
        },
      ),
    );
  }

  void _showPushNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => _PushNotificationDialog(
        notificationService: _notificationService,
        onSent: () {
          _loadData(); // Refresh data after sending
        },
      ),
    );
  }

  void _showCombinedNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Combined Notification'),
        content: const SizedBox(
          width: 400,
          child: Text(
            'Combined SMS + Push notification interface will be implemented here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement combined notification sending
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showTemplateNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Template-Based Notification'),
        content: const SizedBox(
          width: 400,
          child: Text(
            'Template-based notification interface will be implemented here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement template-based sending
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  // ===== TEMPLATE MANAGEMENT METHODS =====

  Widget _buildEmptyTemplatesState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(Icons.description, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Templates Found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first notification template to get started',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateTemplateDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create Template'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _templates.length,
      itemBuilder: (context, index) {
        final template = _templates[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: template['is_active'] == true
                  ? Colors.green[100]
                  : Colors.grey[100],
              child: Icon(
                Icons.description,
                color: template['is_active'] == true
                    ? Colors.green[700]
                    : Colors.grey[600],
              ),
            ),
            title: Text(
              template['template_name'] ?? 'Unnamed Template',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template['title_template'] ?? ''),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        template['template_type'] ?? 'custom',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (template['is_active'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green[700],
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'use',
                  child: Row(
                    children: [
                      Icon(Icons.send, size: 16),
                      SizedBox(width: 8),
                      Text('Use Template'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) =>
                  _handleTemplateAction(value.toString(), template),
            ),
          ),
        );
      },
    );
  }

  void _showCreateTemplateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 800,
          height: 700,
          child: NotificationTemplateEditor(
            onSaved: () {
              Navigator.of(context).pop();
              _loadData(); // Refresh the templates list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Template created successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            onCancelled: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _handleTemplateAction(String action, Map<String, dynamic> template) {
    switch (action) {
      case 'edit':
        _showEditTemplateDialog(template);
        break;
      case 'use':
        _showUseTemplateDialog(template);
        break;
      case 'delete':
        _showDeleteTemplateDialog(template);
        break;
    }
  }

  void _showEditTemplateDialog(Map<String, dynamic> template) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: SizedBox(
          width: 800,
          height: 700,
          child: NotificationTemplateEditor(
            template: template,
            onSaved: () {
              Navigator.of(context).pop();
              _loadData(); // Refresh the templates list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Template updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            onCancelled: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  void _showUseTemplateDialog(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Template'),
        content: Text('Send notification using: ${template['template_name']}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement template usage
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showDeleteTemplateDialog(Map<String, dynamic> template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text(
          'Are you sure you want to delete "${template['template_name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement template deletion
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ===== HISTORY METHODS =====

  Widget _buildEmptyHistoryState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Notification History',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Notification history will appear here once you start sending notifications',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = _filteredNotifications[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getNotificationStatusColor(
                notification['status'],
              ),
              child: Icon(
                _getNotificationIcon(notification['type']),
                color: Colors.white,
                size: 20,
              ),
            ),
            title: Text(
              notification['title'] ?? 'Notification',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification['message'] ?? ''),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notification['type'] ?? 'unknown',
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getNotificationStatusColor(
                          notification['status'],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notification['status'] ?? 'unknown',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Text(
              _formatDateTime(
                DateTime.parse(
                  notification['created_at'] ??
                      DateTime.now().toIso8601String(),
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (notification['recipient_count'] != null) ...[
                      Text('Recipients: ${notification['recipient_count']}'),
                      const SizedBox(height: 8),
                    ],
                    if (notification['template_used'] != null) ...[
                      Text('Template: ${notification['template_used']}'),
                      const SizedBox(height: 8),
                    ],
                    if (notification['delivery_method'] != null) ...[
                      Text('Delivery: ${notification['delivery_method']}'),
                      const SizedBox(height: 8),
                    ],
                    Text('Sent by: ${notification['admin_name'] ?? 'Unknown'}'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getNotificationStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'sms':
        return Icons.sms;
      case 'push':
        return Icons.notifications;
      case 'combined':
        return Icons.campaign;
      default:
        return Icons.notification_important;
    }
  }

  /// Apply filters to notification history
  void _applyHistoryFilters() {
    _filteredNotifications = _recentNotifications.where((notification) {
      // Filter by type
      if (_historyTypeFilter != 'all') {
        final deliveryMethod = notification['delivery_method'] as String?;
        if (_historyTypeFilter == 'sms' && deliveryMethod != 'sms') {
          return false;
        }
        if (_historyTypeFilter == 'push' && deliveryMethod != 'push') {
          return false;
        }
        if (_historyTypeFilter == 'combined' &&
            (deliveryMethod != 'sms' && deliveryMethod != 'push')) {
          return false;
        }
      }

      // Filter by status
      if (_historyStatusFilter != 'all') {
        final status = notification['delivery_status'] as String?;
        if (status != _historyStatusFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }
}

// ===== NOTIFICATION DIALOG WIDGETS =====

/// SMS Notification Dialog Widget
class _SMSNotificationDialog extends StatefulWidget {
  final NotificationService notificationService;
  final VoidCallback onSent;

  const _SMSNotificationDialog({
    required this.notificationService,
    required this.onSent,
  });

  @override
  State<_SMSNotificationDialog> createState() => _SMSNotificationDialogState();
}

class _SMSNotificationDialogState extends State<_SMSNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _recipientController = TextEditingController();

  String _recipientType = 'all';
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send SMS Notification'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recipient Type Selection
              DropdownButtonFormField<String>(
                value: _recipientType,
                decoration: const InputDecoration(
                  labelText: 'Send To',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Users')),
                  DropdownMenuItem(
                    value: 'customers',
                    child: Text('All Customers'),
                  ),
                  DropdownMenuItem(
                    value: 'sellers',
                    child: Text('All Sellers'),
                  ),
                  DropdownMenuItem(
                    value: 'specific',
                    child: Text('Specific Phone Number'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _recipientType = value ?? 'all'),
              ),

              const SizedBox(height: 16),

              // Specific recipient input
              if (_recipientType == 'specific')
                TextFormField(
                  controller: _recipientController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '+91XXXXXXXXXX',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_recipientType == 'specific' &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter a phone number';
                    }
                    return null;
                  },
                ),

              if (_recipientType == 'specific') const SizedBox(height: 16),

              // Message Input
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'Enter your SMS message here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                maxLength: 160,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendSMSNotification,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send SMS'),
        ),
      ],
    );
  }

  Future<void> _sendSMSNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;

      if (_recipientType == 'specific') {
        // Send to specific phone number
        result = await widget.notificationService.sendSMSNotification(
          recipientId: _recipientController.text.trim(),
          recipientType: 'phone',
          templateId: 'custom_sms',
          variables: {'message': _messageController.text.trim()},
          customMessage: _messageController.text.trim(),
        );
      } else {
        // Send to all users of specified type - create recipient list
        final recipients = <Map<String, String>>[];

        // For now, we'll use a placeholder approach
        // In a real implementation, you'd fetch actual user IDs from the database
        recipients.add({
          'id': 'bulk_${_recipientType}',
          'type': _recipientType,
        });

        result = await widget.notificationService.sendBulkSMSNotification(
          recipients: recipients,
          templateId: 'custom_sms',
          variables: {'message': _messageController.text.trim()},
          customMessage: _messageController.text.trim(),
        );
      }

      if (!mounted) return;

      if (result['success']) {
        Navigator.of(context).pop();
        widget.onSent();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ SMS notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to send SMS: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error sending SMS: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

/// Push Notification Dialog Widget
class _PushNotificationDialog extends StatefulWidget {
  final NotificationService notificationService;
  final VoidCallback onSent;

  const _PushNotificationDialog({
    required this.notificationService,
    required this.onSent,
  });

  @override
  State<_PushNotificationDialog> createState() =>
      _PushNotificationDialogState();
}

class _PushNotificationDialogState extends State<_PushNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _userIdController = TextEditingController();
  final _deepLinkController = TextEditingController();

  String _targetType = 'all';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _userIdController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Push Notification'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Target Selection
                DropdownButtonFormField<String>(
                  value: _targetType,
                  decoration: const InputDecoration(
                    labelText: 'Send To',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(
                      value: 'customers',
                      child: Text('All Customers'),
                    ),
                    DropdownMenuItem(
                      value: 'sellers',
                      child: Text('All Sellers'),
                    ),
                    DropdownMenuItem(
                      value: 'specific',
                      child: Text('Specific User'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _targetType = value ?? 'all'),
                ),

                const SizedBox(height: 16),

                // Specific user input
                if (_targetType == 'specific')
                  TextFormField(
                    controller: _userIdController,
                    decoration: const InputDecoration(
                      labelText: 'User ID or Phone Number',
                      hintText: 'Enter user ID or phone number',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_targetType == 'specific' &&
                          (value == null || value.isEmpty)) {
                        return 'Please enter a user ID or phone number';
                      }
                      return null;
                    },
                  ),

                if (_targetType == 'specific') const SizedBox(height: 16),

                // Title Input
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Notification Title',
                    hintText: 'Enter notification title...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Message Input
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter your push notification message...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a message';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Deep Link Input
                TextFormField(
                  controller: _deepLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Deep Link URL (Optional)',
                    hintText: '/product/123 or /orders',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _sendPushNotification,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Push'),
        ),
      ],
    );
  }

  Future<void> _sendPushNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> result;

      if (_targetType == 'specific') {
        // Send to specific user
        result = await widget.notificationService.sendTargetedPushNotification(
          title: _titleController.text.trim(),
          body: _messageController.text.trim(),
          targetUserId: _userIdController.text.trim(),
          targetUserType:
              'customer', // Default to customer, could be made configurable
          deepLinkUrl: _deepLinkController.text.trim().isNotEmpty
              ? _deepLinkController.text.trim()
              : null,
        );
      } else {
        // Send to topic (all users, customers, or sellers)
        String topic = _targetType == 'all' ? 'all_users' : _targetType;

        result = await widget.notificationService.sendTopicPushNotification(
          title: _titleController.text.trim(),
          body: _messageController.text.trim(),
          topic: topic,
          deepLinkUrl: _deepLinkController.text.trim().isNotEmpty
              ? _deepLinkController.text.trim()
              : null,
        );
      }

      if (!mounted) return;

      if (result['success']) {
        Navigator.of(context).pop();
        widget.onSent();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Push notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Failed to send push notification: ${result['message']}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error sending push notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
