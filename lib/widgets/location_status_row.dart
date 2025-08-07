import 'package:flutter/material.dart';
import '../config/ui_flags.dart';
import '../widgets/address_picker.dart';

/// Delivery status types for smart status indicators
enum DeliveryStatusType {
  available, // ⚡ 12 min - Normal delivery
  busy, // 🟡 20-30 min - High demand
  limited, // 🟠 Limited delivery - Restricted area
  closed, // 🔴 Closed - Not available
  unavailable, // ❌ Not serviceable - Outside delivery zone
}

/// Row A of the compact location header
/// Contains: Delivery Status + Location Summary + Action Icons
///
/// Layout: [⚡ Status] [Location Text] [Spacer] [🔔 Notifications]
/// Height: ~44-48dp with smart truncation
class LocationStatusRow extends StatefulWidget {
  final String customerId;
  final String? initialAddress;
  final Function(String address, Map<String, dynamic> locationData)?
  onAddressChanged;
  final VoidCallback?
  onNotificationTap; // Phase 4F: Replaced profile/cart with notifications
  final int notificationCount; // Phase 4F: Notification badge count
  final bool isTablet;
  final bool isCollapsed;

  const LocationStatusRow({
    super.key,
    required this.customerId,
    this.initialAddress,
    this.onAddressChanged,
    this.onNotificationTap, // Phase 4F: Replaced profile/cart with notifications
    this.notificationCount = 0, // Phase 4F: Notification badge count
    this.isTablet = false,
    this.isCollapsed = false,
  });

  @override
  State<LocationStatusRow> createState() => _LocationStatusRowState();
}

class _LocationStatusRowState extends State<LocationStatusRow> {
  String _deliveryStatus = '';
  String _locationLabel = 'Home';
  String _locationAddress = '';
  DeliveryStatusType _statusType = DeliveryStatusType.available;

  @override
  void initState() {
    super.initState();
    _initializeLocationData();
    logUi('LocationStatusRow initialized');
  }

  void _initializeLocationData() {
    // Initialize with provided address or default
    _locationAddress = widget.initialAddress ?? 'Select delivery location';

    // Extract area name from full address for compact display
    _extractLocationInfo(_locationAddress);
  }

  void _extractLocationInfo(String fullAddress) {
    if (fullAddress.isEmpty || fullAddress == 'Select delivery location') {
      _locationLabel = 'Select Location';
      _locationAddress = 'Tap to choose delivery area';
      _deliveryStatus = '';
      _statusType = DeliveryStatusType.unavailable;
      return;
    }

    // Smart extraction of area name from full address
    // Example: "HNO 123, 5th Main, Koramangala, Bangalore" -> "Koramangala"
    final parts = fullAddress.split(',');
    if (parts.length >= 2) {
      // Take the second-to-last part as area name (before city)
      final areaIndex = parts.length >= 3 ? parts.length - 2 : parts.length - 1;
      _locationLabel = parts[areaIndex].trim();
    } else {
      _locationLabel = fullAddress.length > 20
          ? '${fullAddress.substring(0, 20)}...'
          : fullAddress;
    }

    // Smart delivery status based on location and time
    _determineDeliveryStatus(_locationLabel);
  }

  /// Determine smart delivery status based on location and current conditions
  void _determineDeliveryStatus(String area) {
    final hour = DateTime.now().hour;

    // Mock intelligent status determination
    // In real app, this would integrate with delivery service APIs

    if (area.toLowerCase().contains('select') || area.isEmpty) {
      _statusType = DeliveryStatusType.unavailable;
      _deliveryStatus = '';
      return;
    }

    // Business hours check (6 AM to 11 PM)
    if (hour < 6 || hour > 23) {
      _statusType = DeliveryStatusType.closed;
      _deliveryStatus = 'Closed';
      return;
    }

    // Peak hours logic (12-2 PM, 7-9 PM)
    if ((hour >= 12 && hour <= 14) || (hour >= 19 && hour <= 21)) {
      _statusType = DeliveryStatusType.busy;
      _deliveryStatus = '25-35 min';
      return;
    }

    // Area-based delivery status (mock data)
    final popularAreas = [
      'koramangala',
      'indiranagar',
      'whitefield',
      'btm',
      'jayanagar',
    ];
    final areaLower = area.toLowerCase();

    if (popularAreas.any((popular) => areaLower.contains(popular))) {
      _statusType = DeliveryStatusType.available;
      _deliveryStatus = '12-18 min';
    } else {
      _statusType = DeliveryStatusType.limited;
      _deliveryStatus = '30-45 min';
    }
  }

