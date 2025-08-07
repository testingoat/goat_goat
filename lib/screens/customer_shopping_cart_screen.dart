import 'dart:async';
import 'package:flutter/material.dart';
import '../services/shopping_cart_service.dart';
import '../supabase_service.dart';
import '../config/feature_flags.dart';
import '../services/delivery_address_state.dart';
import '../services/delivery_error_notification_service.dart';
import '../widgets/address_picker.dart';
import 'customer_checkout_screen.dart';

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
  final bool
  hideBackButton; // Phase 4D: Hide back button when accessed from app shell

  const CustomerShoppingCartScreen({
    super.key,
    required this.customer,
    this.hideBackButton = false,
  });

  @override
  State<CustomerShoppingCartScreen> createState() =>
      _CustomerShoppingCartScreenState();
}

class _CustomerShoppingCartScreenState
    extends State<CustomerShoppingCartScreen> {
  final ShoppingCartService _cartService = ShoppingCartService();
  final SupabaseService _supabaseService = SupabaseService();

  List<Map<String, dynamic>> _cartItems = [];
  Map<String, dynamic>? _cartSummary;
  bool _isLoading = true;
  String? _errorMessage;

  // Phase 3A.2 - Delivery Fee Integration
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  String? _deliveryAddress;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeCartWithAddress();

    // Log feature usage
    FeatureFlags.logFeatureUsage('shopping_cart', 'screen_opened');
  }

  /// Initialize cart with proper address loading sequence
  Future<void> _initializeCartWithAddress() async {
    // First load customer address, then load cart with delivery fee calculation
    await _loadCustomerAddress();
    await _loadCartItems();
  }

  /// Load cart items and summary
  Future<void> _loadCartItems() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      final customerId = widget.customer['id'] as String;

      // Load cart items and summary with delivery fee calculation
      final results = await Future.wait([
        _cartService.getCartItems(customerId),
        _cartService.getCartSummaryWithDelivery(
          customerId: customerId,
          deliveryAddress: _deliveryAddress,
        ),
      ]);

      if (mounted) {
        setState(() {
          _cartItems = results[0] as List<Map<String, dynamic>>;
          _cartSummary = results[1] as Map<String, dynamic>;
          _isLoading = false;
        });
      }

      print('🛒 CART - Loaded ${_cartItems.length} items for customer');
    } catch (e) {
      print('❌ CART - Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load cart. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Debounce cart reload to avoid too many API calls when typing address
  void _debounceCartReload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _loadCartItems();
    });
  }

  /// Validate address and show appropriate notifications
  void _validateAndNotifyAddress(String address) {
    // Check if address is too short or incomplete
    if (address.length < 5) {
      DeliveryErrorNotificationService.showDeliveryError(
        context,
        errorType: 'incomplete_address',
        customMessage: 'Please enter a complete address',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    // Check if address looks like just a city code (like "bhm")
    if (address.length <= 10 &&
        !address.contains(' ') &&
        !address.contains(',')) {
      DeliveryErrorNotificationService.showDeliveryError(
        context,
        errorType: 'incomplete_address',
        customMessage: 'Please enter full address with area details',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Address looks reasonable - no immediate notification needed
    // Delivery fee calculation will handle further validation
  }

  /// Load customer's primary address to auto-populate delivery address field
  Future<void> _loadCustomerAddress() async {
    try {
      final customerId = widget.customer['id'] as String;

      // Initialize shared address state from customer data
      DeliveryAddressState.initializeFromCustomer(widget.customer);

      // Check if shared state already has an address for this customer
      if (DeliveryAddressState.hasAddress() &&
          DeliveryAddressState.belongsToCustomer(customerId)) {
        final sharedAddress = DeliveryAddressState.getCurrentAddress();
        if (sharedAddress != null) {
          if (mounted) {
            setState(() {
              _deliveryAddress = sharedAddress;
              _deliveryAddressController.text = sharedAddress;
            });
          }
          print(
            '✅ CART - Using shared state address: ${sharedAddress.length > 50 ? '${sharedAddress.substring(0, 50)}...' : sharedAddress}',
          );
          _debounceCartReload();
          return;
        }
      }

      // First try to get address from customer data passed to screen
      String? primaryAddress = widget.customer['address'] as String?;

      // If not available, fetch from database
      if (primaryAddress == null || primaryAddress.trim().isEmpty) {
        final customerResponse = await _supabaseService.getCustomerById(
          customerId,
        );
        if (customerResponse['success']) {
          final customer = customerResponse['customer'];
          primaryAddress = customer['address'] as String?;

          // Also check delivery_addresses for primary address
          if (primaryAddress == null || primaryAddress.trim().isEmpty) {
            final deliveryAddresses =
                customer['delivery_addresses'] as Map<String, dynamic>?;
            if (deliveryAddresses != null) {
              // Look for default address in delivery_addresses array
              final addressList = deliveryAddresses['saved_addresses'] as List?;
              if (addressList != null && addressList.isNotEmpty) {
                for (final addr in addressList) {
                  if (addr['is_default'] == true || addr['isPrimary'] == true) {
                    primaryAddress = addr['address'] as String?;
                    break;
                  }
                }
                // If no default found, use the first address
                if (primaryAddress == null || primaryAddress.trim().isEmpty) {
                  primaryAddress = addressList.first['address'] as String?;
                }
              }
            }
          }
        }
      }

      // Auto-populate the address field if we found an address
      if (primaryAddress != null && primaryAddress.trim().isNotEmpty) {
        if (mounted) {
          setState(() {
            _deliveryAddress = primaryAddress;
            _deliveryAddressController.text = primaryAddress!;
          });
        }

        print(
          '✅ CART - Auto-populated delivery address: ${primaryAddress.substring(0, 50)}...',
        );

        // Trigger initial delivery fee calculation
        _debounceCartReload();
      } else {
        print('⚠️ CART - No primary address found for customer');
      }
    } catch (e) {
      print('❌ CART - Error loading customer address: $e');
      // Don't show error to user, just continue without auto-population
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
      // Phase 4D: Conditionally hide back button when accessed from app shell
      leading: widget.hideBackButton
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
      automaticallyImplyLeading: !widget.hideBackButton,
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
          // Cart items list
          Expanded(child: _buildCartItemsList()),

          // Cart summary at bottom
          if (_cartSummary != null) _buildCartSummary(),
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

  /// Build cart summary with delivery fee breakdown
  Widget _buildCartSummary() {
    final summary = _cartSummary!;
    final totalItems = summary['total_items'] as int? ?? 0;
    final subtotal =
        summary['subtotal'] as double? ??
        summary['total_price'] as double? ??
        0.0;
    final deliveryFee = summary['delivery_fee'] as double? ?? 0.0;
    final totalPrice = summary['total_price'] as double? ?? 0.0;
    final deliveryDetails =
        summary['delivery_fee_details'] as Map<String, dynamic>?;

    // Debug information for delivery fee issues
    print('🛒 CART_SUMMARY - Debug Info:');
    print('   Subtotal: ₹${subtotal.toStringAsFixed(0)}');
    print('   Delivery Fee: ₹${deliveryFee.toStringAsFixed(0)}');
    print('   Delivery Address: $_deliveryAddress');
    print('   Delivery Details: $deliveryDetails');
    if (deliveryDetails != null) {
      print('   Calculated: ${deliveryDetails['calculated']}');
      print('   Reason: ${deliveryDetails['reason']}');
      if (deliveryDetails['error'] != null) {
        print('   Error: ${deliveryDetails['error']}');
      }
    }

    return Column(
      children: [
        // Unified Address Picker (Phase 3A.3 - preserves all existing functionality)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: AddressPicker(
            initialAddress: _deliveryAddress,
            hintText: 'Enter your delivery address',
            customerId: widget.customer['id'] as String,
            onAddressChanged: (address, locationData) {
              final trimmedAddress = address.trim();

              if (mounted) {
                setState(() {
                  _deliveryAddress = trimmedAddress.isEmpty
                      ? null
                      : trimmedAddress;
                  _deliveryAddressController.text = address;
                });
              }

              // Validate address and show notifications
              if (trimmedAddress.isNotEmpty) {
                _validateAndNotifyAddress(trimmedAddress);
              }

              // Preserve existing debounced cart reload functionality
              _debounceCartReload();
            },
          ),
        ),

        // Cart Summary Section
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                color: Colors.green[200]!.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$totalItems items',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Subtotal
              _buildSummaryRow('Subtotal', subtotal, false),

              // Delivery Fee
              const SizedBox(height: 8),
              _buildDeliveryFeeRow(deliveryFee, deliveryDetails),

              // Divider
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 1,
                color: Colors.white.withValues(alpha: 0.3),
              ),

              // Total
              _buildSummaryRow('Total', totalPrice, true),
            ],
          ),
        ),
      ],
    );
  }

  /// Build summary row (subtotal, delivery fee, total)
  Widget _buildSummaryRow(String label, double amount, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Build delivery fee row with proper error handling
  Widget _buildDeliveryFeeRow(
    double deliveryFee,
    Map<String, dynamic>? deliveryDetails,
  ) {
    // Check if there's an error in delivery calculation
    if (deliveryDetails != null && deliveryDetails['error'] != null) {
      final errorMessage = DeliveryErrorNotificationService.getErrorMessage(
        deliveryDetails['error'].toString(),
      );

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Delivery Fee',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: Colors.orange[300],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Error',
                    style: TextStyle(
                      color: Colors.orange[300],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(
                width: 150,
                child: Text(
                  errorMessage,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Show delivery fee if charged
    if (deliveryFee > 0) {
      return Column(
        children: [
          _buildSummaryRow('Delivery Fee', deliveryFee, false),
          if (deliveryDetails != null && deliveryDetails['distance_km'] != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 4),
              child: Row(
                children: [
                  Text(
                    '${deliveryDetails['distance_km'].toStringAsFixed(1)}km • ${deliveryDetails['tier'] ?? 'Standard rate'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    // Show free delivery if applicable
    if (deliveryDetails != null &&
        deliveryDetails['reason'] == 'free_delivery_threshold') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Delivery Fee',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'FREE',
                style: TextStyle(
                  color: Colors.yellow[300],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Order above ₹${deliveryDetails['threshold']?.toStringAsFixed(0) ?? '500'}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Default case - calculating or no address
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Delivery Fee',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        Text(
          'Calculating...',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
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

  /// Proceed to checkout with delivery fee integration
  void _proceedToCheckout() {
    FeatureFlags.logFeatureUsage('shopping_cart', 'checkout_initiated');

    // Validate that we have cart items and summary
    if (_cartItems.isEmpty || _cartSummary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to checkout screen with cart data
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerCheckoutScreen(
          customer: widget.customer,
          cartItems: _cartItems,
          cartSummary: _cartSummary!,
        ),
      ),
    ).then((_) {
      // Refresh cart when returning from checkout
      _loadCartItems();
    });
  }
}
