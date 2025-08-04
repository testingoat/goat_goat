import 'package:flutter/material.dart';
import '../../models/delivery_fee_config.dart';
import '../../services/admin_delivery_config_service.dart';
import '../../config/maps_config.dart';
import '../widgets/admin_layout.dart';
import 'delivery_fee_editor_screen.dart';

/// DeliveryFeeListScreen - Table view of all delivery fee configurations
///
/// This screen displays all delivery fee configurations in a table format
/// with columns for scope, config_name, status, version, updated_at, and
/// last_modified_by. Includes action buttons for CRUD operations.
///
/// Phase C.4 - Distance-based Delivery Fees - Phase 2 (Admin UI Foundation)
class DeliveryFeeListScreen extends StatefulWidget {
  const DeliveryFeeListScreen({super.key});

  @override
  State<DeliveryFeeListScreen> createState() => _DeliveryFeeListScreenState();
}

class _DeliveryFeeListScreenState extends State<DeliveryFeeListScreen> {
  final AdminDeliveryConfigService _adminService = AdminDeliveryConfigService();

  List<DeliveryFeeConfig> _configs = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _filterScope;
  bool? _filterActive;

  @override
  void initState() {
    super.initState();
    _loadConfigurations();
  }

  /// Load delivery fee configurations from service
  Future<void> _loadConfigurations() async {
    if (!kEnableAdminDeliveryRates) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Admin delivery rates feature is disabled';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final configs = await _adminService.getConfigs(
        scope: _filterScope,
        isActive: _filterActive,
      );

