import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/maps_config.dart';

/// Simple data models for Places API responses
class PlacePrediction {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']?['main_text'],
      secondaryText: json['structured_formatting']?['secondary_text'],
    );
  }
}

class PlaceDetailsResult {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final List<String> types;

  PlaceDetailsResult({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.types,
  });

  factory PlaceDetailsResult.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'];
    final location = geometry?['location'];

    return PlaceDetailsResult(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      formattedAddress: json['formatted_address'] ?? '',
      latitude: (location?['lat'] ?? 0.0).toDouble(),
      longitude: (location?['lng'] ?? 0.0).toDouble(),
      types: List<String>.from(json['types'] ?? []),
    );
  }
}

/// PlacesService - Isolated service for Google Places API integration
///
/// This service provides Places API functionality without coupling to existing business logic.
/// It handles address search, autocomplete, and place details fetching.
///
/// Features:
/// - Address autocomplete with session tokens
/// - Place details fetching with coordinates
/// - In-memory caching with TTL for performance
/// - Rate limiting to prevent quota bursts
/// - Error handling and graceful degradation
/// - Integration with existing LocationService patterns
class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  // API configuration
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String _apiKey =
      'AIzaSyDOBBimUu_eGMwsXZUqrNFk3puT5rMWbig'; // Your API key

  // Cache for autocomplete results
  final Map<String, List<PlacePrediction>> _autocompleteCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, PlaceDetailsResult> _placeDetailsCache = {};

  // Cache configuration
  static const int _cacheTTLMinutes = 10;
  static const int _maxCacheSize = 100;
  static const int _rateLimitDelayMs = 300;

  // Rate limiting
  DateTime? _lastRequestTime;

  /// Get autocomplete suggestions for address search
  ///
  /// Returns list of address predictions based on user input
  /// Uses caching and rate limiting for optimal performance
  Future<List<PlacePrediction>> getAutocompleteSuggestions({
    required String query,
    String? sessionToken,
    String countryCode = 'IN', // Default to India
  }) async {
    try {
      // Return empty list for very short queries
      if (query.length < 2) {
        return [];
      }

      // Check cache first
      final cacheKey = '${query.toLowerCase()}_$countryCode';
      if (_isCacheValid(cacheKey)) {
        final cachedResults = _autocompleteCache[cacheKey];
        if (cachedResults != null) {
          if (kDebugMode) {
            print('🔍 Places autocomplete cache hit for: $query');
          }
          return cachedResults;
        }
      }

      // Apply rate limiting
      await _applyRateLimit();

      if (kDebugMode) {
        print('🔍 Places autocomplete API call for: $query');
      }

      // Make HTTP API call to Places Autocomplete
      final url = Uri.parse('$_baseUrl/autocomplete/json');
      final response = await http.get(
        url.replace(
          queryParameters: {
            'input': query,
            'key': _apiKey,
            'sessiontoken': sessionToken ?? _generateSessionToken(),
            'types': 'address',
            'components': 'country:$countryCode',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final predictions = (data['predictions'] as List)
          .map((p) => PlacePrediction.fromJson(p))
          .toList();

      // Cache the results
      _cacheAutocompleteResults(cacheKey, predictions);

      if (kDebugMode) {
        print('✅ Places autocomplete returned ${predictions.length} results');
      }

      return predictions;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in Places autocomplete: $e');
      }
      return [];
    }
  }

  /// Get detailed information for a specific place
  ///
  /// Returns place details including coordinates and formatted address
  /// Uses caching to minimize API calls
  Future<PlaceDetailsResult?> getPlaceDetails({
    required String placeId,
    String? sessionToken,
  }) async {
    try {
      // Check cache first
      if (_placeDetailsCache.containsKey(placeId)) {
        if (kDebugMode) {
          print('📍 Place details cache hit for: $placeId');
        }
        return _placeDetailsCache[placeId];
      }

      // Apply rate limiting
      await _applyRateLimit();

      if (kDebugMode) {
        print('📍 Place details API call for: $placeId');
      }

      // Make HTTP API call to Place Details
      final url = Uri.parse('$_baseUrl/details/json');
      final response = await http.get(
        url.replace(
          queryParameters: {
            'place_id': placeId,
            'key': _apiKey,
            'sessiontoken': sessionToken ?? _generateSessionToken(),
            'fields': 'place_id,name,formatted_address,geometry,types',
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('API request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final result = data['result'];
      if (result == null) {
        return null;
      }

      final placeDetails = PlaceDetailsResult.fromJson(result);

      // Cache the result
      _placeDetailsCache[placeId] = placeDetails;

      // Limit cache size
      if (_placeDetailsCache.length > _maxCacheSize) {
        final firstKey = _placeDetailsCache.keys.first;
        _placeDetailsCache.remove(firstKey);
      }

      if (kDebugMode) {
        print('✅ Place details retrieved for: ${placeDetails.name}');
      }

      return placeDetails;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting place details: $e');
      }
      return null;
    }
  }

  /// Convert place details to location data format
  ///
  /// Returns standardized location data compatible with existing LocationService
  Map<String, dynamic>? placeDetailsToLocationData(
    PlaceDetailsResult placeDetails,
  ) {
    try {
      return {
        'latitude': placeDetails.latitude,
        'longitude': placeDetails.longitude,
        'address': placeDetails.formattedAddress.isNotEmpty
            ? placeDetails.formattedAddress
            : placeDetails.name,
        'place_id': placeDetails.placeId,
        'name': placeDetails.name,
        'types': placeDetails.types,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error converting place details: $e');
      }
      return null;
    }
  }

  /// Save searched address to customer profile
  ///
  /// Extends existing JSONB structure with searched addresses
  Future<bool> saveSearchedAddress({
    required String customerId,
    required Map<String, dynamic> locationData,
  }) async {
    try {
      // This would integrate with existing LocationService or SupabaseService
      // For now, we'll just log the action
      if (kDebugMode) {
        print('💾 Saving searched address for customer: $customerId');
        print('📍 Address: ${locationData['address']}');
      }

      // TODO: Integrate with existing customer data saving
      // This should extend the delivery_addresses JSONB field with:
      // "searched_addresses": [locationData, ...]

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving searched address: $e');
      }
      return false;
    }
  }

  /// Clear all caches
  void clearCache() {
    _autocompleteCache.clear();
    _cacheTimestamps.clear();
    _placeDetailsCache.clear();

    if (kDebugMode) {
      print('🧹 Places service cache cleared');
    }
  }

  /// Check if cached result is still valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;

    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < _cacheTTLMinutes;
  }

  /// Cache autocomplete results with timestamp
  void _cacheAutocompleteResults(
    String cacheKey,
    List<PlacePrediction> results,
  ) {
    _autocompleteCache[cacheKey] = results;
    _cacheTimestamps[cacheKey] = DateTime.now();

    // Limit cache size
    if (_autocompleteCache.length > _maxCacheSize) {
      final firstKey = _autocompleteCache.keys.first;
      _autocompleteCache.remove(firstKey);
      _cacheTimestamps.remove(firstKey);
    }
  }

  /// Apply rate limiting to prevent quota bursts
  Future<void> _applyRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest.inMilliseconds < _rateLimitDelayMs) {
        final delayNeeded =
            _rateLimitDelayMs - timeSinceLastRequest.inMilliseconds;
        await Future.delayed(Duration(milliseconds: delayNeeded));
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Generate session token for Places API
  String _generateSessionToken() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Check if Places API is available and configured
  bool isAvailable() {
    // This would check if API key is configured and Places API is enabled
    // For now, we'll return true if the feature flag is enabled
    return kEnablePlacesAutocomplete;
  }

  /// Get recent search suggestions from cache
  List<PlacePrediction> getRecentSearches({int limit = 5}) {
    final allCachedResults = <PlacePrediction>[];

    for (final results in _autocompleteCache.values) {
      allCachedResults.addAll(results);
    }

    // Remove duplicates and limit results
    final uniqueResults = <String, PlacePrediction>{};
    for (final prediction in allCachedResults) {
      uniqueResults[prediction.placeId] = prediction;
    }

    final recentSearches = uniqueResults.values.toList();
    if (recentSearches.length > limit) {
      return recentSearches.sublist(0, limit);
    }

    return recentSearches;
  }
}
