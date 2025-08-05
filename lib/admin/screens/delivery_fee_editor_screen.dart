import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/delivery_fee_config.dart';
import '../../services/admin_delivery_config_service.dart';
import '../../config/maps_config.dart';
import '../widgets/tier_rate_editor.dart';

/// DeliveryFeeEditorScreen - Form-based editor for delivery fee configurations
///
/// This screen provides a comprehensive form interface for creating and editing
/// delivery fee configurations. Includes general settings, tier rate management,
/// and form validation.
///
/// Phase C.4 - Distance-based Delivery Fees - Phase 2 (Admin UI Foundation)
class DeliveryFeeEditorScreen extends StatefulWidget {
  final DeliveryFeeConfig? config;

  const DeliveryFeeEditorScreen({super.key, this.config});

  @override
  State<DeliveryFeeEditorScreen> createState() =>
      _DeliveryFeeEditorScreenState();
}

class _DeliveryFeeEditorScreenState extends State<DeliveryFeeEditorScreen> {
  final AdminDeliveryConfigService _adminService = AdminDeliveryConfigService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _scopeController = TextEditingController();
  final _configNameController = TextEditingController();
  final _minFeeController = TextEditingController();
  final _maxFeeController = TextEditingController();
  final _freeDeliveryController = TextEditingController();
  final _maxDistanceController = TextEditingController();
  final _calibrationController = TextEditingController();

  // Form state
  bool _isActive = true;
  bool _useRouting = true;
  String _scopeType = 'GLOBAL';
  String? _cityCode;
  String? _zoneCode;
  List<DeliveryFeeTier> _tierRates = [];

