import 'package:flutter/foundation.dart';
import 'customer_notification_service.dart';

/// Phase 4I: Notification count caching service for performance optimization
/// Caches notification counts to avoid repeated API calls during development
class NotificationCountCache {
  static final NotificationCountCache _instance =
      NotificationCountCache._internal();
  factory NotificationCountCache() => _instance;
  NotificationCountCache._internal();

  final Map<String, _CacheEntry> _cache = {};
  final CustomerNotificationService _notificationService =
      CustomerNotificationService();

  // Cache duration: 5 minutes for development, can be adjusted
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get notification count with caching for performance
  Future<int> getNotificationCount(String customerId) async {
    final now = DateTime.now();
    final cacheKey = 'count_$customerId';

    // Check if we have a valid cached entry
    if (_cache.containsKey(cacheKey)) {
      final entry = _cache[cacheKey]!;
      if (now.difference(entry.timestamp) < _cacheDuration) {
        if (kDebugMode) {
          print(
            '🚀 PERFORMANCE: Using cached notification count: ${entry.count}',
          );
        }
        return entry.count;
      } else {
        // Cache expired
        _cache.remove(cacheKey);
        if (kDebugMode) {
          print(
            '🚀 PERFORMANCE: Notification count cache expired, refreshing...',
          );
        }
      }
    }

    // Fetch fresh count from API
    try {
      if (kDebugMode) {
        print('🚀 PERFORMANCE: Fetching fresh notification count...');
      }

      final count = await _notificationService.getUnreadNotificationCount(
        customerId,
      );

      // Cache the result
      _cache[cacheKey] = _CacheEntry(count: count, timestamp: now);

      if (kDebugMode) {
        print('🚀 PERFORMANCE: Cached notification count: $count');
      }

      return count;
    } catch (e) {
      if (kDebugMode) {
        print('❌ PERFORMANCE: Failed to fetch notification count: $e');
      }
      return 0;
    }
  }

  /// Invalidate cache for a specific customer (call when notifications are read)
  void invalidateCache(String customerId) {
    final cacheKey = 'count_$customerId';
    _cache.remove(cacheKey);
    if (kDebugMode) {
      print(
        '🚀 PERFORMANCE: Invalidated notification cache for customer: $customerId',
      );
    }
  }

  /// Clear all cached data
  void clearCache() {
    _cache.clear();
    if (kDebugMode) {
      print('🚀 PERFORMANCE: Cleared all notification count cache');
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
}

/// Internal cache entry structure
class _CacheEntry {
  final int count;
  final DateTime timestamp;

  _CacheEntry({required this.count, required this.timestamp});
}
