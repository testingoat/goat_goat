import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingCartService {
  static final ShoppingCartService _instance = ShoppingCartService._internal();
  factory ShoppingCartService() => _instance;
  ShoppingCartService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Add product to cart
  Future<Map<String, dynamic>> addToCart({
    required String customerId,
    required String productId,
    required int quantity,
    required double unitPrice,
  }) async {
    try {
      print('🛒 ADD TO CART - Customer: $customerId, Product: $productId, Qty: $quantity');

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

        print('✅ ADD TO CART - Updated existing item, new quantity: $newQuantity');
        
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
      print('🛒 UPDATE CART - Customer: $customerId, Product: $productId, New Qty: $quantity');

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
      
      return {
        'success': true,
        'message': 'Item removed from cart',
      };
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
      
      return {
        'success': true,
        'message': 'Cart cleared successfully',
      };
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
}
