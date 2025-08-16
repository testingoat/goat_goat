import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/oms_configuration_service.dart';

/// Order Management System Screen
///
/// This screen provides comprehensive controls for the Order Management System (OMS)
/// including routing algorithms, timer settings, capacity management, and notifications.
///
/// Moved from Debug Panel to main admin navigation for better accessibility.
class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  Map<String, dynamic> _omsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOMSData();
  }

  /// Load OMS configuration data
  Future<void> _loadOMSData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('🔧 ORDER_MANAGEMENT - Loading OMS configuration data');
      }

      final omsService = OMSConfigurationService();
      final result = await omsService.getAllConfigurations();

      if (mounted) {
        setState(() {
          _omsData = result;
          _isLoading = false;
        });
      }

      if (kDebugMode) {
        print('✅ ORDER_MANAGEMENT - OMS data loaded: ${result['success']}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ORDER_MANAGEMENT - Error loading OMS data: $e');
      }
      if (mounted) {
        setState(() {
          _omsData = {'success': false, 'error': e.toString()};
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (!_omsData.containsKey('success')) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_omsData['success'] != true) {
      return _buildErrorState();
    }

    final configurations =
        _omsData['configurations'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOMSHeader(),
          const SizedBox(height: 32),
          _buildOMSConfigurationSections(configurations),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            Text(
              'OMS Configuration Not Available',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[800],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The Order Management System database tables have not been created yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Setup Required',
                        style: TextStyle(
                          color: Colors.blue[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To enable the Order Management System:\n'
                    '1. Run the database migration script\n'
                    '2. Enable the "oms_admin_panel" feature flag\n'
                    '3. Refresh this page',
                    style: TextStyle(color: Colors.blue[700], fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _loadOMSData(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // Show migration instructions
                    _showMigrationInstructions();
                  },
                  icon: const Icon(Icons.help_outline),
                  label: const Text('Setup Guide'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMigrationInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OMS Setup Instructions'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To set up the Order Management System, follow these steps:',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              _buildInstructionStep(
                '1',
                'Database Migration',
                'Run the comprehensive order management migration script located in:\n'
                    'database_migrations/phase_1_comprehensive_order_management_schema.sql',
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                '2',
                'Feature Flag',
                'Enable the "oms_admin_panel" feature flag in the Debug Panel > Feature Flags tab',
              ),
              const SizedBox(height: 12),
              _buildInstructionStep(
                '3',
                'Refresh',
                'Return to this page and click the Retry button to load the OMS configuration',
              ),
            ],
          ),
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

  Widget _buildInstructionStep(
    String number,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.green[600],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build OMS header with overview
  Widget _buildOMSHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.settings_applications,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Management System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Comprehensive controls for order routing, timers, capacity management, and notifications',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _loadOMSData(),
            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
            tooltip: 'Refresh OMS Configuration',
          ),
        ],
      ),
    );
  }

  /// Build OMS configuration sections
  Widget _buildOMSConfigurationSections(Map<String, dynamic> configurations) {
    // Group configurations by type
    final routingConfigs = <String, dynamic>{};
    final timerConfigs = <String, dynamic>{};
    final capacityConfigs = <String, dynamic>{};
    final notificationConfigs = <String, dynamic>{};

    for (final entry in configurations.entries) {
      final config = entry.value as Map<String, dynamic>;
      final type = config['type'] as String? ?? 'general';

      switch (type) {
        case 'routing':
          routingConfigs[entry.key] = config;
          break;
        case 'timer':
          timerConfigs[entry.key] = config;
          break;
        case 'capacity':
          capacityConfigs[entry.key] = config;
          break;
        case 'notification':
          notificationConfigs[entry.key] = config;
          break;
      }
    }

    return Column(
      children: [
        _buildOMSConfigSection(
          'Routing Algorithm',
          Icons.route,
          Colors.blue,
          routingConfigs,
        ),
        const SizedBox(height: 20),
        _buildOMSConfigSection(
          'Timer Settings',
          Icons.timer,
          Colors.orange,
          timerConfigs,
        ),
        const SizedBox(height: 20),
        _buildOMSConfigSection(
          'Capacity Management',
          Icons.inventory,
          Colors.purple,
          capacityConfigs,
        ),
        const SizedBox(height: 20),
        _buildOMSConfigSection(
          'Notifications',
          Icons.notifications,
          Colors.teal,
          notificationConfigs,
        ),
      ],
    );
  }

  /// Build individual OMS configuration section
  Widget _buildOMSConfigSection(
    String title,
    IconData icon,
    MaterialColor color,
    Map<String, dynamic> configs,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color[600], size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color[800],
                  ),
                ),
                const Spacer(),
                Text(
                  '${configs.length} settings',
                  style: TextStyle(fontSize: 14, color: color[600]),
                ),
              ],
            ),
          ),
          // Configuration items
          if (configs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $title configurations available',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            )
          else
            ...configs.entries.map(
              (entry) => _buildConfigItem(entry.key, entry.value),
            ),
        ],
      ),
    );
  }

  /// Build individual configuration item
  Widget _buildConfigItem(String key, Map<String, dynamic> config) {
    final value = config['value'];
    final description =
        config['description'] as String? ?? 'No description available';
    final type = config['data_type'] as String? ?? 'string';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildConfigValueWidget(key, value, type),
        ],
      ),
    );
  }

  /// Build configuration value widget based on type
  Widget _buildConfigValueWidget(String key, dynamic value, String type) {
    switch (type) {
      case 'boolean':
        return Switch(
          value: value == true,
          onChanged: (newValue) => _updateConfiguration(key, newValue),
          activeColor: Colors.green[600],
        );
      case 'integer':
        return SizedBox(
          width: 100,
          child: TextFormField(
            initialValue: value?.toString() ?? '0',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onFieldSubmitted: (newValue) {
              final intValue = int.tryParse(newValue);
              if (intValue != null) {
                _updateConfiguration(key, intValue);
              }
            },
          ),
        );
      case 'decimal':
        return SizedBox(
          width: 100,
          child: TextFormField(
            initialValue: value?.toString() ?? '0.0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            onFieldSubmitted: (newValue) {
              final doubleValue = double.tryParse(newValue);
              if (doubleValue != null) {
                _updateConfiguration(key, doubleValue);
              }
            },
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value?.toString() ?? 'Not set',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        );
    }
  }

  /// Update configuration value
  Future<void> _updateConfiguration(String key, dynamic value) async {
    try {
      final omsService = OMSConfigurationService();
      final result = await omsService.updateConfiguration(
        configKey: key,
        configValue: {'value': value},
        updatedBy: 'admin_panel',
        reason: 'Updated via admin panel',
      );

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated $key successfully'),
            backgroundColor: Colors.green[600],
          ),
        );
        // Reload data to reflect changes
        _loadOMSData();
      } else {
        throw Exception(result['error'] ?? 'Update failed');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update $key: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }
}
