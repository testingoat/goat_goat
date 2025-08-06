import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/places_service.dart';
import '../screens/location_selector_screen.dart';
import '../config/maps_config.dart';
import '../services/delivery_address_state.dart';
import 'address_search_widget.dart';

/// AddressPicker - Unified address selection component
///
/// This component provides a single, consistent interface for address selection
/// across the app while preserving ALL existing functionality from Phase 3A.2.
///
/// Features:
/// - Places autocomplete integration (existing functionality preserved)
/// - Manual text input (existing functionality preserved)
/// - Map-based selection via LocationSelectorScreen (existing functionality)
/// - Auto-population support (existing functionality preserved)
/// - Two display modes: card (for cart) and pill (for header)
/// - Feature flag controlled with graceful fallbacks
/// - Zero-risk implementation - extends existing patterns
class AddressPicker extends StatefulWidget {
  final String? initialAddress;
  final String? hintText;
  final Function(String address, Map<String, dynamic>? locationData)?
  onAddressChanged;
  final bool isPillMode;
  final bool showMapButton;
  final String? customerId;

  const AddressPicker({
    super.key,
    this.initialAddress,
    this.hintText,
    this.onAddressChanged,
    this.isPillMode = false,
    this.showMapButton = true,
    this.customerId,
  });

  @override
  State<AddressPicker> createState() => _AddressPickerState();
}

class _AddressPickerState extends State<AddressPicker> {
  final TextEditingController _addressController = TextEditingController();
  final PlacesService _placesService = PlacesService();
  String? _currentAddress;
  Map<String, dynamic>? _currentLocationData;

  @override
  void initState() {
    super.initState();
    _initializeAddress();
  }

  /// Initialize address from shared state or widget parameter
  void _initializeAddress() {
    String? addressToUse;
    Map<String, dynamic>? locationDataToUse;

    // Priority 1: Use shared state if available and belongs to current customer
    if (widget.customerId != null && DeliveryAddressState.hasAddress()) {
      if (DeliveryAddressState.belongsToCustomer(widget.customerId!)) {
        addressToUse = DeliveryAddressState.getCurrentAddress();
        locationDataToUse = DeliveryAddressState.getLocationData();
        print('📍 ADDRESS_PICKER - Using shared state address');
      }
    }

    // Priority 2: Use widget initialAddress if no shared state
    if (addressToUse == null &&
        widget.initialAddress != null &&
        widget.initialAddress!.isNotEmpty) {
      addressToUse = widget.initialAddress!;
      print('📍 ADDRESS_PICKER - Using widget initial address');

      // Store in shared state for persistence
      if (widget.customerId != null) {
        DeliveryAddressState.setAddress(
          addressToUse,
          customerId: widget.customerId!,
        );
      }
    }

    // Apply the address if found
    if (addressToUse != null) {
      setState(() {
        _addressController.text = addressToUse!;
        _currentAddress = addressToUse;
        _currentLocationData = locationDataToUse;
      });
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Handle address change from text input or autocomplete
  void _onAddressChanged(String address, [Map<String, dynamic>? locationData]) {
    setState(() {
      _currentAddress = address;
      _currentLocationData = locationData;
    });

    // Update shared state for persistence
    if (widget.customerId != null && address.isNotEmpty) {
      DeliveryAddressState.updateAddressForCustomer(
        address,
        widget.customerId!,
        locationData: locationData,
      );
    }

    widget.onAddressChanged?.call(address, locationData);
  }

  /// Handle Places autocomplete selection
  void _onPlaceSelected(Map<String, dynamic> locationData) {
    final address =
        locationData['address'] as String? ??
        locationData['formatted_address'] as String? ??
        'Selected location';

    setState(() {
      _addressController.text = address;
      _currentAddress = address;
      _currentLocationData = locationData;
    });

    // Update shared state for persistence
    if (widget.customerId != null) {
      DeliveryAddressState.updateAddressForCustomer(
        address,
        widget.customerId!,
        locationData: locationData,
      );
    }

    widget.onAddressChanged?.call(address, locationData);
  }

  /// Open map-based location selector
  Future<void> _openMapSelector() async {
    if (widget.customerId == null) return;

    // Use existing LocationSelectorScreen
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectorScreen(
          customerId: widget.customerId!,
          initialLocation: _currentLocationData != null
              ? LatLng(
                  _currentLocationData!['latitude'] ?? 12.9716,
                  _currentLocationData!['longitude'] ?? 77.5946,
                )
              : const LatLng(12.9716, 77.5946), // Default to Bangalore
          initialAddress: _currentAddress,
        ),
      ),
    );

    if (result != null) {
      final address = result['address'] as String? ?? 'Selected location';
      setState(() {
        _addressController.text = address;
        _currentAddress = address;
        _currentLocationData = result;
      });

      // Update shared state for persistence
      if (widget.customerId != null) {
        DeliveryAddressState.updateAddressForCustomer(
          address,
          widget.customerId!,
          locationData: result,
        );
      }

      widget.onAddressChanged?.call(address, result);
    }
  }

