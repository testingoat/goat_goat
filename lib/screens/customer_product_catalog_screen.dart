import 'package:flutter/material.dart';
import '../supabase_service.dart';
import '../services/shopping_cart_service.dart';
import '../services/customer_notification_service.dart';
import '../services/auth_service.dart';
import '../config/feature_flags.dart';
import 'customer_order_history_screen.dart';
import 'customer_shopping_cart_screen.dart';
import 'customer_notifications_screen.dart';

class CustomerProductCatalogScreen extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerProductCatalogScreen({super.key, required this.customer});

  @override
  State<CustomerProductCatalogScreen> createState() =>
      _CustomerProductCatalogScreenState();
}

class _CustomerProductCatalogScreenState
    extends State<CustomerProductCatalogScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final ShoppingCartService _cartService = ShoppingCartService();
  final CustomerNotificationService _notificationService =
      CustomerNotificationService();
  final AuthService _authService = AuthService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _cartItemCount = 0;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _updateCartCount();
    _updateNotificationCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load only approved and active products for customers
      final products = await _supabaseService.getMeatProducts(
        approvalStatus: 'approved',
        isActive: true,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: 'name',
        ascending: true,
        limit: 100,
      );

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading products: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFECFDF5), // emerald-50
              Color(0xFFDCFAE6), // green-100
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildSearchBar(),
              Expanded(
                child: _isLoading ? _buildLoadingState() : _buildProductGrid(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF059669), Color(0xFF047857)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fresh Meat Products',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Welcome, ${widget.customer['full_name']}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Order History Button (Feature Flag Protected)
          if (FeatureFlags.isEnabled('order_history'))
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              onPressed: () => _navigateToOrderHistory(),
              tooltip: 'Order History',
            ),
          // Notifications Button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => _navigateToNotifications(),
                tooltip: 'Notifications',
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Shopping Cart Button
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () => _navigateToShoppingCart(),
                tooltip: 'Shopping Cart',
              ),
              if (_cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Logout Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search for meat products...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF059669)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _loadProducts();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          // Debounce search
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchQuery == value) {
              _loadProducts();
            }
          });
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF059669)),
          SizedBox(height: 16),
          Text(
            'Loading fresh products...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No products found for "$_searchQuery"'
                  : 'No products available',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back later for fresh products',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72, // Further optimized to prevent any overflow
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image - Reduced height
          Container(
            height: 100, // Reduced from 120 to 100
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.fastfood,
                size: 40,
                color: Color(0xFF059669),
              ), // Reduced icon size
            ),
          ),

          // Product Details - Fixed height instead of Expanded
          Container(
            height: 115, // Slightly reduced height to prevent overflow
            padding: const EdgeInsets.all(8), // Further reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name
                Text(
                  product['name'] ?? 'Product',
                  style: const TextStyle(
                    fontSize: 14, // Reduced font size
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Price
                Text(
                  '₹${product['price'] ?? 0}/kg',
                  style: const TextStyle(
                    fontSize: 16, // Reduced font size
                    color: Color(0xFF059669),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),

                // Seller name - More compact
                if (product['sellers'] != null)
                  Text(
                    'by ${product['sellers']['seller_name']}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ), // Reduced font size
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                const Spacer(),

                // Add to Cart Button - More compact
                SizedBox(
                  width: double.infinity,
                  height: 28, // Reduced height for button
                  child: ElevatedButton(
                    onPressed: () => _addToCart(product),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                    child: const Text(
                      'Add to Cart',
                      style: TextStyle(
                        fontSize: 11, // Reduced font size
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final result = await _cartService.addToCart(
        customerId: widget.customer['id'],
        productId: product['id'],
        quantity: 1, // Default quantity
        unitPrice: (product['price'] as num).toDouble(),
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: const Color(0xFF059669),
              duration: const Duration(seconds: 2),
            ),
          );

          // Update cart count
          _updateCartCount();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to add to cart'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _updateCartCount() async {
    try {
      final summary = await _cartService.getCartSummary(widget.customer['id']);
      if (mounted) {
        setState(() {
          _cartItemCount = summary['total_items'] ?? 0;
        });
      }
    } catch (e) {
      // Silently handle cart count update errors
      print('Error updating cart count: $e');
    }
  }

  /// Update notification count for badge display
  Future<void> _updateNotificationCount() async {
    try {
      final count = await _notificationService.getUnreadNotificationCount(
        widget.customer['id'],
      );
      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Silently handle notification count update errors
      print('Error updating notification count: $e');
    }
  }

  /// Navigate to Order History screen (Phase 1.1 feature)
  ///
  /// This method provides navigation to the new Order History feature
  /// while maintaining the existing customer portal workflow
  void _navigateToOrderHistory() {
    // Feature flag check (redundant but safe)
    if (!FeatureFlags.isEnabled('order_history')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order history feature is not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Log feature usage
    FeatureFlags.logFeatureUsage('order_history', 'navigation_from_catalog');

    // Navigate to Order History screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerOrderHistoryScreen(customer: widget.customer),
      ),
    );
  }

  /// Navigate to Shopping Cart screen
  ///
  /// This method provides navigation to the shopping cart
  /// while maintaining the existing customer portal workflow
  void _navigateToShoppingCart() {
    // Log feature usage
    FeatureFlags.logFeatureUsage('shopping_cart', 'navigation_from_catalog');

    // Navigate to Shopping Cart screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerShoppingCartScreen(customer: widget.customer),
      ),
    ).then((_) {
      // Refresh cart count when returning from cart screen
      _updateCartCount();
    });
  }

  /// Navigate to Notifications screen
  ///
  /// This method provides navigation to the notifications screen
  /// and refreshes notification count when returning
  void _navigateToNotifications() {
    // Log feature usage
    FeatureFlags.logFeatureUsage('notifications', 'navigation_from_catalog');

    // Navigate to Notifications screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerNotificationsScreen(customer: widget.customer),
      ),
    ).then((_) {
      // Refresh notification count when returning from notifications screen
      _updateNotificationCount();
    });
  }

  /// Show logout confirmation dialog
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  /// Perform logout and return to main screen
  Future<void> _performLogout() async {
    try {
      // Clear the session
      await _authService.clearSession();

      // Navigate back to main screen (replace entire navigation stack)
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      // Handle logout error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
