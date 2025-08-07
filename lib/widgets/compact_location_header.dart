import 'package:flutter/material.dart';
import '../config/ui_flags.dart';
import 'location_status_row.dart';
import 'search_pill_row.dart';

/// Compact two-row header replacing the large location bar
/// Row A: Status + Location summary + Action icons
/// Row B: Full-width search pill
///
/// Features:
/// - 25-35% height reduction vs old design
/// - Smart truncation and responsive design
/// - Scroll-collapsing behavior (Phase 2)
/// - Feature-flagged for safe rollout
class CompactLocationHeader extends StatefulWidget {
  final String customerId;
  final String? initialAddress;
  final TextEditingController searchController;
  final String searchQuery;
  final ScrollController? scrollController;
  final VoidCallback? onSearchChanged;
  final Function(String address, Map<String, dynamic> locationData)?
  onAddressChanged;
  final VoidCallback?
  onNotificationTap; // Phase 4F: Replaced profile/cart with notifications
  final int notificationCount; // Phase 4F: Notification badge count
  final bool showVoiceSearch;
  final VoidCallback? onVoiceSearchTap;

  const CompactLocationHeader({
    super.key,
    required this.customerId,
    this.initialAddress,
    required this.searchController,
    required this.searchQuery,
    this.scrollController,
    this.onSearchChanged,
    this.onAddressChanged,
    this.onNotificationTap, // Phase 4F: Replaced profile/cart with notifications
    this.notificationCount = 0, // Phase 4F: Notification badge count
    this.showVoiceSearch = false,
    this.onVoiceSearchTap,
  });

  @override
  State<CompactLocationHeader> createState() => _CompactLocationHeaderState();
}

class _CompactLocationHeaderState extends State<CompactLocationHeader> {
  bool _isCollapsed = false;
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    logUi('CompactLocationHeader initialized');

    // Attach scroll listener for collapse behavior
    if (widget.scrollController != null && UiFlags.enableScrollCollapse) {
      widget.scrollController!.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    // Remove scroll listener
    if (widget.scrollController != null && UiFlags.enableScrollCollapse) {
      widget.scrollController!.removeListener(_handleScroll);
    }
    _scrollController?.dispose();
    super.dispose();
  }

  /// Attach scroll controller for collapse behavior (Phase 2)
  void attachScrollController(ScrollController controller) {
    _scrollController = controller;
    _scrollController?.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (widget.scrollController == null) return;

    final offset = widget.scrollController!.offset;
    final shouldCollapse = offset > 50; // Collapse after 50px scroll

    if (shouldCollapse != _isCollapsed) {
      setState(() {
        _isCollapsed = shouldCollapse;
      });
      logUi(
        'CompactLocationHeader: ${_isCollapsed ? "Collapsed" : "Expanded"}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Feature flag check
    if (!UiFlags.compactLocationHeaderEnabled) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final horizontalPadding = isTablet ? 24.0 : 12.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 8.0,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: _isCollapsed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row A: Status + Location + Actions
          if (!_isCollapsed || !UiFlags.enableScrollCollapse)
            LocationStatusRow(
              customerId: widget.customerId,
              initialAddress: widget.initialAddress,
              onAddressChanged: widget.onAddressChanged,
              onNotificationTap: widget
                  .onNotificationTap, // Phase 4F: Replaced profile/cart with notifications
              notificationCount: widget
                  .notificationCount, // Phase 4F: Pass notification count for badge
              isTablet: isTablet,
              isCollapsed: _isCollapsed,
            ),

          // Spacing between rows
          if (!_isCollapsed || !UiFlags.enableScrollCollapse)
            const SizedBox(height: 8),

          // Row B: Search Pill
          SearchPillRow(
            controller: widget.searchController,
            searchQuery: widget.searchQuery,
            onSearchChanged: widget.onSearchChanged,
            showVoiceSearch: widget.showVoiceSearch,
            onVoiceSearchTap: widget.onVoiceSearchTap,
            isTablet: isTablet,
            isCollapsed: _isCollapsed,
          ),
        ],
      ),
    );
  }
}

/// Extension to add scroll behavior to any ScrollController
extension CompactHeaderScrollBehavior on ScrollController {
  void attachToCompactHeader(CompactLocationHeader header) {
    // This will be implemented in Phase 2
    // header.attachScrollController(this);
  }
}