  void _openLocationPicker() {
    logUi('LocationStatusRow: Opening location picker');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: AddressPicker(
          isPillMode: false,
          customerId: widget.customerId,
          initialAddress: widget.initialAddress,
          onAddressChanged: (address, locationData) {
            setState(() {
              _extractLocationInfo(address);
            });
            widget.onAddressChanged?.call(address, locationData ?? {});
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const emeraldGreen = Color(0xFF059669);

    return SizedBox(
      height: 48, // Fixed height for Row A
      child: Row(
        children: [
          // Left: Delivery Status + Location
          Expanded(
            child: GestureDetector(
              onTap: _openLocationPicker,
              child: Row(
                children: [
                  // Smart Delivery Status Chip
                  if (_deliveryStatus.isNotEmpty) ...[
                    _buildSmartStatusChip(),
                    const SizedBox(width: 8),
                  ],

                  // Location Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Location Label (Home, Other, etc.)
                        Text(
                          _locationLabel,
                          style: TextStyle(
                            fontSize: widget.isTablet ? 16 : 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Address Subtitle
                        if (_locationAddress.isNotEmpty &&
                            _locationAddress != 'Select delivery location')
                          Text(
                            _truncateAddress(_locationAddress),
                            style: TextStyle(
                              fontSize: widget.isTablet ? 13 : 12,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Dropdown Arrow
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Right: Notification Icon with Badge (Phase 4F: Replaced profile/cart with notifications)
          if (widget.onNotificationTap != null)
            Stack(
              clipBehavior: Clip.none,
              children: [
                _ActionIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: widget.onNotificationTap,
                  tooltip: 'Notifications',
                ),
                if (widget.notificationCount > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Center(
                        child: Text(
                          widget.notificationCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Build smart delivery status chip with appropriate styling
  Widget _buildSmartStatusChip() {
    final (icon, color, bgColor) = _getStatusStyling();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            _deliveryStatus,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Get appropriate icon, color, and background color for delivery status
  (IconData, Color, Color) _getStatusStyling() {
    const emeraldGreen = Color(0xFF059669);
    const orangeColor = Color(0xFFEA580C);
    const redColor = Color(0xFFDC2626);
    const grayColor = Color(0xFF6B7280);

    switch (_statusType) {
      case DeliveryStatusType.available:
        return (Icons.bolt, emeraldGreen, emeraldGreen.withValues(alpha: 0.1));
      case DeliveryStatusType.busy:
        return (
          Icons.schedule,
          orangeColor,
          orangeColor.withValues(alpha: 0.1),
        );
      case DeliveryStatusType.limited:
        return (
          Icons.warning_rounded,
          orangeColor,
          orangeColor.withValues(alpha: 0.1),
        );
      case DeliveryStatusType.closed:
        return (Icons.access_time, redColor, redColor.withValues(alpha: 0.1));
      case DeliveryStatusType.unavailable:
        return (
          Icons.location_off,
          grayColor,
          grayColor.withValues(alpha: 0.1),
        );
    }
  }

  /// Smart address truncation for compact display
  String _truncateAddress(String address) {
    if (address.length <= 30) return address;

    // Try to truncate in the middle, keeping start and end
    final parts = address.split(',');
    if (parts.length > 2) {
      return '${parts.first.trim()}...${parts.last.trim()}';
    }

    // Fallback: simple truncation
    return '${address.substring(0, 27)}...';
  }
}

/// Reusable action icon button (32-36dp circular)
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const _ActionIconButton({required this.icon, this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
