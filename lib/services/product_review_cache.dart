import 'package:flutter/foundation.dart';

/// Phase 4I: Product review caching service to prevent excessive API calls
/// Caches product review stats to avoid repeated API calls during scrolling
class ProductReviewCache {
  static final ProductReviewCache _instance = ProductReviewCache._internal();
  factory ProductReviewCache() => _instance;
  ProductReviewCache._internal();

  final Map<String, _ReviewCacheEntry> _cache = {};
  
  // Cache duration: 10 minutes for product reviews
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// Get cached review stats or return null if not cached/expired
  Map<String, dynamic>? getCachedReviewStats(String productId) {
    final now = DateTime.now();
    final cacheKey = 'review_$productId';
    
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (now.difference(entry.timestamp) < _cacheDuration) {
        if (kDebugMode) {
          print('🚀 PERFORMANCE: Using cached review stats for product: $productId');
        }
        return entry.stats;
      } else {
        // Cache expired
        _cache.remove(cacheKey);
        if (kDebugMode) {
          print('🚀 PERFORMANCE: Review cache expired for product: $productId');
        }
      }
    }
    
    return null;
  }

  /// Cache review stats for a product
  void cacheReviewStats(String productId, Map<String, dynamic> stats) {
    final now = DateTime.now();
    final cacheKey = 'review_$productId';
    
    _cache[cacheKey] = _ReviewCacheEntry(stats: stats, timestamp: now);
    
    if (kDebugMode) {
      print('🚀 PERFORMANCE: Cached review stats for product: $productId');
    }
  }

  /// Clear cache for a specific product (call when reviews are updated)
  void invalidateProduct(String productId) {
    final cacheKey = 'review_$productId';
    _cache.remove(cacheKey);
    if (kDebugMode) {
      print('🚀 PERFORMANCE: Invalidated review cache for product: $productId');
    }
  }

  /// Clear all cached data
  void clearCache() {
    _cache.clear();
    if (kDebugMode) {
      print('🚀 PERFORMANCE: Cleared all product review cache');
    }
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int validEntries = 0;
    int expiredEntries = 0;
    
    for (final entry in _cache.values) {
      if (now.difference(entry.timestamp) < _cacheDuration) {
        validEntries++;
      } else {
        expiredEntries++;
      }
    }
    
    return {
      'total_entries': _cache.length,
      'valid_entries': validEntries,
      'expired_entries': expiredEntries,
      'cache_duration_minutes': _cacheDuration.inMinutes,
    };
  }

  /// Batch cache multiple product reviews (for initial load)
  void batchCacheReviews(Map<String, Map<String, dynamic>> reviewsMap) {
    final now = DateTime.now();
    
    reviewsMap.forEach((productId, stats) {
      final cacheKey = 'review_$productId';
      _cache[cacheKey] = _ReviewCacheEntry(stats: stats, timestamp: now);
    });
    
    if (kDebugMode) {
      print('🚀 PERFORMANCE: Batch cached ${reviewsMap.length} product reviews');
    }
  }
}

/// Internal cache entry structure
class _ReviewCacheEntry {
  final Map<String, dynamic> stats;
  final DateTime timestamp;
  
  _ReviewCacheEntry({required this.stats, required this.timestamp});
}
