import 'package:flutter/material.dart';
import '../models/saved_address.dart';
import '../services/saved_addresses_service.dart';
import '../config/maps_config.dart';

/// SavedAddressesCarousel - Horizontal scrolling carousel for saved addresses
/// 
/// This widget provides a 60px height carousel that displays saved address cards
/// with quick selection functionality. Features:
/// - Horizontal scrolling with momentum
/// - Emerald color scheme matching app design
/// - Quick address selection without opening full-screen
/// - "+ Add New" button for easy address management
/// - Loading states and error handling
/// - Zero impact on existing functionality
class SavedAddressesCarousel extends StatefulWidget {
  final String customerId;
  final Function(SavedAddress) onAddressSelected;
  final Function()? onAddNewPressed;
  final SavedAddress? selectedAddress;

  const SavedAddressesCarousel({
    super.key,
    required this.customerId,
    required this.onAddressSelected,
    this.onAddNewPressed,
    this.selectedAddress,
  });

  @override
  State<SavedAddressesCarousel> createState() => _SavedAddressesCarouselState();
}

class _SavedAddressesCarouselState extends State<SavedAddressesCarousel> {
  final SavedAddressesService _savedAddressesService = SavedAddressesService();
  
  List<SavedAddress> _savedAddresses = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  /// Load saved addresses from service
  Future<void> _loadSavedAddresses() async {
    if (!kEnableMultipleAddresses) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final addresses = await _savedAddressesService.getSavedAddresses(widget.customerId);
      
      if (mounted) {
        setState(() {
          _savedAddresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _savedAddresses = [];
          _isLoading = false;
          _errorMessage = 'Unable to load saved addresses';
        });
      }
    }
  }

  /// Handle address selection
  Future<void> _onAddressSelected(SavedAddress address) async {
    // Mark address as used
    await _savedAddressesService.markAddressAsUsed(widget.customerId, address.id);
    
    // Notify parent widget
    widget.onAddressSelected(address);
    
    // Refresh addresses to update order
    _loadSavedAddresses();
  }

  /// Handle add new address button
  void _onAddNewPressed() {
    if (widget.onAddNewPressed != null) {
      widget.onAddNewPressed!();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if feature is disabled
    if (!kEnableMultipleAddresses) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: _buildCarouselContent(),
    );
  }

  /// Build carousel content based on state
  Widget _buildCarouselContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_savedAddresses.isEmpty) {
      return _buildEmptyState();
    }

    return _buildAddressCarousel();
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
          ),
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 16, color: Colors.red[600]),
            const SizedBox(width: 4),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 10,
                color: Colors.red[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state (no saved addresses)
  Widget _buildEmptyState() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: _onAddNewPressed,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_location_alt,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Add saved address',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build address carousel
  Widget _buildAddressCarousel() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _savedAddresses.length + 1, // +1 for "Add New" button
      itemBuilder: (context, index) {
        if (index == _savedAddresses.length) {
          return _buildAddNewCard();
        }
        
        final address = _savedAddresses[index];
        final isSelected = widget.selectedAddress?.id == address.id;
        
        return _buildAddressCard(address, isSelected);
      },
    );
  }

  /// Build individual address card
  Widget _buildAddressCard(SavedAddress address, bool isSelected) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => _onAddressSelected(address),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF059669) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF059669) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF059669).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Address icon
              Icon(
                _getAddressIcon(address.iconName),
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF059669),
              ),
              const SizedBox(height: 2),
              
              // Address label
              Text(
                address.displayName,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF374151),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              
              // Primary indicator
              if (address.isPrimary)
                Container(
                  margin: const EdgeInsets.only(top: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF059669).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Primary',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF059669),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build "Add New" card
  Widget _buildAddNewCard() {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: _onAddNewPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF059669),
              width: 1,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Add icon
              const Icon(
                Icons.add_circle_outline,
                size: 18,
                color: Color(0xFF059669),
              ),
              const SizedBox(height: 2),
              
              // Add text
              const Text(
                'Add New',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF059669),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get icon for address type
  IconData _getAddressIcon(String iconName) {
    switch (iconName) {
      case 'home':
        return Icons.home;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'restaurant':
        return Icons.restaurant;
      case 'fitness_center':
        return Icons.fitness_center;
      default:
        return Icons.location_on;
    }
  }

  /// Refresh addresses (called from parent when new address is added)
  void refresh() {
    _loadSavedAddresses();
  }
}
