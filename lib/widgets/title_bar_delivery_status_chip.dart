import 'package:flutter/material.dart';
import '../services/delivery_address_state.dart';

/// TitleBarDeliveryStatusChip
/// Compact chip to show: "⚡ 25-30 min • Current Location Name"
/// - Delivery ETA text is passed in so we don't couple to fee/ETA integrations
/// - Location comes from DeliveryAddressState (manual override takes precedence)
/// - Handles loading/denied/fallback gracefully via props
class TitleBarDeliveryStatusChip extends StatelessWidget {
  final String? deliveryEtaText; // e.g., "25-30 min"
  final bool isLoading; // true while fetching permission/location on startup
  final bool permissionDenied; // true if location permission denied
  final VoidCallback? onTap; // opens existing location picker/address management
  final String? fallbackLocationLabel; // e.g., "Set location" or "Current location"

  const TitleBarDeliveryStatusChip({
    super.key,
    required this.deliveryEtaText,
    this.isLoading = false,
    this.permissionDenied = false,
    this.onTap,
    this.fallbackLocationLabel,
  });

  String _resolveLocationLabel() {
    // Manual override via shared state takes precedence
    final current = DeliveryAddressState.getCurrentAddress();
    if (current != null && current.trim().isNotEmpty) {
      // Use a short address for compact display
      return current.length > 28 ? '${current.substring(0, 25)}...' : current;
    }
    // fallbacks
    if (isLoading) return 'Locating…';
    if (permissionDenied) return fallbackLocationLabel ?? 'Set location';
    return fallbackLocationLabel ?? 'Current location';
  }

  String _resolveEta() {
    if (deliveryEtaText == null || deliveryEtaText!.trim().isEmpty) return '—';
    return deliveryEtaText!;
  }

  @override
  Widget build(BuildContext context) {
    final eta = _resolveEta();
    final locationLabel = _resolveLocationLabel();

    final label = '⚡ $eta • $locationLabel';

    final bg = Colors.green[50];
    final border = Colors.green[200];
    final textColor = Colors.green[800];

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.green[600]),
            ),
          ),
          const SizedBox(width: 6),
        ] else ...[
          const Text('⚡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            // When loading we already showed spinner, keep label consistent
            isLoading ? '— • $locationLabel' : label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: border!),
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: const BoxConstraints(maxWidth: 260, minHeight: 28),
          child: content,
        ),
      ),
    );
  }
}
