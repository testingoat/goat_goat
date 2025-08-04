import 'package:flutter/material.dart';
import '../services/places_service.dart';

/// AddressSearchWidget - Optional search component for location selection
///
/// This widget provides address search functionality that enhances the existing
/// tap-to-select location flow. Features:
/// - Real-time autocomplete suggestions
/// - Recent searches display
/// - Smooth animations and transitions
/// - Follows app's emerald color scheme
/// - Graceful error handling and fallbacks
/// - Zero impact on existing location selection
class AddressSearchWidget extends StatefulWidget {
  final Function(Map<String, dynamic>) onSelectSuggestion;
  final String? initialQuery;
  final String? hintText;

  const AddressSearchWidget({
    super.key,
    required this.onSelectSuggestion,
    this.initialQuery,
    this.hintText,
  });

  @override
  State<AddressSearchWidget> createState() => _AddressSearchWidgetState();
}

class _AddressSearchWidgetState extends State<AddressSearchWidget>
    with SingleTickerProviderStateMixin {
  final PlacesService _placesService = PlacesService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<PlacePrediction> _suggestions = [];
  List<PlacePrediction> _recentSearches = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Session token for Places API
  String? _sessionToken;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Set initial query if provided
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }

    // Load recent searches
    _loadRecentSearches();

    // Listen to focus changes
    _focusNode.addListener(_onFocusChange);

    // Generate session token
    _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Handle focus changes to show/hide suggestions
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showSuggestionsPanel();
    } else {
      // Delay hiding to allow for suggestion selection
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focusNode.hasFocus) {
          _hideSuggestionsPanel();
        }
      });
    }
  }

  /// Show suggestions panel with animation
  void _showSuggestionsPanel() {
    if (!_showSuggestions) {
      setState(() {
        _showSuggestions = true;
      });
      _animationController.forward();
    }
  }

  /// Hide suggestions panel with animation
  void _hideSuggestionsPanel() {
    if (_showSuggestions) {
      _animationController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _showSuggestions = false;
          });
        }
      });
    }
  }

  /// Load recent searches from cache
  void _loadRecentSearches() {
    try {
      final recentSearches = _placesService.getRecentSearches(limit: 3);
      setState(() {
        _recentSearches = recentSearches;
      });
    } catch (e) {
      // Silently handle error - recent searches are optional
    }
  }

  /// Handle search query changes
  void _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final suggestions = await _placesService.getAutocompleteSuggestions(
        query: query.trim(),
        sessionToken: _sessionToken,
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
          _errorMessage = 'Search temporarily unavailable';
        });
      }
    }
  }

  /// Handle suggestion selection
  void _onSuggestionSelected(PlacePrediction prediction) async {
    // Hide suggestions and clear focus
    _hideSuggestionsPanel();
    _focusNode.unfocus();

    // Update search field
    setState(() {
      _searchController.text = prediction.description;
      _isLoading = true;
    });

    try {
      // Get place details
      final placeDetails = await _placesService.getPlaceDetails(
        placeId: prediction.placeId,
        sessionToken: _sessionToken,
      );

      if (placeDetails != null) {
        // Convert to location data
        final locationData = _placesService.placeDetailsToLocationData(
          placeDetails,
        );

        if (locationData != null) {
          // Notify parent widget
          widget.onSelectSuggestion(locationData);

          // Generate new session token for next search
          _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
        }
      }
    } catch (e) {
      // Show error but don't block user
      setState(() {
        _errorMessage = 'Unable to get location details';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search input field
        _buildSearchField(),

        // Suggestions panel
        if (_showSuggestions) _buildSuggestionsPanel(),
      ],
    );
  }

  /// Build search input field
  Widget _buildSearchField() {
    return Container(
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
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search for an address...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF059669),
            size: 20,
          ),
          suffixIcon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF059669),
                      ),
                    ),
                  ),
                )
              : _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: const TextStyle(fontSize: 14),
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }

  /// Build suggestions panel
  Widget _buildSuggestionsPanel() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
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
          children: [
            // Error message
            if (_errorMessage != null) _buildErrorMessage(),

            // Recent searches (when no query)
            if (_searchController.text.trim().isEmpty &&
                _recentSearches.isNotEmpty)
              _buildRecentSearches(),

            // Search suggestions
            if (_suggestions.isNotEmpty) _buildSuggestionsList(),

            // Empty state
            if (_suggestions.isEmpty &&
                _searchController.text.trim().isNotEmpty &&
                !_isLoading &&
                _errorMessage == null)
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  /// Build error message
  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[600], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.orange[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// Build recent searches section
  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Recent Searches',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        ..._recentSearches.map(
          (prediction) => _buildSuggestionTile(prediction),
        ),
      ],
    );
  }

  /// Build suggestions list
  Widget _buildSuggestionsList() {
    return Column(
      children: _suggestions
          .map((prediction) => _buildSuggestionTile(prediction))
          .toList(),
    );
  }

  /// Build individual suggestion tile
  Widget _buildSuggestionTile(PlacePrediction prediction) {
    return InkWell(
      onTap: () => _onSuggestionSelected(prediction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.grey[600], size: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.mainText ?? prediction.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (prediction.secondaryText != null)
                    Text(
                      prediction.secondaryText!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Text(
        'No addresses found',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
    );
  }
}
