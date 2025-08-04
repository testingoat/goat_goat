import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/delivery_fee_config.dart';

/// TierRateEditor - Widget for managing distance-based pricing tiers
/// 
/// This widget provides an interface for adding, editing, and deleting
/// delivery fee tier rates with validation for continuity and non-overlap.
/// 
/// Phase C.4 - Distance-based Delivery Fees - Phase 2 (Admin UI Foundation)
class TierRateEditor extends StatefulWidget {
  final List<DeliveryFeeTier> tierRates;
  final Function(List<DeliveryFeeTier>) onTierRatesChanged;

  const TierRateEditor({
    super.key,
    required this.tierRates,
    required this.onTierRatesChanged,
  });

  @override
  State<TierRateEditor> createState() => _TierRateEditorState();
}

class _TierRateEditorState extends State<TierRateEditor> {
  late List<DeliveryFeeTier> _tierRates;

  @override
  void initState() {
    super.initState();
    _tierRates = List.from(widget.tierRates);
  }

  @override
  void didUpdateWidget(TierRateEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tierRates != oldWidget.tierRates) {
      _tierRates = List.from(widget.tierRates);
    }
  }

  /// Add a new tier rate
  void _addTierRate() {
    final lastTier = _tierRates.isNotEmpty ? _tierRates.last : null;
    final newMinKm = lastTier?.maxKm ?? 0.0;
    
    final newTier = DeliveryFeeTier(
      minKm: newMinKm,
      maxKm: newMinKm + 5.0, // Default 5km range
      fee: 20.0, // Default fee
    );
    
    setState(() {
      _tierRates.add(newTier);
    });
    
    widget.onTierRatesChanged(_tierRates);
  }

  /// Remove a tier rate
  void _removeTierRate(int index) {
    if (_tierRates.length <= 1) {
      _showErrorMessage('At least one tier rate is required');
      return;
    }
    
    setState(() {
      _tierRates.removeAt(index);
    });
    
    widget.onTierRatesChanged(_tierRates);
  }

  /// Update a tier rate
  void _updateTierRate(int index, DeliveryFeeTier updatedTier) {
    setState(() {
      _tierRates[index] = updatedTier;
    });
    
    widget.onTierRatesChanged(_tierRates);
  }

  /// Show error message
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Validate tier continuity
  String? _validateTierContinuity() {
    if (_tierRates.isEmpty) return 'At least one tier is required';
    
    final sortedTiers = List<DeliveryFeeTier>.from(_tierRates)
      ..sort((a, b) => a.minKm.compareTo(b.minKm));

    for (int i = 0; i < sortedTiers.length; i++) {
      final tier = sortedTiers[i];
      
      // Check tier validity
      if (tier.maxKm != null && tier.minKm >= tier.maxKm!) {
        return 'Invalid range: ${tier.minKm}km - ${tier.maxKm}km';
      }

      // Check continuity (except for last tier)
      if (i < sortedTiers.length - 1) {
        final nextTier = sortedTiers[i + 1];
        if (tier.maxKm == null) {
          return 'Only the last tier can have unlimited range';
        }
        if (tier.maxKm != nextTier.minKm) {
          return 'Tiers must be continuous: ${tier.maxKm}km ≠ ${nextTier.minKm}km';
        }
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final validationError = _validateTierContinuity();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Validation error
        if (validationError != null)
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
                Icon(Icons.warning, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    validationError,
                    style: TextStyle(color: Colors.red[600], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // Tier rates table
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('Distance Range', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('Fee Structure', style: TextStyle(fontWeight: FontWeight.bold))),
                    SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              
              // Tier rows
              ...List.generate(_tierRates.length, (index) {
                return _buildTierRow(index, _tierRates[index]);
              }),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Add tier button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addTierRate,
            icon: const Icon(Icons.add),
            label: const Text('Add Tier Rate'),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tier summary
        _buildTierSummary(),
      ],
    );
  }

  /// Build individual tier row
  Widget _buildTierRow(int index, DeliveryFeeTier tier) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: index < _tierRates.length - 1 ? 1 : 0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Distance range
          Expanded(
            flex: 2,
            child: Row(
              children: [
                // Min distance
                Expanded(
                  child: TextFormField(
                    initialValue: tier.minKm.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Min (km)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    onChanged: (value) {
                      final minKm = double.tryParse(value) ?? tier.minKm;
                      _updateTierRate(index, tier.copyWith(minKm: minKm));
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                const Text(' - '),
                const SizedBox(width: 8),
                
                // Max distance
                Expanded(
                  child: tier.maxKm != null
                      ? TextFormField(
                          initialValue: tier.maxKm.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Max (km)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          onChanged: (value) {
                            final maxKm = double.tryParse(value);
                            _updateTierRate(index, tier.copyWith(maxKm: maxKm));
                          },
                        )
                      : Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Center(
                            child: Text(
                              'Unlimited',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                ),
                
                const SizedBox(width: 8),
                
                // Unlimited toggle
                Checkbox(
                  value: tier.maxKm == null,
                  onChanged: (unlimited) {
                    if (unlimited == true) {
                      _updateTierRate(index, tier.copyWith(maxKm: null));
                    } else {
                      _updateTierRate(index, tier.copyWith(maxKm: tier.minKm + 5.0));
                    }
                  },
                ),
                const Text('∞', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Fee structure
          Expanded(
            flex: 2,
            child: tier.fee != null
                ? TextFormField(
                    initialValue: tier.fee.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Fixed Fee (₹)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    onChanged: (value) {
                      final fee = double.tryParse(value) ?? tier.fee;
                      _updateTierRate(index, tier.copyWith(fee: fee));
                    },
                  )
                : Row(
                    children: [
                      // Base fee
                      Expanded(
                        child: TextFormField(
                          initialValue: tier.baseFee?.toString() ?? '0',
                          decoration: const InputDecoration(
                            labelText: 'Base (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          onChanged: (value) {
                            final baseFee = double.tryParse(value) ?? tier.baseFee ?? 0;
                            _updateTierRate(index, tier.copyWith(baseFee: baseFee));
                          },
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      const Text('+'),
                      const SizedBox(width: 8),
                      
                      // Per km fee
                      Expanded(
                        child: TextFormField(
                          initialValue: tier.perKmFee?.toString() ?? '0',
                          decoration: const InputDecoration(
                            labelText: 'Per km (₹)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          onChanged: (value) {
                            final perKmFee = double.tryParse(value) ?? tier.perKmFee ?? 0;
                            _updateTierRate(index, tier.copyWith(perKmFee: perKmFee));
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // Actions
          SizedBox(
            width: 100,
            child: Row(
              children: [
                // Toggle fee type
                IconButton(
                  onPressed: () {
                    if (tier.fee != null) {
                      // Switch to variable fee
                      _updateTierRate(
                        index,
                        DeliveryFeeTier(
                          minKm: tier.minKm,
                          maxKm: tier.maxKm,
                          baseFee: tier.fee,
                          perKmFee: 5.0,
                        ),
                      );
                    } else {
                      // Switch to fixed fee
                      _updateTierRate(
                        index,
                        DeliveryFeeTier(
                          minKm: tier.minKm,
                          maxKm: tier.maxKm,
                          fee: tier.baseFee ?? 20.0,
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    tier.fee != null ? Icons.functions : Icons.attach_money,
                    size: 18,
                  ),
                  tooltip: tier.fee != null ? 'Switch to Variable' : 'Switch to Fixed',
                ),
                
                // Delete tier
                IconButton(
                  onPressed: () => _removeTierRate(index),
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: 'Delete Tier',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build tier summary
  Widget _buildTierSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        border: Border.all(color: Colors.blue[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fee Preview',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          
          // Sample calculations
          ...List.generate(5, (index) {
            final distance = (index + 1) * 3.0; // 3, 6, 9, 12, 15 km
            final applicableTier = _tierRates.firstWhere(
              (tier) => tier.appliesTo(distance),
              orElse: () => _tierRates.isNotEmpty ? _tierRates.last : const DeliveryFeeTier(minKm: 0, maxKm: 1, fee: 0),
            );
            final fee = applicableTier.calculateFee(distance);
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text('${distance.toStringAsFixed(0)}km:'),
                  ),
                  Text(
                    '₹${fee.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${applicableTier.displayRange})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Extension to add copyWith method to DeliveryFeeTier
extension DeliveryFeeTierCopyWith on DeliveryFeeTier {
  DeliveryFeeTier copyWith({
    double? minKm,
    double? maxKm,
    double? fee,
    double? baseFee,
    double? perKmFee,
  }) {
    return DeliveryFeeTier(
      minKm: minKm ?? this.minKm,
      maxKm: maxKm ?? this.maxKm,
      fee: fee ?? this.fee,
      baseFee: baseFee ?? this.baseFee,
      perKmFee: perKmFee ?? this.perKmFee,
    );
  }
}
