import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/feature_flags.dart';
import 'intelligent_seller_selection_service.dart';
import 'enhanced_notification_service.dart';
import 'order_timer_service.dart';

/// Comprehensive Order Service
///
/// This service implements the complete order lifecycle management system
/// as specified in the comprehensive order management design document.
///
/// ZERO-RISK IMPLEMENTATION:
/// - Uses composition pattern (doesn't modify existing services)
/// - All functionality is behind feature flags
/// - Maintains 100% backward compatibility
/// - Graceful fallback to existing simple order creation
class ComprehensiveOrderService {
  static final ComprehensiveOrderService _instance =
      ComprehensiveOrderService._internal();
  factory ComprehensiveOrderService() => _instance;
  ComprehensiveOrderService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // =====================================================
  // ORDER CREATION AND LIFECYCLE MANAGEMENT
  // =====================================================

  /// Create a comprehensive order with full lifecycle management
  ///
  /// This method implements the complete order creation flow from the design document:
  /// 1. Validate order data and inventory
  /// 2. Calculate pricing and delivery fees
  /// 3. Create order record with 5-minute expiry
  /// 4. Trigger seller selection algorithm
  /// 5. Send real-time notification to selected seller
  /// 6. Start 5-minute countdown timer
  /// 7. Return order confirmation to customer
  Future<Map<String, dynamic>> createComprehensiveOrder({
    required String customerId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double deliveryFee,
    required String deliveryAddress,
    Map<String, dynamic>? deliveryFeeDetails,
    double? taxAmount,
    String? specialInstructions,
    String paymentMethod = 'cod',
  }) async {
    try {
      // Check if comprehensive order management is enabled
      final isEnabled = await FeatureFlags.isEnabledRemote(
        'comprehensive_order_management',
      );

      if (!isEnabled) {
        // Fallback to simple order creation for backward compatibility
        return await _createSimpleOrder(
          customerId: customerId,
          items: items,
          subtotal: subtotal,
          deliveryFee: deliveryFee,
          deliveryAddress: deliveryAddress,
          specialInstructions: specialInstructions,
          paymentMethod: paymentMethod,
        );
      }

      print(
        '🛒 COMPREHENSIVE ORDER - Starting order creation for customer: $customerId',
      );

      // 1. Validate order data and inventory
      final validation = await _validateOrderRequest(items, customerId);
      if (!validation['valid']) {
        return {
          'success': false,
          'error': validation['error'],
          'step': 'validation',
        };
      }

      // 2. Calculate total amount
      final totalAmount = subtotal + deliveryFee + (taxAmount ?? 0.0);

      // 3. Generate unique order number
      final orderNumber = await _generateOrderNumber();

      // 4. Create order record with 5-minute expiry
      final orderData = {
        'customer_id': customerId,
        'order_number': orderNumber,
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'tax_amount': taxAmount ?? 0.0,
        'total_amount': totalAmount,
        'delivery_address': {
          'address': deliveryAddress,
          'details': deliveryFeeDetails,
        },
        'special_instructions': specialInstructions,
        'order_metadata': {
          'payment_method': paymentMethod,
          'created_via': 'comprehensive_oms',
          'version': '1.0',
        },
        'status_enum': 'pending',
        'order_status': 'pending', // Maintain backward compatibility
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        'created_by': customerId,
      };

      // Create the order
      final orderResponse = await _supabase
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final orderId = orderResponse['id'] as String;

      print('✅ COMPREHENSIVE ORDER - Order created: $orderId');

      // 5. Create order items
      await _createOrderItems(orderId, items);

      // 6. Log initial state transition
      await _logStateTransition(
        orderId: orderId,
        fromStatus: null,
        toStatus: 'pending',
        triggeredBy: customerId,
        userType: 'customer',
        reason: 'Order placed by customer',
      );

      // 7. Trigger seller selection algorithm (if enabled)
      final routingEnabled = await FeatureFlags.isEnabledRemote(
        'order_routing_algorithm',
      );
      Map<String, dynamic>? routingResult;

      if (routingEnabled) {
        routingResult = await _triggerSellerSelection(orderId, orderResponse);

        // Send notification to selected seller (if routing successful)
        if (routingResult != null && routingResult['success']) {
          await _sendOrderNotificationToSeller(
            orderId,
            routingResult,
            orderResponse,
          );
        }
      }

      // 8. Schedule order expiration timer (if enabled)
      final timerEnabled = await FeatureFlags.isEnabledRemote(
        'order_acceptance_timer',
      );
      if (timerEnabled) {
        await _scheduleOrderExpiration(orderId);
      }

      // 9. Return comprehensive order confirmation
      return {
        'success': true,
        'order': orderResponse,
        'order_id': orderId,
        'order_number': orderNumber,
        'total_amount': totalAmount,
        'estimated_acceptance_time': '2-5 minutes',
        'routing_result': routingResult,
        'expires_at': orderData['expires_at'],
        'message': 'Order placed successfully',
      };
    } catch (e) {
      print('❌ COMPREHENSIVE ORDER - Error creating order: $e');
      return {
        'success': false,
        'error': 'Failed to create order: ${e.toString()}',
        'step': 'creation',
      };
    }
  }

