import 'package:flutter/material.dart';
import '../services/shopping_cart_service.dart';
import '../config/feature_flags.dart';

/// Customer Shopping Cart Screen
///
/// This screen provides customers with a complete shopping cart experience
/// including viewing cart items, updating quantities, and proceeding to checkout.
///
/// Key features:
/// - View all cart items with product details
/// - Update item quantities or remove items
/// - Cart summary with totals
/// - Checkout functionality (placeholder for future payment integration)
/// - Follows existing emerald theme and design patterns
class CustomerShoppingCartScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerShoppingCartScreen({Key? key, required this.customer})
    : super(key: key);

  @override
  State<CustomerShoppingCartScreen> createState() =>
      _CustomerShoppingCartScreenState();
}

class _CustomerShoppingCartScreenState
    extends State<CustomerShoppingCartScreen> {
  final ShoppingCartService _cartService = ShoppingCartService();

  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic>? _cartSummary;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCartItems();

    // Log feature usage
    FeatureFlags.logFeatureUsage('shopping_cart', 'screen_opened');
  }

  /// Load cart items and summary
  Future<void> _loadCartItems() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final customerId = widget.customer['id'] as String;

      // Load cart items and summary concurrently
      final results = await Future.wait([
        _cartService.getCartItems(customerId),
        _cartService.getCartSummary(customerId),
      ]);

      setState(() {
        _cartItems = results[0] as List<Map<String, dynamic>>;
        _cartSummary = results[1] as Map<String, dynamic>;
        _isLoading = false;
      });

      print('🛒 CART - Loaded ${_cartItems.length} items for customer');
    } catch (e) {
      print('❌ CART - Error loading data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load cart. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _cartItems.isNotEmpty ? _buildCheckoutBar() : null,
    );
  }

  /// Build app bar with green theme
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Shopping Cart',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.green[600],
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (_cartItems.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _showClearCartDialog,
            tooltip: 'Clear Cart',
          ),
      ],
    );
  }

  /// Build main body content
  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_cartItems.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadCartItems,
      color: Colors.green[600],
      child: Column(
        children: [
          // Cart summary
          if (_cartSummary != null) _buildCartSummary(),

          // Cart items list
          Expanded(child: _buildCartItemsList()),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your cart...',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadCartItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty cart state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Your Cart is Empty',
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some delicious products to get started',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build cart summary
  Widget _buildCartSummary() {
    final summary = _cartSummary!;
    final totalItems = summary['total_items'] as int? ?? 0;
    final totalPrice = summary['total_price'] as double? ?? 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green[200]!.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cart Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalItems items',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Text(
            '₹${totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build cart items list
  Widget _buildCartItemsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        return _buildCartItemCard(item);
      },
    );
  }

  /// Build individual cart item card
  Widget _buildCartItemCard(Map<String, dynamic> item) {
    final productName =
        item['meat_products']?['name'] as String? ?? 'Unknown Product';
    final quantity = item['quantity'] as int? ?? 0;
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final totalPrice = quantity * unitPrice;
    final productImages =
        item['meat_products']?['meat_product_images'] as List? ?? [];
    final imageUrl = productImages.isNotEmpty
        ? productImages[0]['image_url']
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[200]!,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.image_not_supported,
                            color: Colors.grey[400],
                          );
                        },
                      ),
                    )
                  : Icon(Icons.fastfood, color: Colors.grey[400]),
            ),
            const SizedBox(width: 12),

            // Product details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${unitPrice.toStringAsFixed(0)} per unit',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Quantity controls
                      Row(
                        children: [
                          IconButton(
                            onPressed: () =>
                                _updateQuantity(item, quantity - 1),
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red[600],
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                _updateQuantity(item, quantity + 1),
                            icon: const Icon(Icons.add_circle_outline),
                            color: Colors.green[600],
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),

                      // Total price
                      Text(
                        '₹${totalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build checkout bar
  Widget _buildCheckoutBar() {
    final totalPrice = _cartSummary?['total_price'] as double? ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  '₹${totalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _proceedToCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Checkout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Update item quantity
  Future<void> _updateQuantity(
    Map<String, dynamic> item,
    int newQuantity,
  ) async {
    if (newQuantity <= 0) {
      _removeItem(item);
      return;
    }

    try {
      final customerId = widget.customer['id'] as String;
      final productId = item['product_id'] as String;

      final result = await _cartService.updateCartQuantity(
        customerId: customerId,
        productId: productId,
        quantity: newQuantity,
      );

      if (result['success']) {
        await _loadCartItems(); // Refresh cart

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quantity updated to $newQuantity'),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 1),
          ),
        );
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update quantity: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  /// Remove item from cart
  Future<void> _removeItem(Map<String, dynamic> item) async {
    try {
      final customerId = widget.customer['id'] as String;
      final productId = item['product_id'] as String;

      final result = await _cartService.removeFromCart(
        customerId: customerId,
        productId: productId,
      );

      if (result['success']) {
        await _loadCartItems(); // Refresh cart

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Item removed from cart'),
            backgroundColor: Colors.orange[600],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove item: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  /// Show clear cart confirmation dialog
  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearCart();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );
  }

  /// Clear entire cart
  Future<void> _clearCart() async {
    try {
      final customerId = widget.customer['id'] as String;

      final result = await _cartService.clearCart(customerId);

      if (result['success']) {
        await _loadCartItems(); // Refresh cart

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cart cleared successfully'),
            backgroundColor: Colors.orange[600],
          ),
        );
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear cart: $e'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  /// Proceed to checkout (placeholder for future payment integration)
  void _proceedToCheckout() {
    FeatureFlags.logFeatureUsage('shopping_cart', 'checkout_initiated');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Checkout'),
        content: const Text(
          'Checkout functionality will be implemented in the next phase. '
          'This will include payment processing, order creation, and delivery scheduling.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