  // UI state
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _scopeController.dispose();
    _configNameController.dispose();
    _minFeeController.dispose();
    _maxFeeController.dispose();
    _freeDeliveryController.dispose();
    _maxDistanceController.dispose();
    _calibrationController.dispose();
    super.dispose();
  }

  /// Initialize form with existing configuration or defaults
  void _initializeForm() {
    if (widget.config != null) {
      final config = widget.config!;

      _scopeController.text = config.scope;
      _configNameController.text = config.configName;
      _minFeeController.text = config.minFee.toString();
      _maxFeeController.text = config.maxFee.toString();
      _freeDeliveryController.text =
          config.freeDeliveryThreshold?.toString() ?? '';
      _maxDistanceController.text = config.maxServiceableDistanceKm.toString();
      _calibrationController.text = config.calibrationMultiplier.toString();

      _isActive = config.isActive;
      _useRouting = config.useRouting;
      _tierRates = List.from(config.tierRates);

      // Parse scope
      _parseScopeString(config.scope);
    } else {
      // Default values for new configuration
      _configNameController.text = 'default';
      _minFeeController.text = '15';
      _maxFeeController.text = '99';
      _freeDeliveryController.text = '500';
      _maxDistanceController.text = '15';
      _calibrationController.text = '1.3';

      // Default tier rates
      _tierRates = [
        const DeliveryFeeTier(minKm: 0, maxKm: 3, fee: 19),
        const DeliveryFeeTier(minKm: 3, maxKm: 6, fee: 29),
        const DeliveryFeeTier(minKm: 6, maxKm: 9, fee: 39),
        const DeliveryFeeTier(minKm: 9, maxKm: 12, fee: 49),
        const DeliveryFeeTier(minKm: 12, maxKm: null, baseFee: 59, perKmFee: 5),
      ];
    }

    _updateScopeController();
  }

  /// Parse scope string into components
  void _parseScopeString(String scope) {
    if (scope == 'GLOBAL') {
      _scopeType = 'GLOBAL';
      _cityCode = null;
      _zoneCode = null;
    } else if (scope.startsWith('CITY:')) {
      _scopeType = 'CITY';
      _cityCode = scope.substring(5);
      _zoneCode = null;
    } else if (scope.startsWith('ZONE:')) {
      _scopeType = 'ZONE';
      final parts = scope.substring(5).split('-');
      _cityCode = parts.isNotEmpty ? parts[0] : null;
      _zoneCode = parts.length > 1 ? parts[1] : null;
    }
  }

  /// Update scope controller based on type and codes
  void _updateScopeController() {
    switch (_scopeType) {
      case 'GLOBAL':
        _scopeController.text = 'GLOBAL';
        break;
      case 'CITY':
        _scopeController.text = _cityCode != null ? 'CITY:$_cityCode' : 'CITY:';
        break;
      case 'ZONE':
        _scopeController.text = _cityCode != null && _zoneCode != null
            ? 'ZONE:$_cityCode-$_zoneCode'
            : 'ZONE:';
        break;
    }
  }

  /// Validate form data
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      print('🔍 DEBUG: Form validation failed');
      return false;
    }

    // Validate tier rates
    if (_tierRates.isEmpty) {
      _showErrorMessage('At least one tier rate is required');
      return false;
    }

    print('🔍 DEBUG: Validating ${_tierRates.length} tier rates');
    for (int i = 0; i < _tierRates.length; i++) {
      final tier = _tierRates[i];
      print(
        '🔍 DEBUG: Tier $i: ${tier.minKm}km - ${tier.maxKm}km (fee: ${tier.fee}, base: ${tier.baseFee}, perKm: ${tier.perKmFee})',
      );
    }

    // Validate tier continuity
    final sortedTiers = List<DeliveryFeeTier>.from(_tierRates)
      ..sort((a, b) => a.minKm.compareTo(b.minKm));

    print('🔍 DEBUG: Sorted tiers:');
    for (int i = 0; i < sortedTiers.length; i++) {
      final tier = sortedTiers[i];
      print('🔍 DEBUG: Sorted Tier $i: ${tier.minKm}km - ${tier.maxKm}km');
    }

    for (int i = 0; i < sortedTiers.length; i++) {
      final tier = sortedTiers[i];

      // Check tier validity
      if (tier.maxKm != null && tier.minKm >= tier.maxKm!) {
        final errorMsg =
            'Invalid tier range: ${tier.minKm}km - ${tier.maxKm}km';
        print('🔍 DEBUG: $errorMsg');
        _showErrorMessage(errorMsg);
        return false;
      }

      // Check continuity (except for last tier)
      if (i < sortedTiers.length - 1) {
        final nextTier = sortedTiers[i + 1];
        if (tier.maxKm == null) {
          final errorMsg =
              'Only the last tier can have unlimited range (found at position $i)';
          print('🔍 DEBUG: $errorMsg');
          _showErrorMessage(errorMsg);
          return false;
        }
        if (tier.maxKm != nextTier.minKm) {
          final errorMsg =
              'Tier ranges must be continuous: ${tier.maxKm}km ≠ ${nextTier.minKm}km';
          print('🔍 DEBUG: $errorMsg');
          _showErrorMessage(errorMsg);
          return false;
        }
      }
    }

    print('🔍 DEBUG: All tier validations passed');
    return true;
  }

  /// Save configuration
  Future<void> _saveConfiguration() async {
    if (!_validateForm()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final config = DeliveryFeeConfig(
        id: widget.config?.id ?? '',
        scope: _scopeController.text,
        configName: _configNameController.text,
        isActive: _isActive,
        useRouting: _useRouting,
        calibrationMultiplier: double.parse(_calibrationController.text),
        tierRates: _tierRates,
        dynamicMultipliers:
            widget.config?.dynamicMultipliers ??
            DeliveryFeeMultipliers.defaultMultipliers,
        minFee: double.parse(_minFeeController.text),
        maxFee: double.parse(_maxFeeController.text),
        freeDeliveryThreshold: _freeDeliveryController.text.isNotEmpty
            ? double.parse(_freeDeliveryController.text)
            : null,
        maxServiceableDistanceKm: double.parse(_maxDistanceController.text),
        version: widget.config?.version ?? 1,
        lastModifiedBy: 'admin_user', // TODO: Get actual admin user ID
        createdAt: widget.config?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.config != null) {
        // Update existing configuration
        await _adminService.updateConfig(config, 'admin_user');
        _showSuccessMessage('Configuration updated successfully');
      } else {
        // Create new configuration
        await _adminService.createConfig(config);
        _showSuccessMessage('Configuration created successfully');
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorMessage('Failed to save configuration: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// Show success message
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  /// Show error message
  void _showErrorMessage(String message) {
    setState(() {
      _errorMessage = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kEnableAdminDeliveryRates) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Fee Editor')),
        body: const Center(
          child: Text('Admin delivery rates feature is disabled'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.config != null ? 'Edit Configuration' : 'Create Configuration',
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveConfiguration,
              child: const Text('Save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error message
              if (_errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[600]),
                        ),
                      ),
                    ],
                  ),
                ),

              // General Settings
              _buildGeneralSettings(),

              const SizedBox(height: 32),

              // Tier Rates
              _buildTierRatesSection(),

              const SizedBox(height: 32),

              // Fee Limits
              _buildFeeLimitsSection(),

              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveConfiguration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text('Saving...'),
                          ],
                        )
                      : Text(
                          widget.config != null
                              ? 'Update Configuration'
                              : 'Create Configuration',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build general settings section
  Widget _buildGeneralSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Scope Type
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _scopeType,
                    decoration: const InputDecoration(
                      labelText: 'Scope Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GLOBAL', child: Text('Global')),
                      DropdownMenuItem(value: 'CITY', child: Text('City')),
                      DropdownMenuItem(value: 'ZONE', child: Text('Zone')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _scopeType = value!;
                        _updateScopeController();
                      });
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // City Code (if not GLOBAL)
                if (_scopeType != 'GLOBAL')
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'City Code',
                        border: OutlineInputBorder(),
                        hintText: 'BLR, DEL, MUM',
                      ),
                      onChanged: (value) {
                        _cityCode = value;
                        _updateScopeController();
                      },
                      validator: (value) {
                        if (_scopeType != 'GLOBAL' &&
                            (value == null || value.isEmpty)) {
                          return 'City code is required';
                        }
                        return null;
                      },
                    ),
                  ),

                // Zone Code (if ZONE)
                if (_scopeType == 'ZONE') ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Zone Code',
                        border: OutlineInputBorder(),
                        hintText: 'Z01, Z02',
                      ),
                      onChanged: (value) {
                        _zoneCode = value;
                        _updateScopeController();
                      },
                      validator: (value) {
                        if (_scopeType == 'ZONE' &&
                            (value == null || value.isEmpty)) {
                          return 'Zone code is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                // Config Name
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _configNameController,
                    decoration: const InputDecoration(
                      labelText: 'Configuration Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Configuration name is required';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Active Toggle
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Use Routing Toggle
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Use Routing'),
                    subtitle: const Text('Google Distance Matrix'),
                    value: _useRouting,
                    onChanged: (value) {
                      setState(() {
                        _useRouting = value;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Scope Preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scope Preview:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _scopeController.text,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build tier rates section
  Widget _buildTierRatesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distance-based Tier Rates',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            TierRateEditor(
              tierRates: _tierRates,
              onTierRatesChanged: (tierRates) {
                setState(() {
                  _tierRates = tierRates;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Build fee limits section
  Widget _buildFeeLimitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fee Limits & Thresholds',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Min Fee
                Expanded(
                  child: TextFormField(
                    controller: _minFeeController,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Fee (₹)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Minimum fee is required';
                      }
                      final fee = double.tryParse(value);
                      if (fee == null || fee < 0) {
                        return 'Invalid minimum fee';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Max Fee
                Expanded(
                  child: TextFormField(
                    controller: _maxFeeController,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Fee (₹)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Maximum fee is required';
                      }
                      final fee = double.tryParse(value);
                      if (fee == null || fee < 0) {
                        return 'Invalid maximum fee';
                      }
                      final minFee = double.tryParse(_minFeeController.text);
                      if (minFee != null && fee < minFee) {
                        return 'Maximum fee must be >= minimum fee';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Free Delivery Threshold
                Expanded(
                  child: TextFormField(
                    controller: _freeDeliveryController,
                    decoration: const InputDecoration(
                      labelText: 'Free Delivery Threshold (₹)',
                      border: OutlineInputBorder(),
                      hintText: 'Optional',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final threshold = double.tryParse(value);
                        if (threshold == null || threshold < 0) {
                          return 'Invalid threshold';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                // Max Distance
                Expanded(
                  child: TextFormField(
                    controller: _maxDistanceController,
                    decoration: const InputDecoration(
                      labelText: 'Max Serviceable Distance (km)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Max distance is required';
                      }
                      final distance = double.tryParse(value);
                      if (distance == null || distance <= 0) {
                        return 'Invalid distance';
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 16),

                // Calibration Multiplier
                Expanded(
                  child: TextFormField(
                    controller: _calibrationController,
                    decoration: const InputDecoration(
                      labelText: 'Calibration Multiplier',
                      border: OutlineInputBorder(),
                      hintText: '1.3 (driving vs straight-line)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Calibration multiplier is required';
                      }
                      final multiplier = double.tryParse(value);
                      if (multiplier == null || multiplier <= 0) {
                        return 'Invalid multiplier';
                      }
                      return null;
                    },
                  ),
                ),

                const Expanded(child: SizedBox()), // Spacer
              ],
            ),
          ],
        ),
      ),
    );
  }
}