      if (mounted) {
        setState(() {
          _configs = configs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _configs = [];
          _isLoading = false;
          _errorMessage = 'Failed to load configurations: ${e.toString()}';
        });
      }
    }
  }

  /// Handle configuration creation
  void _createConfiguration() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeliveryFeeEditorScreen()),
    ).then((_) => _loadConfigurations());
  }

  /// Handle configuration editing
  void _editConfiguration(DeliveryFeeConfig config) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryFeeEditorScreen(config: config),
      ),
    ).then((_) => _loadConfigurations());
  }

  /// Handle configuration duplication
  Future<void> _duplicateConfiguration(DeliveryFeeConfig config) async {
    try {
      final newScope = '${config.scope}_COPY';
      final newName = '${config.configName}_copy';

      await _adminService.duplicateConfig(
        config.id,
        newScope,
        newName,
        'admin_user', // TODO: Get actual admin user ID
      );

      _showSuccessMessage('Configuration duplicated successfully');
      _loadConfigurations();
    } catch (e) {
      _showErrorMessage('Failed to duplicate configuration: ${e.toString()}');
    }
  }

  /// Handle configuration activation/deactivation
  Future<void> _toggleConfiguration(DeliveryFeeConfig config) async {
    try {
      await _adminService.toggleActive(
        config.id,
        !config.isActive,
        'admin_user', // TODO: Get actual admin user ID
      );

      _showSuccessMessage(
        config.isActive
            ? 'Configuration deactivated successfully'
            : 'Configuration activated successfully',
      );
      _loadConfigurations();
    } catch (e) {
      _showErrorMessage('Failed to toggle configuration: ${e.toString()}');
    }
  }

  /// Handle configuration deletion
  Future<void> _deleteConfiguration(DeliveryFeeConfig config) async {
    final confirmed = await _showDeleteConfirmation(config);
    if (!confirmed) return;

    try {
      await _adminService.deleteConfig(
        config.id,
        'admin_user', // TODO: Get actual admin user ID
      );

      _showSuccessMessage('Configuration deleted successfully');
      _loadConfigurations();
    } catch (e) {
      _showErrorMessage('Failed to delete configuration: ${e.toString()}');
    }
  }

  /// Show delete confirmation dialog
  Future<bool> _showDeleteConfirmation(DeliveryFeeConfig config) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Configuration'),
            content: Text(
              'Are you sure you want to delete the configuration "${config.configName}" for scope "${config.scope}"?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Show error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kEnableAdminDeliveryRates) {
      return AdminLayout(
        title: 'Delivery Fee Management',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Delivery Fee Management',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is currently disabled.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text(
                'Enable kEnableAdminDeliveryRates in maps_config.dart to access this feature.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return AdminLayout(
      title: 'Delivery Fee Management',
      actions: [
        ElevatedButton.icon(
          onPressed: _createConfiguration,
          icon: const Icon(Icons.add),
          label: const Text('Create Configuration'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
          ),
        ),
      ],
      isLoading: _isLoading,
      error: _errorMessage,
      child: Column(
        children: [
          // Filters
          _buildFilters(),

          const SizedBox(height: 16),

          // Configurations table
          Expanded(child: _buildConfigurationsTable()),
        ],
      ),
    );
  }

  /// Build filter controls
  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Scope filter
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                value: _filterScope,
                decoration: const InputDecoration(
                  labelText: 'Filter by Scope',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Scopes'),
                  ),
                  const DropdownMenuItem(
                    value: 'GLOBAL',
                    child: Text('GLOBAL'),
                  ),
                  const DropdownMenuItem(
                    value: 'CITY:BLR',
                    child: Text('CITY:BLR'),
                  ),
                  const DropdownMenuItem(
                    value: 'CITY:DEL',
                    child: Text('CITY:DEL'),
                  ),
                  const DropdownMenuItem(
                    value: 'CITY:MUM',
                    child: Text('CITY:MUM'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterScope = value;
                  });
                  _loadConfigurations();
                },
              ),
            ),

            const SizedBox(width: 16),

            // Active filter
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<bool?>(
                value: _filterActive,
                decoration: const InputDecoration(
                  labelText: 'Filter by Status',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Status')),
                  DropdownMenuItem(value: true, child: Text('Active')),
                  DropdownMenuItem(value: false, child: Text('Inactive')),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterActive = value;
                  });
                  _loadConfigurations();
                },
              ),
            ),

            const SizedBox(width: 16),

            // Refresh button
            IconButton(
              onPressed: _loadConfigurations,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
      ),
    );
  }

  /// Build configurations table
  Widget _buildConfigurationsTable() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error Loading Configurations',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConfigurations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_configs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Configurations Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first delivery fee configuration to get started.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createConfiguration,
              icon: const Icon(Icons.add),
              label: const Text('Create Configuration'),
            ),
          ],
        ),
      );
    }

    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Scope')),
            DataColumn(label: Text('Config Name')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Tiers')),
            DataColumn(label: Text('Min Fee')),
            DataColumn(label: Text('Max Fee')),
            DataColumn(label: Text('Version')),
            DataColumn(label: Text('Updated')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _configs
              .map((config) => _buildConfigurationRow(config))
              .toList(),
        ),
      ),
    );
  }

  /// Build individual configuration row
  DataRow _buildConfigurationRow(DeliveryFeeConfig config) {
    return DataRow(
      cells: [
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getScopeColor(config.scopeType),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              config.scope,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(Text(config.configName)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: config.isActive ? Colors.green : Colors.grey,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              config.isActive ? 'Active' : 'Inactive',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(Text('${config.tierRates.length} tiers')),
        DataCell(Text('₹${config.minFee.toStringAsFixed(0)}')),
        DataCell(Text('₹${config.maxFee.toStringAsFixed(0)}')),
        DataCell(Text('v${config.version}')),
        DataCell(Text(_formatDate(config.updatedAt))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _editConfiguration(config),
                icon: const Icon(Icons.edit, size: 18),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () => _duplicateConfiguration(config),
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Duplicate',
              ),
              IconButton(
                onPressed: () => _toggleConfiguration(config),
                icon: Icon(
                  config.isActive ? Icons.toggle_on : Icons.toggle_off,
                  size: 18,
                ),
                tooltip: config.isActive ? 'Deactivate' : 'Activate',
              ),
              if (config.scope != 'GLOBAL' || !config.isActive)
                IconButton(
                  onPressed: () => _deleteConfiguration(config),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: 'Delete',
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Get color for scope type
  Color _getScopeColor(String scopeType) {
    switch (scopeType) {
      case 'GLOBAL':
        return Colors.blue;
      case 'CITY':
        return Colors.green;
      case 'ZONE':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
