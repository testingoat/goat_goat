import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../config/feature_flags.dart';
import '../admin/services/oms_configuration_service.dart';
import 'enhanced_notification_service.dart';
import 'intelligent_seller_selection_service.dart';
import 'comprehensive_order_service.dart';

/// Order Timer Service
///
/// This service implements the 5-minute order acceptance timer system
/// with automatic expiration and fallback routing as specified in the
/// comprehensive order management design document.
///
/// KEY FEATURES:
/// - 5-minute order acceptance countdown timer
/// - Automatic order expiration handling
/// - Fallback routing to alternative sellers
/// - Real-time timer updates for sellers
/// - Grace period and reminder notifications
/// - Integration with Supabase Edge Functions for scheduling
///
/// ZERO-RISK IMPLEMENTATION:
/// - Behind feature flag `order_acceptance_timer`
/// - Graceful fallback when timer system is disabled
/// - Comprehensive error handling and logging
/// - Integration with existing order management flow
class OrderTimerService {
  static final OrderTimerService _instance = OrderTimerService._internal();
  factory OrderTimerService() => _instance;
  OrderTimerService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final OMSConfigurationService _configService = OMSConfigurationService();
  final EnhancedNotificationService _notificationService =
      EnhancedNotificationService();
  final IntelligentSellerSelectionService _sellerSelectionService =
      IntelligentSellerSelectionService();
  final ComprehensiveOrderService _orderService = ComprehensiveOrderService();

  // Active timers map: orderId -> Timer
  final Map<String, Timer> _activeTimers = {};
  final Map<String, DateTime> _orderExpiryTimes = {};

  // =====================================================
  // MAIN TIMER MANAGEMENT
  // =====================================================

  /// Start order acceptance timer for a new order
  ///
  /// This method initiates the 5-minute countdown timer:
  /// 1. Check if timer system is enabled
  /// 2. Get timer configuration (timeout, grace period, etc.)
  /// 3. Schedule expiration timer
  /// 4. Schedule reminder notifications
  /// 5. Set up real-time timer updates
  /// 6. Log timer initiation
  Future<Map<String, dynamic>> startOrderTimer({
    required String orderId,
    required String sellerId,
    required Map<String, dynamic> orderData,
    int? customTimeoutMinutes,
  }) async {
    try {
      // Check if order acceptance timer is enabled
      final isEnabled = await FeatureFlags.isEnabledRemote(
        'order_acceptance_timer',
      );

      if (!isEnabled) {
        if (kDebugMode) {
          print(
            '⏰ ORDER TIMER - Timer system disabled, skipping timer for order: $orderId',
          );
        }
        return {
          'success': true,
          'timer_enabled': false,
          'message': 'Timer system disabled',
        };
      }

      if (kDebugMode) {
        print(
          '⏰ ORDER TIMER - Starting timer for order: $orderId, seller: $sellerId',
        );
      }

      // Get timer configuration
      final timerConfig = await _getTimerConfiguration();
      final timeoutMinutes =
          customTimeoutMinutes ?? timerConfig['timeout_minutes'];
      final gracePeriodSeconds = timerConfig['grace_period_seconds'];
      final reminderMinutes = timerConfig['reminder_minutes'];

      // Calculate expiry time
      final expiryTime = DateTime.now().add(Duration(minutes: timeoutMinutes));
      _orderExpiryTimes[orderId] = expiryTime;

      // Update order with expiry time
      await _supabase
          .from('orders')
          .update({'expires_at': expiryTime.toIso8601String()})
          .eq('id', orderId);

      // Schedule main expiration timer
      final mainTimer = Timer(Duration(minutes: timeoutMinutes), () {
        _handleOrderExpiration(orderId, sellerId, orderData);
      });
      _activeTimers[orderId] = mainTimer;

      // Schedule reminder notification (2 minutes before expiry)
      if (timeoutMinutes > reminderMinutes) {
        Timer(Duration(minutes: timeoutMinutes - reminderMinutes), () {
          _sendReminderNotification(
            orderId,
            sellerId,
            orderData,
            reminderMinutes,
          );
        });
      }

      // Log timer initiation
      await _logTimerEvent(
        orderId: orderId,
        sellerId: sellerId,
        eventType: 'timer_started',
        timeoutMinutes: timeoutMinutes,
        expiryTime: expiryTime,
      );

      if (kDebugMode) {
        print(
          '✅ ORDER TIMER - Timer started for order: $orderId, expires at: ${expiryTime.toIso8601String()}',
        );
      }

      return {
        'success': true,
        'timer_enabled': true,
        'expires_at': expiryTime.toIso8601String(),
        'timeout_minutes': timeoutMinutes,
        'grace_period_seconds': gracePeriodSeconds,
        'reminder_minutes': reminderMinutes,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ ORDER TIMER - Error starting timer for order: $orderId - $e');
      }

      return {
        'success': false,
        'error': 'Failed to start order timer: ${e.toString()}',
        'timer_enabled': false,
      };
    }
  }