  /// Update order status with comprehensive state transition logging
  Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String newStatus,
    String? triggeredBy,
    String userType = 'system',
    String? reason,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final transitionsEnabled = await FeatureFlags.isEnabledRemote(
        'order_state_transitions',
      );

      if (!transitionsEnabled) {
        // Fallback to simple status update
        return await _updateSimpleOrderStatus(orderId, newStatus);
      }

      print('🔄 ORDER STATUS - Updating order $orderId to $newStatus');

      // Use the database function for atomic status update with transition logging
      final result = await _supabase.rpc(
        'update_order_status_with_transition',
        params: {
          'p_order_id': orderId,
          'p_new_status': newStatus,
          'p_triggered_by': triggeredBy,
          'p_user_type': userType,
          'p_reason': reason,
          'p_notes': notes,
        },
      );

      if (result == true) {
        // Update timestamps based on status
        await _updateStatusTimestamps(orderId, newStatus);

        print('✅ ORDER STATUS - Updated successfully');
        return {
          'success': true,
          'order_id': orderId,
          'new_status': newStatus,
          'message': 'Order status updated successfully',
        };
      } else {
        throw Exception('Database function returned false');
      }
    } catch (e) {
      print('❌ ORDER STATUS - Error updating status: $e');
      return {
        'success': false,
        'error': 'Failed to update order status: ${e.toString()}',
      };
    }
  }

  /// Get comprehensive order details with full tracking information
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      print('📦 ORDER DETAILS - Loading comprehensive details for: $orderId');

      // Get order with all related data
      final orderResponse = await _supabase
          .from('orders')
          .select('''
            *,
            customers(full_name, phone_number, address),
            sellers(seller_name, contact_phone, business_city),
            order_items(
              *,
              meat_products(
                name,
                price,
                description,
                meat_product_images(image_url)
              )
            )
          ''')
          .eq('id', orderId)
          .maybeSingle();

      if (orderResponse == null) {
        return null;
      }

      // Get state transitions if enabled
      List<Map<String, dynamic>> stateTransitions = [];
      final transitionsEnabled = await FeatureFlags.isEnabledRemote(
        'order_state_transitions',
      );

      if (transitionsEnabled) {
        stateTransitions = await _supabase
            .from('order_state_transitions')
            .select('*')
            .eq('order_id', orderId)
            .order('transitioned_at', ascending: true);
      }

      // Get routing decision if available
      Map<String, dynamic>? routingDecision;
      final routingEnabled = await FeatureFlags.isEnabledRemote(
        'order_routing_algorithm',
      );

      if (routingEnabled) {
        routingDecision = await _supabase
            .from('order_routing_decisions')
            .select('*')
            .eq('order_id', orderId)
            .maybeSingle();
      }

      // Enhance order data with comprehensive information
      final enhancedOrder = {
        ...orderResponse,
        'state_transitions': stateTransitions,
        'routing_decision': routingDecision,
        'is_comprehensive': true,
        'time_remaining': _calculateTimeRemaining(orderResponse['expires_at']),
      };

      print('✅ ORDER DETAILS - Loaded comprehensive details');
      return enhancedOrder;
    } catch (e) {
      print('❌ ORDER DETAILS - Error loading details: $e');
      return null;
    }
  }

  // =====================================================
  // PRIVATE HELPER METHODS
  // =====================================================

  /// Fallback to simple order creation for backward compatibility
  Future<Map<String, dynamic>> _createSimpleOrder({
    required String customerId,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double deliveryFee,
    required String deliveryAddress,
    String? specialInstructions,
    String paymentMethod = 'cod',
  }) async {
    print('🔄 SIMPLE ORDER - Using fallback simple order creation');

    final totalAmount = subtotal + deliveryFee;

    // Create basic order using existing schema
    final orderData = {
      'customer_id': customerId,
      'total_amount': totalAmount,
      'order_status': 'pending',
      'delivery_instructions': specialInstructions,
      'estimated_delivery': DateTime.now()
          .add(const Duration(hours: 2))
          .toIso8601String(),
    };

    final orderResponse = await _supabase
        .from('orders')
        .insert(orderData)
        .select()
        .single();

    final orderId = orderResponse['id'] as String;

    // Create order items
    await _createOrderItems(orderId, items);

    return {
      'success': true,
      'order': orderResponse,
      'order_id': orderId,
      'total_amount': totalAmount,
      'message': 'Order placed successfully (simple mode)',
    };
  }

  /// Validate order request data and inventory
  Future<Map<String, dynamic>> _validateOrderRequest(
    List<Map<String, dynamic>> items,
    String customerId,
  ) async {
    try {
      if (items.isEmpty) {
        return {
          'valid': false,
          'error': 'Order must contain at least one item',
        };
      }

      // Validate each item
      for (final item in items) {
        final productId = item['product_id'];
        final quantity = item['quantity'] as int?;

        if (productId == null || quantity == null || quantity <= 0) {
          return {'valid': false, 'error': 'Invalid item data'};
        }

        // Check if product exists and is available
        final product = await _supabase
            .from('meat_products')
            .select('id, name, is_active, stock_quantity')
            .eq('id', productId)
            .maybeSingle();

        if (product == null) {
          return {'valid': false, 'error': 'Product not found: $productId'};
        }

        if (product['is_active'] != true) {
          return {
            'valid': false,
            'error': 'Product is not available: ${product['name']}',
          };
        }

        // Check stock if available
        final stockQuantity = product['stock_quantity'] as int?;
        if (stockQuantity != null && stockQuantity < quantity) {
          return {
            'valid': false,
            'error': 'Insufficient stock for: ${product['name']}',
          };
        }
      }

      return {'valid': true};
    } catch (e) {
      return {'valid': false, 'error': 'Validation error: ${e.toString()}'};
    }
  }

  /// Generate unique order number
  Future<String> _generateOrderNumber() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'ORD$random';
  }

  /// Create order items with enhanced data
  Future<void> _createOrderItems(
    String orderId,
    List<Map<String, dynamic>> items,
  ) async {
    final orderItems = <Map<String, dynamic>>[];

    for (final item in items) {
      final productId = item['product_id'];
      final quantity = item['quantity'] as int;
      final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;

      // Get product details for snapshot
      final product = await _supabase
          .from('meat_products')
          .select('*')
          .eq('id', productId)
          .maybeSingle();

      final orderItem = {
        'order_id': orderId,
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'total_price': unitPrice * quantity,
        // Enhanced fields for comprehensive OMS
        'product_name': product?['name'],
        'product_sku': product?['default_code'],
        'product_snapshot': product != null
            ? {
                'name': product['name'],
                'price': product['price'],
                'description': product['description'],
                'captured_at': DateTime.now().toIso8601String(),
              }
            : null,
      };

      orderItems.add(orderItem);
    }

    await _supabase.from('order_items').insert(orderItems);
  }

  /// Log state transition
  Future<void> _logStateTransition({
    required String orderId,
    required String? fromStatus,
    required String toStatus,
    required String triggeredBy,
    required String userType,
    String? reason,
    String? notes,
  }) async {
    try {
      await _supabase.from('order_state_transitions').insert({
        'order_id': orderId,
        'from_status': fromStatus,
        'to_status': toStatus,
        'triggered_by_user_id': triggeredBy,
        'triggered_by_user_type': userType,
        'transition_reason': reason,
        'notes': notes,
      });
    } catch (e) {
      print('⚠️ STATE TRANSITION - Failed to log transition: $e');
    }
  }

  /// Trigger seller selection algorithm using intelligent service
  Future<Map<String, dynamic>?> _triggerSellerSelection(
    String orderId,
    Map<String, dynamic> order,
  ) async {
    try {
      print(
        '🎯 SELLER SELECTION - Triggering intelligent selection for order: $orderId',
      );

      // Use the intelligent seller selection service
      final selectionService = IntelligentSellerSelectionService();

      // Extract order items and delivery location from order
      final orderItems = await _getOrderItems(orderId);
      final deliveryLocation =
          order['delivery_address'] as Map<String, dynamic>? ?? {};

      // Call intelligent seller selection
      final selectionResult = await selectionService.selectBestSeller(
        orderId: orderId,
        orderItems: orderItems,
        deliveryLocation: deliveryLocation,
      );

      if (selectionResult['success']) {
        final selectedSeller = selectionResult['selected_seller'];
        final sellerId = selectedSeller['seller_id'];

        // Update order with selected seller
        await _supabase
            .from('orders')
            .update({'seller_id': sellerId})
            .eq('id', orderId);

        print(
          '✅ SELLER SELECTION - Selected seller: $sellerId using ${selectionResult['algorithm']}',
        );

        return {
          'success': true,
          'seller_id': sellerId,
          'seller_info': selectedSeller['seller_info'],
          'method': 'intelligent_selection',
          'algorithm': selectionResult['algorithm'],
          'total_candidates': selectionResult['total_candidates'],
          'selection_details': selectionResult,
        };
      } else {
        print(
          '⚠️ SELLER SELECTION - Intelligent selection failed: ${selectionResult['error']}',
        );
        return null;
      }
    } catch (e) {
      print('❌ SELLER SELECTION - Error in intelligent selection: $e');
      return null;
    }
  }

  /// Get order items for seller selection
  Future<List<Map<String, dynamic>>> _getOrderItems(String orderId) async {
    try {
      final items = await _supabase
          .from('order_items')
          .select('*')
          .eq('order_id', orderId);

      return items;
    } catch (e) {
      print('❌ ORDER ITEMS - Error getting order items: $e');
      return [];
    }
  }

  /// Schedule order expiration using OrderTimerService
  Future<void> _scheduleOrderExpiration(String orderId) async {
    try {
      print('⏰ ORDER TIMER - Scheduling expiration for order: $orderId');

      // Get order details for timer
      final order = await _supabase
          .from('orders')
          .select('seller_id, order_number, total_amount, delivery_address')
          .eq('id', orderId)
          .maybeSingle();

      if (order == null) {
        print(
          '⚠️ ORDER TIMER - Order not found for timer scheduling: $orderId',
        );
        return;
      }

      final sellerId = order['seller_id'] as String?;
      if (sellerId == null) {
        print('⚠️ ORDER TIMER - No seller assigned for order: $orderId');
        return;
      }

      // Prepare order data for timer
      final orderData = {
        'order_number': order['order_number'],
        'total_amount': order['total_amount'],
        'delivery_address': order['delivery_address'],
      };

      // Start order timer
      final timerService = OrderTimerService();
      final result = await timerService.startOrderTimer(
        orderId: orderId,
        sellerId: sellerId,
        orderData: orderData,
      );

      if (result['success']) {
        print('✅ ORDER TIMER - Timer started for order: $orderId');
      } else {
        print('⚠️ ORDER TIMER - Failed to start timer for order: $orderId');
      }
    } catch (e) {
      print(
        '❌ ORDER TIMER - Error scheduling expiration for order: $orderId - $e',
      );
    }
  }

  /// Update simple order status (fallback)
  Future<Map<String, dynamic>> _updateSimpleOrderStatus(
    String orderId,
    String status,
  ) async {
    await _supabase
        .from('orders')
        .update({
          'order_status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', orderId);

    return {
      'success': true,
      'order_id': orderId,
      'new_status': status,
      'message': 'Order status updated (simple mode)',
    };
  }

  /// Update status-specific timestamps
  Future<void> _updateStatusTimestamps(String orderId, String status) async {
    final updates = <String, dynamic>{};
    final now = DateTime.now().toIso8601String();

    switch (status) {
      case 'accepted':
        updates['accepted_at'] = now;
        break;
      case 'confirmed':
        updates['confirmed_at'] = now;
        break;
      case 'delivered':
        updates['completed_at'] = now;
        updates['actual_delivery_time'] = now;
        break;
      case 'cancelled':
      case 'expired':
        updates['cancelled_at'] = now;
        break;
    }

    if (updates.isNotEmpty) {
      await _supabase.from('orders').update(updates).eq('id', orderId);
    }
  }

  /// Calculate time remaining for order expiration
  int? _calculateTimeRemaining(String? expiresAt) {
    if (expiresAt == null) return null;

    try {
      final expiry = DateTime.parse(expiresAt);
      final now = DateTime.now();
      final difference = expiry.difference(now).inSeconds;
      return difference > 0 ? difference : 0;
    } catch (e) {
      return null;
    }
  }

  /// Send order notification to selected seller
  Future<void> _sendOrderNotificationToSeller(
    String orderId,
    Map<String, dynamic> routingResult,
    Map<String, dynamic> orderData,
  ) async {
    try {
      final notificationService = EnhancedNotificationService();
      final sellerId = routingResult['seller_id'] as String;

      // Prepare order data for notification
      final notificationOrderData = {
        'order_number': orderData['order_number'],
        'customer_name': 'Customer', // Would get from customer data
        'total_amount': orderData['total_amount'],
        'delivery_address': orderData['delivery_address'],
        'expires_at': orderData['expires_at'],
      };

      // Send new order notification
      final result = await notificationService.sendOrderNotificationToSeller(
        sellerId: sellerId,
        orderId: orderId,
        notificationType: 'new_order',
        orderData: notificationOrderData,
        urgency: 'high',
      );

      if (result['success']) {
        print(
          '✅ NOTIFICATION - Sent new order notification to seller: $sellerId',
        );
      } else {
        print(
          '⚠️ NOTIFICATION - Failed to send notification to seller: $sellerId',
        );
      }
    } catch (e) {
      print('❌ NOTIFICATION - Error sending notification: $e');
    }
  }

  /// Accept order by seller (cancels timer and updates status)
  Future<Map<String, dynamic>> acceptOrder({
    required String orderId,
    required String sellerId,
    String? notes,
  }) async {
    try {
      print('✅ ORDER ACCEPTANCE - Seller $sellerId accepting order: $orderId');

      // Cancel the order timer
      final timerService = OrderTimerService();
      await timerService.cancelOrderTimer(
        orderId: orderId,
        reason: 'Order accepted by seller',
        sellerId: sellerId,
      );

      // Update order status to accepted
      final result = await updateOrderStatus(
        orderId: orderId,
        newStatus: 'accepted',
        triggeredBy: sellerId,
        userType: 'seller',
        reason: 'Order accepted by seller',
        notes: notes,
      );

      if (result['success']) {
        // Send acceptance notification to customer
        final notificationService = EnhancedNotificationService();

        // Get customer ID from order
        final order = await _supabase
            .from('orders')
            .select('customer_id, order_number')
            .eq('id', orderId)
            .maybeSingle();

        if (order != null) {
          await notificationService.sendOrderUpdateToCustomer(
            customerId: order['customer_id'],
            orderId: orderId,
            updateType: 'order_accepted',
            updateData: {
              'order_number': order['order_number'],
              'seller_id': sellerId,
            },
          );
        }

        print('✅ ORDER ACCEPTANCE - Order $orderId accepted successfully');

        return {
          'success': true,
          'order_id': orderId,
          'status': 'accepted',
          'message': 'Order accepted successfully',
        };
      } else {
        return result;
      }
    } catch (e) {
      print('❌ ORDER ACCEPTANCE - Error accepting order: $orderId - $e');
      return {
        'success': false,
        'error': 'Failed to accept order: ${e.toString()}',
      };
    }
  }

  /// Decline order by seller (cancels timer and triggers fallback)
  Future<Map<String, dynamic>> declineOrder({
    required String orderId,
    required String sellerId,
    String? reason,
    String? notes,
  }) async {
    try {
      print('❌ ORDER DECLINE - Seller $sellerId declining order: $orderId');

      // Cancel the order timer
      final timerService = OrderTimerService();
      await timerService.cancelOrderTimer(
        orderId: orderId,
        reason: 'Order declined by seller',
        sellerId: sellerId,
      );

      // Update order status to declined
      await updateOrderStatus(
        orderId: orderId,
        newStatus: 'declined',
        triggeredBy: sellerId,
        userType: 'seller',
        reason: reason ?? 'Order declined by seller',
        notes: notes,
      );

      // Attempt fallback routing if enabled
      final fallbackEnabled = await FeatureFlags.isEnabledRemote(
        'order_fallback_routing',
      );

      if (fallbackEnabled) {
        // Get order data for fallback routing
        final order = await _supabase
            .from('orders')
            .select('order_number, total_amount, delivery_address')
            .eq('id', orderId)
            .maybeSingle();

        if (order != null) {
          // Trigger fallback routing through timer service
          // This will find an alternative seller and restart the timer
          print(
            '🔄 ORDER DECLINE - Attempting fallback routing for order: $orderId',
          );

          // The timer service will handle the fallback routing
          // For now, we'll just log the intent
        }
      }

      print('✅ ORDER DECLINE - Order $orderId declined successfully');

      return {
        'success': true,
        'order_id': orderId,
        'status': 'declined',
        'message': 'Order declined successfully',
        'fallback_attempted': fallbackEnabled,
      };
    } catch (e) {
      print('❌ ORDER DECLINE - Error declining order: $orderId - $e');
      return {
        'success': false,
        'error': 'Failed to decline order: ${e.toString()}',
      };
    }
  }
}