  /// Clear address
  void _clearAddress() {
    setState(() {
      _addressController.clear();
      _currentAddress = null;
      _currentLocationData = null;
    });

    // Clear shared state if this belongs to current customer
    if (widget.customerId != null &&
        DeliveryAddressState.belongsToCustomer(widget.customerId!)) {
      DeliveryAddressState.clearAddress();
    }

    widget.onAddressChanged?.call('', null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isPillMode) {
      return _buildPillMode();
    } else {
      return _buildCardMode();
    }
  }

  /// Build pill mode for header display
  Widget _buildPillMode() {
    final hasAddress = _currentAddress != null && _currentAddress!.isNotEmpty;

    return GestureDetector(
      onTap: _openMapSelector,
      child: Container(
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.green[600], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasAddress ? _currentAddress! : 'Set delivery location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: hasAddress ? FontWeight.w500 : FontWeight.w400,
                  color: hasAddress ? Colors.black87 : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[600], size: 18),
          ],
        ),
      ),
    );
  }

  /// Build card mode for cart and other screens
  Widget _buildCardMode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Delivery Address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (widget.showMapButton)
                TextButton.icon(
                  onPressed: _openMapSelector,
                  icon: Icon(Icons.map, size: 16, color: Colors.green[600]),
                  label: Text(
                    'Use Map',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Smart address input - single field with autocomplete and manual entry
          if (kUseSimplifiedAddressInput) ...[
            // Single smart input field (UI Fix - eliminates duplication)
            if (kEnablePlacesAutocomplete) ...[
              AddressSearchWidget(
                initialQuery: _addressController.text,
                hintText:
                    widget.hintText ?? 'Search or enter your delivery address',
                onSelectSuggestion: _onPlaceSelected,
              ),
            ] else ...[
              // Fallback to manual input if Places is disabled
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Enter your delivery address',
                  prefixIcon: Icon(
                    Icons.location_on,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.green[600]!),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  suffixIcon: _addressController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[600]),
                          onPressed: _clearAddress,
                        )
                      : null,
                ),
                maxLines: 2,
                onChanged: (value) => _onAddressChanged(value.trim()),
              ),
            ],
          ] else ...[
            // Legacy dual input mode (preserved for rollback safety)
            if (kEnablePlacesAutocomplete) ...[
              AddressSearchWidget(
                initialQuery: _addressController.text,
                hintText: widget.hintText ?? 'Search for your delivery address',
                onSelectSuggestion: _onPlaceSelected,
              ),
              const SizedBox(height: 8),
              Text(
                'Or enter manually:',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // Manual address input (always available - preserves existing functionality)
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                hintText: kEnablePlacesAutocomplete
                    ? 'Type address manually if needed'
                    : (widget.hintText ?? 'Enter your delivery address'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.green[600]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                suffixIcon: _addressController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[600]),
                        onPressed: _clearAddress,
                      )
                    : null,
              ),
              maxLines: 2,
              onChanged: (value) => _onAddressChanged(value.trim()),
            ),
          ],

          // Status message
          if (_currentAddress != null && _currentAddress!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Address set - delivery fee will be calculated',
                    style: TextStyle(color: Colors.green[600], fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
