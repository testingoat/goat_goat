import 'package:flutter/material.dart';
import '../supabase_service.dart';
import '../services/shopping_cart_service.dart';
import '../services/customer_notification_service.dart';
import '../services/auth_service.dart';
import '../services/delivery_address_state.dart';
import '../config/feature_flags.dart';
import '../config/maps_config.dart';
import '../widgets/product_review_widget.dart';
import '../widgets/delivery_location_section.dart';
import '../widgets/section_header.dart';
import '../widgets/category_shortcut_row.dart';
import '../widgets/address_picker.dart';
import '../config/ui_flags.dart';
import 'customer_order_history_screen.dart';
import 'customer_shopping_cart_screen.dart';
import 'customer_notifications_screen.dart';
import 'customer_product_reviews_screen.dart';
import 'customer_product_details_screen.dart';
// Diagnostics wiring for delivery fee
import '../services/delivery_fee_service.dart';

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

  // --- Delivery fee diagnostics state (non-invasive) ---
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();
  double? _lastDeliveryFee;
  double? _lastDistanceKm;
  String? _lastFeeReason;
  String? _lastFeeTier;

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _cartItemCount = 0;
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeAddressState();
    _loadProducts();
    _updateCartCount();
    _updateNotificationCount();
  }

  /// Initialize shared address state from customer data
  void _initializeAddressState() {
    try {
      // Initialize shared address state for this customer
      DeliveryAddressState.initializeFromCustomer(widget.customer);
      print(
        '📍 CATALOG - Address state initialized for customer: ${widget.customer['id']}',
      );
    } catch (e) {
      print('❌ CATALOG - Address state initialization error: $e');
    }
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

              // Phase 3A.3: Delivery Address Pill (feature flagged)
              if (kShowDeliveryAddressPill)
                AddressPicker(
                  isPillMode: true,
                  customerId: widget.customer['id'] as String,
                  initialAddress: widget.customer['address'] as String?,
                  onAddressChanged: (address, locationData) async {
                    // Wire to delivery fee calculation
                    final subtotal = await _safeGetCartSubtotal();
                    print('🧩 CATALOG-FEE: AddressPicker change → addr="$address", subtotal=₹${subtotal.toStringAsFixed(0)}');
                    await _calculateAndShowDeliveryFee(address, subtotal);
                  },
                ),

              _buildSearchBar(),

              // Category shortcuts just under search (feature-flagged via UiFlags)
              if (UiFlags.categoryShortcutsEnabled) ...[
                const SectionHeader(title: 'Popular categories'),
                CategoryShortcutRow(
                  categories: _defaultCategories,
                  onTap: (cat) {
                    // Apply as a quick search and reload results
                    _searchController.text = cat.query ?? cat.label;
                    setState(() {
                      _searchQuery = _searchController.text;
                    });
                    _loadProducts();
                  },
                ),
              ],

              // Google Maps delivery location section (feature flagged)
              // UI Fix: Hide redundant map section when kHideHomeMapSection is true
              if (kEnableCatalogMap && !kHideHomeMapSection)
                DeliveryLocationSection(
                  customerId: widget.customer['id'],
                  onLocationSelected: (locationData) async {
                    final address = (locationData['address'] as String?) ?? '';
                    final subtotal = await _safeGetCartSubtotal();
                    print('🧩 CATALOG-FEE: Map selection → addr="$address", subtotal=₹${subtotal.toStringAsFixed(0)}');
                    await _calculateAndShowDeliveryFee(address, subtotal);
                  },
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
            tooltip: 'Back',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fresh Meat Products',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Welcome, ${widget.customer['full_name']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (FeatureFlags.isEnabled('order_history'))
                IconButton(
                  icon: const Icon(
                    Icons.history,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: () => _navigateToOrderHistory(),
                  tooltip: 'Order History',
                ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => _navigateToNotifications(),
                    tooltip: 'Notifications',
                  ),
                  if (_notificationCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$_notificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 22,
                    ),
                    onPressed: () => _navigateToShoppingCart(),
                    tooltip: 'Shopping Cart',
                  ),
                  if (_cartItemCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$_cartItemCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 22,
                ),
                onSelected: (value) {
                  if (value == 'logout') _showLogoutDialog();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
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
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search for meat products...',
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF059669),
            size: 20,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _loadProducts();
                  },
                  tooltip: 'Clear',
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
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
    return AnimatedOpacity(
      opacity: _isLoading ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading fresh products...',
              style: TextStyle(
                color: Color(0xFF059669),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
                  ? 'No products found for \"$_searchQuery\"'
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
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.78,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return StatefulBuilder(
      builder: (context, setInnerState) {
        bool isPressed = false;
        bool isHovered = false;

        return GestureDetector(
          onTapDown: (_) => setInnerState(() => isPressed = true),
          onTapUp: (_) => setInnerState(() => isPressed = false),
          onTapCancel: () => setInnerState(() => isPressed = false),
          onTap: () => _navigateToProductDetails(product),
          child: MouseRegion(
            onEnter: (_) => setInnerState(() => isHovered = true),
            onExit: (_) => setInnerState(() => isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()
                ..scale(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isHovered ? 0.1 : 0.05,
                    ),
                    blurRadius: isHovered ? 12 : 8,
                    offset: Offset(0, isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'product-${product['id']}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF059669,
                        ).withValues(alpha: isHovered ? 0.15 : 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Center(
                        child: AnimatedScale(
                          scale: isHovered ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.fastfood,
                            size: 40,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 115,
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['name'] ?? 'Product',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${product['price'] ?? 0}/kg',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF059669),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (product['sellers'] != null)
                          Text(
                            'by ${product['sellers']['seller_name']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        ProductReviewSummary(
                          productId: product['id'],
                          showFullStats: false,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: double.infinity,
                          height: 28,
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
                                fontSize: 11,
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
            ),
          ),
        );
      },
    );
  }

  // --- Delivery fee helpers ---

  Future<double> _safeGetCartSubtotal() async {
    try {
      final summary = await _cartService.getCartSummary(widget.customer['id']);
      final subtotal = (summary['subtotal'] as num?)?.toDouble() ?? 0.0;
      return subtotal;
    } catch (e) {
      print('❌ CATALOG-FEE: Failed to get cart subtotal: $e');
      return 0.0;
    }
  }

  Future<void> _calculateAndShowDeliveryFee(String address, double subtotal) async {
    if (address.trim().isEmpty) {
      print('⚠️ CATALOG-FEE: Empty address, skipping fee calc');
      return;
    }
    // Call the DeliveryFeeService
    final result = await _deliveryFeeService.calculateDeliveryFee(
      customerAddress: address,
      orderSubtotal: subtotal,
      // sellerAddress can be provided per product/seller later; default is BLR
    );

    if (!(result['success'] as bool)) {
      print('❌ CATALOG-FEE: Fee calc failed → ${result['error']}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery fee unavailable: ${result['error']}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final fee = (result['fee'] as num).toDouble();
    final distanceKm = (result['distance_km'] as num?)?.toDouble();
    final tier = result['tier'] as String?;
    final reason = result['reason'] as String?;

    print('💰 CATALOG-FEE: success fee=₹${fee.toStringAsFixed(0)} dist=${distanceKm?.toStringAsFixed(2)}km tier=$tier reason=${reason ?? '-'}');

    if (mounted) {
      setState(() {
        _lastDeliveryFee = fee;
        _lastDistanceKm = distanceKm;
        _lastFeeTier = tier;
        _lastFeeReason = reason;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reason == 'free_delivery_threshold'
              ? 'Free delivery applied (subtotal qualifies)'
              : 'Estimated delivery fee: ₹${fee.toStringAsFixed(0)}'
          ),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToProductReviews(Map<String, dynamic> product) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CustomerProductReviewsScreen(
              product: product,
              customer: widget.customer,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToProductDetails(Map<String, dynamic> product) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CustomerProductDetailsScreen(
              product: product,
              customer: widget.customer,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuad,
            ),
            child: SlideTransition(
              position: animation.drive(tween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Future<void> _addToCart(Map<String, dynamic> product) async {
    try {
      final result = await _cartService.addToCart(
        customerId: widget.customer['id'],
        productId: product['id'],
        quantity: 1,
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
      // ignore
    }
  }

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
      // ignore
    }
  }

  void _navigateToOrderHistory() {
    if (!FeatureFlags.isEnabled('order_history')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order history feature is not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    FeatureFlags.logFeatureUsage('order_history', 'navigation_from_catalog');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerOrderHistoryScreen(customer: widget.customer),
      ),
    );
  }

  void _navigateToShoppingCart() {
    FeatureFlags.logFeatureUsage('shopping_cart', 'navigation_from_catalog');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerShoppingCartScreen(customer: widget.customer),
      ),
    ).then((_) {
      _updateCartCount();
    });
  }

  void _navigateToNotifications() {
    FeatureFlags.logFeatureUsage('notifications', 'navigation_from_catalog');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerNotificationsScreen(customer: widget.customer),
      ),
    ).then((_) {
      _updateNotificationCount();
    });
  }

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

  Future<void> _performLogout() async {
    try {
      await _authService.clearSession();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
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

// Single file-level constant for default categories
const List<CategoryShortcut> _defaultCategories = [
  CategoryShortcut(
    id: 'chicken',
    label: 'Chicken',
    icon: Icons.set_meal,
    query: 'chicken',
  ),
  CategoryShortcut(
    id: 'mutton',
    label: 'Mutton',
    icon: Icons.lunch_dining,
    query: 'mutton',
  ),
  CategoryShortcut(id: 'fish', label: 'Fish', icon: Icons.water, query: 'fish'),
  CategoryShortcut(
    id: 'prawns',
    label: 'Prawns',
    icon: Icons.emoji_food_beverage,
    query: 'prawns',
  ),
  CategoryShortcut(id: 'eggs', label: 'Eggs', icon: Icons.egg, query: 'eggs'),
  CategoryShortcut(
    id: 'marinades',
    label: 'Ready to Cook',
    icon: Icons.kitchen,
    query: 'marinated',
  ),
];
