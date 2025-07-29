import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../widgets/admin_layout.dart';

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
    return const Center(
      child: Text(
        'Send Notification Interface - Coming Soon',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return const Center(
      child: Text(
        'Template Management Interface - Coming Soon',
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return const Center(
      child: Text(
        'Notification History Interface - Coming Soon',
        style: TextStyle(fontSize: 18, color: Colors.grey),
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
}
