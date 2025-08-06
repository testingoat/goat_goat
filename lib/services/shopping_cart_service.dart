import 'package:supabase_flutter/supabase_flutter.dart';
import 'delivery_fee_service.dart';

class ShoppingCartService {
  static final ShoppingCartService _instance = ShoppingCartService._internal();
  factory ShoppingCartService() => _instance;
  ShoppingCartService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  /// Add product to cart
  Future<Map<String, dynamic>> addToCart({
    required String customerId,
    required String productId,
    required int quantity,
    required double unitPrice,
  }) async {
    try {
      print(
        '🛒 ADD TO CART - Customer: $customerId, Product: $productId, Qty: $quantity',
      );

      // Check if item already exists in cart
      final existingItem = await _supabase
          .from('shopping_cart')
          .select()
          .eq('customer_id', customerId)
          .eq('product_id', productId)
          .maybeSingle();

      if (existingItem != null) {
        // Update existing item quantity
        final newQuantity = existingItem['quantity'] + quantity;
        await _supabase
            .from('shopping_cart')
            .update({
              'quantity': newQuantity,
              'unit_price': unitPrice, // Update price in case it changed
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingItem['id']);

        print(
          '✅ ADD TO CART - Updated existing item, new quantity: $newQuantity',
        );

        return {
          'success': true,
          'message': 'Cart updated successfully',
          'action': 'updated',
          'new_quantity': newQuantity,
        };
      } else {
        // Add new item to cart
        await _supabase.from('shopping_cart').insert({
          'customer_id': customerId,
          'product_id': productId,
          'quantity': quantity,
          'unit_price': unitPrice,
        });

        print('✅ ADD TO CART - Added new item to cart');

        return {
          'success': true,
          'message': 'Product added to cart',
          'action': 'added',
          'quantity': quantity,
        };
      }
    } catch (e) {
      print('❌ ADD TO CART - Error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Failed to add product to cart',
        'error': e.toString(),
      };
    }
  }

  /// Get cart items for customer
  Future<List<Map<String, dynamic>>> getCartItems(String customerId) async {
    try {
      print('🛒 GET CART - Loading cart for customer: $customerId');

      final cartItems = await _supabase
          .from('shopping_cart')
          .select('''
            *,
            meat_products(
              id,
              name,
              price,
              description,
              sellers(seller_name)
            )
          ''')
          .eq('customer_id', customerId)
          .order('added_at', ascending: false);

      print('✅ GET CART - Found ${cartItems.length} items');
      return cartItems;
    } catch (e) {
      print('❌ GET CART - Error: ${e.toString()}');
      return [];
    }
  }

  /// Update cart item quantity
  Future<Map<String, dynamic>> updateCartQuantity({
    required String customerId,
    required String productId,
    required int quantity,
  }) async {
    try {
      print(
        '🛒 UPDATE CART - Customer: $customerId, Product: $productId, New Qty: $quantity',
      );

      if (quantity <= 0) {
        // Remove item if quantity is 0 or negative
        await _supabase
            .from('shopping_cart')
            .delete()
            .eq('customer_id', customerId)
            .eq('product_id', productId);

        print('✅ UPDATE CART - Removed item from cart');

        return {
          'success': true,
          'message': 'Item removed from cart',
          'action': 'removed',
        };
      } else {
        // Update quantity
        await _supabase
            .from('shopping_cart')
            .update({
              'quantity': quantity,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('customer_id', customerId)
            .eq('product_id', productId);

        print('✅ UPDATE CART - Updated quantity to $quantity');

        return {
          'success': true,
          'message': 'Cart updated successfully',
          'action': 'updated',
          'new_quantity': quantity,
        };
      }
    } catch (e) {
      print('❌ UPDATE CART - Error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Failed to update cart',
        'error': e.toString(),
      };
    }
  }

  /// Remove item from cart
  Future<Map<String, dynamic>> removeFromCart({
    required String customerId,
    required String productId,
  }) async {
    try {
      print('🛒 REMOVE FROM CART - Customer: $customerId, Product: $productId');

      await _supabase
          .from('shopping_cart')
          .delete()
          .eq('customer_id', customerId)
          .eq('product_id', productId);

      print('✅ REMOVE FROM CART - Item removed successfully');

      return {'success': true, 'message': 'Item removed from cart'};
    } catch (e) {
      print('❌ REMOVE FROM CART - Error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Failed to remove item from cart',
        'error': e.toString(),
      };
    }
  }

  /// Clear entire cart
  Future<Map<String, dynamic>> clearCart(String customerId) async {
    try {
      print('🛒 CLEAR CART - Customer: $customerId');

      await _supabase
          .from('shopping_cart')
          .delete()
          .eq('customer_id', customerId);

      print('✅ CLEAR CART - Cart cleared successfully');

      return {'success': true, 'message': 'Cart cleared successfully'};
    } catch (e) {
      print('❌ CLEAR CART - Error: ${e.toString()}');
      return {
        'success': false,
        'message': 'Failed to clear cart',
        'error': e.toString(),
      };
    }
  }

  /// Get cart summary (total items, total price)
  Future<Map<String, dynamic>> getCartSummary(String customerId) async {
    try {
      final cartItems = await getCartItems(customerId);

      int totalItems = 0;
      double totalPrice = 0.0;

      for (final item in cartItems) {
        final quantity = item['quantity'] as int;
        final unitPrice = (item['unit_price'] as num).toDouble();

        totalItems += quantity;
        totalPrice += quantity * unitPrice;
      }

      return {
        'success': true,
        'total_items': totalItems,
        'total_price': totalPrice,
        'item_count': cartItems.length,
      };
    } catch (e) {
      print('❌ GET CART SUMMARY - Error: ${e.toString()}');
      return {
        'success': false,
        'total_items': 0,
        'total_price': 0.0,
        'item_count': 0,
      };
    }
  }

  // ===== PHASE 3A.2 - DELIVERY FEE INTEGRATION =====

  /// Get cart summary with delivery fee calculation
  ///
  /// This method extends the existing getCartSummary functionality to include
  /// delivery fee calculations based on customer address and order subtotal.
  ///
  /// Maintains 100% backward compatibility - existing getCartSummary() method
  /// remains unchanged for any code that depends on the original structure.
  Future<Map<String, dynamic>> getCartSummaryWithDelivery({
    required String customerId,
    String? deliveryAddress,
  }) async {
    try {
      print('🛒 GET CART SUMMARY WITH DELIVERY - Customer: $customerId');

      // Get basic cart summary first (preserves existing functionality)
      final basicSummary = await getCartSummary(customerId);

      if (!basicSummary['success']) {
        return basicSummary; // Return original error if basic summary fails
      }

      final subtotal = basicSummary['total_price'] as double;
      final totalItems = basicSummary['total_items'] as int;
      final itemCount = basicSummary['item_count'] as int;

      // If no delivery address provided, return basic summary with zero delivery fee
      if (deliveryAddress == null || deliveryAddress.trim().isEmpty) {
        print(
          '⚠️ CART SUMMARY - No delivery address provided, delivery fee set to 0',
        );
        return {
          'success': true,
          'total_items': totalItems,
          'item_count': itemCount,
          'subtotal': subtotal,
          'delivery_fee': 0.0,
          'delivery_fee_details': {
            'calculated': false,
            'reason': 'no_address_provided',
          },
          'total_price': subtotal, // Total = subtotal when no delivery fee
        };
      }

      // Calculate delivery fee
      print('📍 CART SUMMARY - Calculating delivery fee for: $deliveryAddress');
      final deliveryResult = await _deliveryFeeService.calculateDeliveryFee(
        customerAddress: deliveryAddress,
        orderSubtotal: subtotal,
      );

      double deliveryFee = 0.0;
      Map<String, dynamic> deliveryDetails = {
        'calculated': false,
        'reason': 'calculation_failed',
      };

      if (deliveryResult['success']) {
        deliveryFee = deliveryResult['fee'] as double;
        deliveryDetails = {
          'calculated': true,
          'distance_km': deliveryResult['distance_km'],
          'tier': deliveryResult['tier'],
          'config_name': deliveryResult['config_name'],
          'method': 'admin_configuration',
        };

        // Add additional details if available
        if (deliveryResult['reason'] != null) {
          deliveryDetails['reason'] = deliveryResult['reason'];
        }
        if (deliveryResult['applied_multipliers'] != null) {
          deliveryDetails['applied_multipliers'] =
              deliveryResult['applied_multipliers'];
        }

        print(
          '✅ CART SUMMARY - Delivery fee calculated: ₹${deliveryFee.toStringAsFixed(0)}',
        );
      } else {
        print(
          '⚠️ CART SUMMARY - Delivery fee calculation failed: ${deliveryResult['error']}',
        );
        deliveryDetails['error'] = deliveryResult['error'];
      }

      final totalPrice = subtotal + deliveryFee;

      return {
        'success': true,
        'total_items': totalItems,
        'item_count': itemCount,
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'delivery_fee_details': deliveryDetails,
        'total_price': totalPrice, // Total = subtotal + delivery fee
      };
    } catch (e) {
      print('❌ GET CART SUMMARY WITH DELIVERY - Error: ${e.toString()}');

      // Fallback to basic summary on error
      final basicSummary = await getCartSummary(customerId);
      if (basicSummary['success']) {
        return {
          'success': true,
          'total_items': basicSummary['total_items'],
          'item_count': basicSummary['item_count'],
          'subtotal': basicSummary['total_price'],
          'delivery_fee': 0.0,
          'delivery_fee_details': {
            'calculated': false,
            'reason': 'calculation_error',
            'error': e.toString(),
          },
          'total_price': basicSummary['total_price'],
        };
      } else {
        return basicSummary; // Return original error
      }
    }
  }

  /// Check if location is serviceable for delivery
  ///
  /// This method provides a quick way to check if delivery is available
  /// to a specific address before showing delivery options to customers.
  Future<bool> isDeliveryAvailable(String address) async {
    try {
      if (address.trim().isEmpty) return false;
      return await _deliveryFeeService.isLocationServiceable(address);
    } catch (e) {
      print('❌ DELIVERY AVAILABILITY CHECK - Error: ${e.toString()}');
      return false;
    }
  }
}