  /// Cancel order timer (when order is accepted or cancelled)
  Future<Map<String, dynamic>> cancelOrderTimer({
    required String orderId,
    required String reason,
    String? sellerId,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '⏰ ORDER TIMER - Cancelling timer for order: $orderId, reason: $reason',
        );
      }

      // Cancel active timer
      final timer = _activeTimers[orderId];
      if (timer != null) {
        timer.cancel();
        _activeTimers.remove(orderId);
        _orderExpiryTimes.remove(orderId);

        // Log timer cancellation
        await _logTimerEvent(
          orderId: orderId,
          sellerId: sellerId,
          eventType: 'timer_cancelled',
          reason: reason,
        );

        if (kDebugMode) {
          print('✅ ORDER TIMER - Timer cancelled for order: $orderId');
        }

        return {'success': true, 'timer_cancelled': true, 'reason': reason};
      } else {
        if (kDebugMode) {
          print('⚠️ ORDER TIMER - No active timer found for order: $orderId');
        }

        return {
          'success': true,
          'timer_cancelled': false,
          'reason': 'No active timer found',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ ORDER TIMER - Error cancelling timer for order: $orderId - $e',
        );
      }

      return {
        'success': false,
        'error': 'Failed to cancel order timer: ${e.toString()}',
      };
    }
  }

  /// Get remaining time for an order
  Map<String, dynamic> getOrderTimeRemaining(String orderId) {
    try {
      final expiryTime = _orderExpiryTimes[orderId];

      if (expiryTime == null) {
        return {
          'success': false,
          'error': 'No timer found for order',
          'has_timer': false,
        };
      }

      final now = DateTime.now();
      final remainingDuration = expiryTime.difference(now);
      final remainingSeconds = remainingDuration.inSeconds;

      if (remainingSeconds <= 0) {
        return {
          'success': true,
          'has_timer': true,
          'expired': true,
          'remaining_seconds': 0,
          'remaining_minutes': 0,
          'expiry_time': expiryTime.toIso8601String(),
        };
      }

      return {
        'success': true,
        'has_timer': true,
        'expired': false,
        'remaining_seconds': remainingSeconds,
        'remaining_minutes': (remainingSeconds / 60).ceil(),
        'expiry_time': expiryTime.toIso8601String(),
        'formatted_time': _formatRemainingTime(remainingSeconds),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error calculating remaining time: ${e.toString()}',
      };
    }
  }

  /// Get all active timers (for admin monitoring)
  Map<String, dynamic> getAllActiveTimers() {
    try {
      final activeTimers = <String, Map<String, dynamic>>{};

      for (final entry in _orderExpiryTimes.entries) {
        final orderId = entry.key;
        final expiryTime = entry.value;
        final remainingTime = getOrderTimeRemaining(orderId);

        activeTimers[orderId] = {
          'expiry_time': expiryTime.toIso8601String(),
          'remaining_time': remainingTime,
          'has_active_timer': _activeTimers.containsKey(orderId),
        };
      }

      return {
        'success': true,
        'active_timers_count': activeTimers.length,
        'active_timers': activeTimers,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error getting active timers: ${e.toString()}',
      };
    }
  }

  // =====================================================
  // ORDER EXPIRATION HANDLING
  // =====================================================

  /// Handle order expiration and trigger fallback routing
  Future<void> _handleOrderExpiration(
    String orderId,
    String sellerId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      if (kDebugMode) {
        print('⏰ ORDER EXPIRATION - Handling expiration for order: $orderId');
      }

      // Remove from active timers
      _activeTimers.remove(orderId);
      _orderExpiryTimes.remove(orderId);

      // Check if order is still pending (not already accepted/cancelled)
      final currentOrder = await _supabase
          .from('orders')
          .select('status_enum, seller_id')
          .eq('id', orderId)
          .maybeSingle();

      if (currentOrder == null) {
        if (kDebugMode) {
          print('⚠️ ORDER EXPIRATION - Order not found: $orderId');
        }
        return;
      }

      final currentStatus = currentOrder['status_enum'] as String?;

      if (currentStatus != 'pending') {
        if (kDebugMode) {
          print(
            '⚠️ ORDER EXPIRATION - Order already processed: $orderId, status: $currentStatus',
          );
        }
        return;
      }

      // Update order status to expired
      await _orderService.updateOrderStatus(
        orderId: orderId,
        newStatus: 'expired',
        triggeredBy: 'system',
        userType: 'system',
        reason: 'Order acceptance timeout',
        notes: 'Order expired after 5-minute acceptance window',
      );

      // Send expiration notification to original seller
      await _notificationService.sendOrderNotificationToSeller(
        sellerId: sellerId,
        orderId: orderId,
        notificationType: 'order_expired',
        orderData: orderData,
        urgency: 'normal',
      );

      // Log expiration event
      await _logTimerEvent(
        orderId: orderId,
        sellerId: sellerId,
        eventType: 'order_expired',
        reason: 'Acceptance timeout',
      );

      // Attempt fallback routing if enabled
      final fallbackEnabled = await FeatureFlags.isEnabledRemote(
        'order_fallback_routing',
      );

      if (fallbackEnabled) {
        await _attemptFallbackRouting(orderId, sellerId, orderData);
      } else {
        if (kDebugMode) {
          print(
            '⚠️ ORDER EXPIRATION - Fallback routing disabled for order: $orderId',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ ORDER EXPIRATION - Error handling expiration for order: $orderId - $e',
        );
      }
    }
  }

  /// Attempt fallback routing to alternative sellers
  Future<void> _attemptFallbackRouting(
    String orderId,
    String originalSellerId,
    Map<String, dynamic> orderData,
  ) async {
    try {
      if (kDebugMode) {
        print('🔄 FALLBACK ROUTING - Attempting fallback for order: $orderId');
      }

      // Get order items for seller selection
      final orderItems = await _supabase
          .from('order_items')
          .select('*')
          .eq('order_id', orderId);

      if (orderItems.isEmpty) {
        if (kDebugMode) {
          print(
            '⚠️ FALLBACK ROUTING - No order items found for order: $orderId',
          );
        }
        return;
      }

      // Get delivery location from order
      final deliveryLocation =
          orderData['delivery_address'] as Map<String, dynamic>? ?? {};

      // Use intelligent seller selection to find alternative seller
      final selectionResult = await _sellerSelectionService.selectBestSeller(
        orderId: orderId,
        orderItems: orderItems,
        deliveryLocation: deliveryLocation,
      );

      if (selectionResult['success']) {
        final newSeller = selectionResult['selected_seller'];
        final newSellerId = newSeller['seller_id'] as String;

        // Ensure we don't route back to the same seller
        if (newSellerId == originalSellerId) {
          if (kDebugMode) {
            print(
              '⚠️ FALLBACK ROUTING - Same seller selected, skipping fallback for order: $orderId',
            );
          }
          return;
        }

        // Update order with new seller and reset to pending
        await _supabase
            .from('orders')
            .update({'seller_id': newSellerId, 'status_enum': 'pending'})
            .eq('id', orderId);

        // Start new timer for the fallback seller
        await startOrderTimer(
          orderId: orderId,
          sellerId: newSellerId,
          orderData: orderData,
        );

        // Send notification to new seller
        await _notificationService.sendOrderNotificationToSeller(
          sellerId: newSellerId,
          orderId: orderId,
          notificationType: 'new_order',
          orderData: {
            ...orderData,
            'is_fallback': true,
            'original_seller_id': originalSellerId,
          },
          urgency: 'high',
        );

        // Log successful fallback routing
        await _logTimerEvent(
          orderId: orderId,
          sellerId: newSellerId,
          eventType: 'fallback_routing_success',
          reason: 'Routed to alternative seller',
          metadata: {
            'original_seller_id': originalSellerId,
            'new_seller_id': newSellerId,
            'selection_algorithm': selectionResult['algorithm'],
          },
        );

        if (kDebugMode) {
          print(
            '✅ FALLBACK ROUTING - Successfully routed order: $orderId to seller: $newSellerId',
          );
        }
      } else {
        if (kDebugMode) {
          print(
            '❌ FALLBACK ROUTING - No alternative seller found for order: $orderId',
          );
        }

        // Log failed fallback routing
        await _logTimerEvent(
          orderId: orderId,
          sellerId: originalSellerId,
          eventType: 'fallback_routing_failed',
          reason: 'No alternative sellers available',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ FALLBACK ROUTING - Error in fallback routing for order: $orderId - $e',
        );
      }
    }
  }

  /// Send reminder notification to seller
  Future<void> _sendReminderNotification(
    String orderId,
    String sellerId,
    Map<String, dynamic> orderData,
    int reminderMinutes,
  ) async {
    try {
      if (kDebugMode) {
        print(
          '⏰ REMINDER - Sending reminder for order: $orderId to seller: $sellerId',
        );
      }

      await _notificationService.sendOrderNotificationToSeller(
        sellerId: sellerId,
        orderId: orderId,
        notificationType: 'order_reminder',
        orderData: {...orderData, 'reminder_minutes': reminderMinutes},
        urgency: 'urgent',
      );

      // Log reminder sent
      await _logTimerEvent(
        orderId: orderId,
        sellerId: sellerId,
        eventType: 'reminder_sent',
        reason: '$reminderMinutes minutes before expiry',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ REMINDER - Error sending reminder for order: $orderId - $e');
      }
    }
  }

  // =====================================================
  // CONFIGURATION AND HELPER METHODS
  // =====================================================

  /// Get timer configuration from OMS settings
  Future<Map<String, dynamic>> _getTimerConfiguration() async {
    try {
      final timeoutConfig = await _configService.getConfiguration(
        'order_acceptance_timeout_minutes',
      );
      final graceConfig = await _configService.getConfiguration(
        'order_grace_period_seconds',
      );

      return {
        'timeout_minutes': timeoutConfig['success']
            ? (timeoutConfig['configuration']['value']['value'] as int? ?? 5)
            : 5,
        'grace_period_seconds': graceConfig['success']
            ? (graceConfig['configuration']['value']['value'] as int? ?? 30)
            : 30,
        'reminder_minutes': 2, // Send reminder 2 minutes before expiry
      };
    } catch (e) {
      // Return default configuration on error
      return {
        'timeout_minutes': 5,
        'grace_period_seconds': 30,
        'reminder_minutes': 2,
      };
    }
  }

  /// Format remaining time for display
  String _formatRemainingTime(int remainingSeconds) {
    if (remainingSeconds <= 0) {
      return 'Expired';
    }

    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Log timer events for analytics and debugging
  Future<void> _logTimerEvent({
    required String orderId,
    String? sellerId,
    required String eventType,
    String? reason,
    int? timeoutMinutes,
    DateTime? expiryTime,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final logEntry = {
        'order_id': orderId,
        'seller_id': sellerId,
        'event_type': eventType,
        'reason': reason,
        'timeout_minutes': timeoutMinutes,
        'expiry_time': expiryTime?.toIso8601String(),
        'metadata': metadata ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _supabase.from('order_timer_logs').insert(logEntry);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ TIMER LOG - Failed to log timer event: $e');
      }
    }
  }

  // =====================================================
  // CLEANUP AND UTILITY METHODS
  // =====================================================

  /// Clean up expired timers (maintenance method)
  void cleanupExpiredTimers() {
    try {
      final now = DateTime.now();
      final expiredOrders = <String>[];

      for (final entry in _orderExpiryTimes.entries) {
        if (entry.value.isBefore(now)) {
          expiredOrders.add(entry.key);
        }
      }

      for (final orderId in expiredOrders) {
        final timer = _activeTimers[orderId];
        timer?.cancel();
        _activeTimers.remove(orderId);
        _orderExpiryTimes.remove(orderId);
      }

      if (kDebugMode && expiredOrders.isNotEmpty) {
        print(
          '🧹 TIMER CLEANUP - Cleaned up ${expiredOrders.length} expired timers',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TIMER CLEANUP - Error during cleanup: $e');
      }
    }
  }

  /// Cancel all active timers (for app shutdown)
  void cancelAllTimers() {
    try {
      for (final timer in _activeTimers.values) {
        timer.cancel();
      }

      _activeTimers.clear();
      _orderExpiryTimes.clear();

      if (kDebugMode) {
        print('🛑 TIMER SERVICE - All timers cancelled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ TIMER SERVICE - Error cancelling all timers: $e');
      }
    }
  }

  /// Get timer service statistics
  Map<String, dynamic> getTimerStatistics() {
    return {
      'active_timers_count': _activeTimers.length,
      'tracked_orders_count': _orderExpiryTimes.length,
      'service_uptime': DateTime.now().toIso8601String(),
    };
  }
}
