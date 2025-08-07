import 'package:flutter/material.dart';
import '../config/ui_flags.dart';
import '../services/voice_search_service.dart';

/// Row B of the compact location header
/// Contains: Full-width search pill with icons
///
/// Layout: [🔍] [Search field...] [🎤]
/// Height: 44-48dp with proper touch targets
class SearchPillRow extends StatefulWidget {
  final TextEditingController controller;
  final String searchQuery;
  final VoidCallback? onSearchChanged;
  final bool showVoiceSearch;
  final VoidCallback? onVoiceSearchTap;
  final bool isTablet;
  final bool isCollapsed;

  const SearchPillRow({
    super.key,
    required this.controller,
    required this.searchQuery,
    this.onSearchChanged,
    this.showVoiceSearch = false,
    this.onVoiceSearchTap,
    this.isTablet = false,
    this.isCollapsed = false,
  });

  @override
  State<SearchPillRow> createState() => _SearchPillRowState();
}

class _SearchPillRowState extends State<SearchPillRow> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  final VoiceSearchService _voiceSearchService = VoiceSearchService();
  bool _isListening = false;
  String _voiceSearchError = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _initializeVoiceSearch();
    logUi('SearchPillRow initialized');
  }

  /// Initialize voice search service with callbacks
  void _initializeVoiceSearch() {
    _voiceSearchService.onResult = (result) {
      setState(() {
        widget.controller.text = result;
        _voiceSearchError = '';
      });
      widget.onSearchChanged?.call();
      logUi('SearchPillRow: Voice search result - "$result"');
    };

    _voiceSearchService.onError = (error) {
      setState(() {
        _voiceSearchError = error;
        _isListening = false;
      });
      logUi('SearchPillRow: Voice search error - "$error"');
      _showVoiceSearchError(error);
    };

    _voiceSearchService.onListeningStateChanged = (isListening) {
      setState(() {
        _isListening = isListening;
      });
      logUi('SearchPillRow: Voice search listening - $isListening');
    };
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _voiceSearchService.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });

    if (_isFocused) {
      logUi('SearchPillRow: Search field focused');
    }
  }

  void _handleSearchChanged(String value) {
    logUi('SearchPillRow: Search query changed to "$value"');
    widget.onSearchChanged?.call();
  }

  String _getSearchPlaceholder() {
    // Contextual placeholder based on location
    // In real app, this could be dynamic based on current area
    final baseText = 'Search for meat products';

    if (widget.isTablet) {
      return '$baseText near your location...';
    }

    return '$baseText...';
  }

  /// Show voice search error to user
  void _showVoiceSearchError(String error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Handle voice search button tap
  Future<void> _handleVoiceSearchTap() async {
    if (_isListening) {
      // Stop listening if currently active
      await _voiceSearchService.stopListening();
      return;
    }

    try {
      logUi('SearchPillRow: Voice search button tapped');

      // Request microphone permission and start listening
      final success = await _voiceSearchService.startListening();

      if (!success) {
        _showVoiceSearchError(
          'Unable to start voice search. Please check microphone permissions.',
        );
      }
    } catch (e) {
      logUi('SearchPillRow: Voice search error - $e');
      _showVoiceSearchError('Voice search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const emeraldGreen = Color(0xFF059669);

    // Responsive sizing
    final pillHeight = widget.isTablet ? 48.0 : 44.0;
    final horizontalPadding = widget.isTablet ? 16.0 : 12.0;
    final iconSize = widget.isTablet ? 20.0 : 18.0;

    return Container(
      height: pillHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(
          pillHeight / 2,
        ), // Perfect pill shape
        border: Border.all(
          color: _isFocused
              ? emeraldGreen.withValues(alpha: 0.5)
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: _isFocused ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Search Icon
          Padding(
            padding: EdgeInsets.only(left: horizontalPadding),
            child: Icon(
              Icons.search,
              size: iconSize,
              color: _isFocused
                  ? emeraldGreen
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),

          const SizedBox(width: 12),

          // Center: Search TextField
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: _handleSearchChanged,
              style: TextStyle(
                fontSize: widget.isTablet ? 15 : 14,
                fontWeight: FontWeight.w400,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: _getSearchPlaceholder(),
                hintStyle: TextStyle(
                  fontSize: widget.isTablet ? 15 : 14,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                logUi('SearchPillRow: Search submitted with "$value"');
                _focusNode.unfocus();
              },
            ),
          ),

          // Right: Voice Search Icon (feature-flagged)
          if (widget.showVoiceSearch &&
              UiFlags.compactLocationHeaderEnabled) ...[
            const SizedBox(width: 8),
            _VoiceSearchButton(
              onTap: _handleVoiceSearchTap,
              iconSize: iconSize,
              isTablet: widget.isTablet,
              isListening: _isListening,
            ),
          ],

          SizedBox(width: horizontalPadding),
        ],
      ),
    );
  }
}

/// Voice search button component (feature-flagged)
class _VoiceSearchButton extends StatefulWidget {
  final Future<void> Function()? onTap;
  final double iconSize;
  final bool isTablet;
  final bool isListening;

  const _VoiceSearchButton({
    this.onTap,
    required this.iconSize,
    this.isTablet = false,
    this.isListening = false,
  });

  @override
  State<_VoiceSearchButton> createState() => _VoiceSearchButtonState();
}

class _VoiceSearchButtonState extends State<_VoiceSearchButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const emeraldGreen = Color(0xFF059669);
    const redColor = Color(0xFFDC2626);

    // Determine colors based on listening state
    final isActive = widget.isListening || _isPressed;
    final iconColor = widget.isListening
        ? redColor
        : (isActive
              ? emeraldGreen
              : theme.colorScheme.onSurface.withValues(alpha: 0.6));
    final bgColor = isActive
        ? (widget.isListening
              ? redColor.withValues(alpha: 0.1)
              : emeraldGreen.withValues(alpha: 0.1))
        : Colors.transparent;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        logUi(
          'SearchPillRow: Voice search tapped (listening: ${widget.isListening})',
        );
        await widget.onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: widget.isListening
              ? Border.all(color: redColor.withValues(alpha: 0.3), width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing animation when listening
            if (widget.isListening)
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                width: widget.isListening ? 28 : 20,
                height: widget.isListening ? 28 : 20,
                decoration: BoxDecoration(
                  color: redColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),

            // Microphone icon
            Icon(
              widget.isListening ? Icons.mic : Icons.mic_outlined,
              size: widget.iconSize,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Extension to add search-specific behavior
extension SearchPillBehavior on SearchPillRow {
  /// Focus the search field programmatically
  void focusSearch() {
    // This would be implemented if we need external focus control
  }

  /// Clear the search field
  void clearSearch() {
    // This would be implemented if we need external clear control
  }
}
