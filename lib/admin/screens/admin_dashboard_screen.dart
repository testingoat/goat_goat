import 'package:flutter/material.dart';
import '../services/admin_auth_service.dart';
import '../utils/admin_constants.dart';
import 'admin_login_screen.dart';
import 'product_reviews_screen.dart';
import 'delivery_fee_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminAuthService _authService = AdminAuthService();
  int _selectedIndex = 0;

  final List<AdminMenuItem> _menuItems = [
    AdminMenuItem(
      icon: Icons.dashboard,
      title: 'Dashboard',
      permission: null, // Always accessible
    ),
    AdminMenuItem(
      icon: Icons.rate_review,
      title: 'Review Moderation',
      permission: 'review_moderation',
    ),
    AdminMenuItem(
      icon: Icons.notifications,
      title: 'Notifications',
      permission: 'notification_management',
    ),
    AdminMenuItem(
      icon: Icons.people,
      title: 'User Management',
      permission: 'user_management',
    ),
    AdminMenuItem(
      icon: Icons.analytics,
      title: 'Analytics',
      permission: 'analytics_access',
    ),
    AdminMenuItem(
      icon: Icons.attach_money,
      title: 'Pricing',
      permission: 'pricing_management',
    ),
    AdminMenuItem(
      icon: Icons.settings,
      title: 'System Admin',
      permission: 'system_administration',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
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
                      Icon(
                        Icons.admin_panel_settings,
                        size: 48,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AdminConstants.adminPanelTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'v${AdminConstants.adminPanelVersion}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Admin info
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green[100],
                        child: Icon(Icons.person, color: Colors.green[600]),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _authService.currentAdmin?['full_name'] ??
                                  'Admin User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _authService.currentAdmin?['role'] ?? 'admin',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Menu items
                Expanded(
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final item = _menuItems[index];
                      final hasPermission =
                          item.permission == null ||
                          _authService.hasPermission(item.permission!);

                      if (!hasPermission) return const SizedBox.shrink();

                      return ListTile(
                        leading: Icon(
                          item.icon,
                          color: _selectedIndex == index
                              ? Colors.green[600]
                              : Colors.grey[600],
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            color: _selectedIndex == index
                                ? Colors.green[600]
                                : Colors.grey[800],
                            fontWeight: _selectedIndex == index
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: _selectedIndex == index,
                        selectedTileColor: Colors.green[50],
                        onTap: () {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                      );
                    },
                  ),
                ),

                const Divider(),

                // Logout button
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.red[600]),
                  title: Text(
                    'Logout',
                    style: TextStyle(color: Colors.red[600]),
                  ),
                  onTap: _handleLogout,
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: Column(
              children: [
                // Top bar
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _menuItems[_selectedIndex].title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),

                      // Environment indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AdminConstants.isDevelopment
                              ? Colors.orange[100]
                              : Colors.green[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          AdminConstants.isDevelopment
                              ? 'DEVELOPMENT'
                              : 'PRODUCTION',
                          style: TextStyle(
                            color: AdminConstants.isDevelopment
                                ? Colors.orange[800]
                                : Colors.green[800],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content area
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return _buildReviewModerationContent();
      case 2:
        return _buildNotificationsContent();
      case 3:
        return _buildUserManagementContent();
      case 4:
        return _buildAnalyticsContent();
      case 5:
        return _buildPricingContent();
      case 6:
        return _buildSystemAdminContent();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome to Goat Goat Admin Panel',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),

          // Quick stats cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  '1,234',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Pending Reviews',
                  '45',
                  Icons.rate_review,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Active Orders',
                  '89',
                  Icons.shopping_cart,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'System Health',
                  '98%',
                  Icons.health_and_safety,
                  Colors.purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Development info
          if (AdminConstants.isDevelopment)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Development Mode Active',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are running the admin panel in development mode. '
                    'All features are available for testing, and data is connected '
                    'to the same Supabase backend as the mobile app.',
                    style: TextStyle(color: Colors.blue[600]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildReviewModerationContent() {
    return const ProductReviewsScreen();
  }

  Widget _buildNotificationsContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Notifications Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Coming Soon - Temporarily disabled for web deployment',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildUserManagementContent() {
    return const Center(child: Text('User Management - Coming Soon'));
  }

  Widget _buildAnalyticsContent() {
    return const Center(child: Text('Analytics - Coming Soon'));
  }

  Widget _buildPricingContent() {
    return const DeliveryFeeListScreen();
  }

  Widget _buildSystemAdminContent() {
    return const Center(child: Text('System Administration - Coming Soon'));
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
        );
      }
    }
  }
}

class AdminMenuItem {
  final IconData icon;
  final String title;
  final String? permission;

  AdminMenuItem({required this.icon, required this.title, this.permission});
}
