import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Phase 4I: For kDebugMode
import '../supabase_service.dart';
import '../services/shopping_cart_service.dart';
import '../services/customer_notification_service.dart';
import '../services/notification_count_cache.dart'; // Phase 4I: Performance optimization
// Phase 4E: AuthService import removed - logout functionality moved to Account section
import '../services/delivery_address_state.dart';
import '../services/delivery_error_notification_service.dart';
import '../config/feature_flags.dart';
import '../config/maps_config.dart';
import '../widgets/product_review_widget.dart';
import '../widgets/delivery_location_section.dart';
import '../widgets/section_header.dart';
import '../widgets/category_shortcut_row.dart';
import '../widgets/address_picker.dart';
import '../widgets/compact_location_header.dart';
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
  // Phase 4E: AuthService removed - logout functionality moved to Account section
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  // --- Delivery fee diagnostics state (non-invasive) ---
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();
  double? _lastDeliveryFee;
  double? _lastDistanceKm;
  String? _lastFeeReason;
  String? _lastFeeTier;

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false; // Phase 4I: Start with false for faster UI display
  String _searchQuery = '';
  // Phase 4B: _cartItemCount removed - using bottom navigation cart instead
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeAddressState();
    // Phase 4I: Lazy loading - load products after UI is built (faster startup)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
    // Phase 4I: Lazy loading - load notification count in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateNotificationCount();
    });
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
    _scrollController.dispose();
    super.dispose();
  }

  /// Phase 4I: Optimized product loading with better performance
  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('🚀 PERFORMANCE: Loading products...');
      }

      final products = await _supabaseService.getMeatProducts(
        approvalStatus: 'approved',
        isActive: true,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        sortBy: 'name',
        ascending: true,
        limit: 50, // Phase 4I: Reduced from 100 to 50 for faster loading
      );

      if (!mounted) return;

      setState(() {
        _products = products;
        _isLoading = false;
      });

      if (kDebugMode) {
        print(
          '🚀 PERFORMANCE: Loaded ${products.length} products successfully',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (kDebugMode) {
        print('❌ PERFORMANCE: Product loading failed: $e');
      }

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
      // Important: do not add a bottomNavigationBar here to avoid duplicates with CustomerAppShell
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
        child: SafeArea(child: _buildResponsiveBody()),
      ),
    );
  }

  /// Build responsive body with proper scrolling behavior
  Widget _buildResponsiveBody() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // App Bar
        SliverToBoxAdapter(child: _buildAppBar()),

        // Compact Location Header (New Design - Feature Flagged)
        if (UiFlags.compactLocationHeaderEnabled)
          SliverToBoxAdapter(
            child: CompactLocationHeader(
              customerId: widget.customer['id'] as String,
              initialAddress: widget.customer['address'] as String?,
              searchController: _searchController,
              searchQuery: _searchQuery,
              scrollController:
                  _scrollController, // For scroll-collapse behavior
              onSearchChanged: () {
                setState(() {
                  _searchQuery = _searchController.text;
                });
                _loadProducts();
              },
              onAddressChanged: (address, locationData) async {
                // Wire to delivery fee calculation
                final subtotal = await _safeGetCartSubtotal();
                print(
                  '🧩 CATALOG-FEE: CompactHeader change → addr="$address", subtotal=₹${subtotal.toStringAsFixed(0)}',
                );
                await _calculateAndShowDeliveryFee(address, subtotal);
              },
              onNotificationTap: () {
                // Phase 4F: Navigate to notifications (functional implementation)
                _navigateToNotifications();
              },
              notificationCount:
                  _notificationCount, // Phase 4F: Pass notification count for badge
              showVoiceSearch: true, // Phase 3: Voice search enabled
            ),
          ),

        // Legacy UI (Old Design - When compact header is disabled)
        if (!UiFlags.compactLocationHeaderEnabled) ...[
          // Delivery Address Pill (feature flagged)
          if (kShowDeliveryAddressPill)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 12,
                  vertical: 8,
                ),
                child: AddressPicker(
                  isPillMode: true,
                  customerId: widget.customer['id'] as String,
                  initialAddress: widget.customer['address'] as String?,
                  onAddressChanged: (address, locationData) async {
                    // Wire to delivery fee calculation
                    final subtotal = await _safeGetCartSubtotal();
                    print(
                      '🧩 CATALOG-FEE: AddressPicker change → addr="$address", subtotal=₹${subtotal.toStringAsFixed(0)}',
                    );
                    await _calculateAndShowDeliveryFee(address, subtotal);
                  },
                ),
              ),
            ),

          // Search Bar
          SliverToBoxAdapter(child: _buildSearchBar()),
        ],

        // Category shortcuts (feature-flagged via UiFlags)
        if (UiFlags.categoryShortcutsEnabled) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 12),
              child: const SectionHeader(title: 'Popular categories'),
            ),
          ),
          SliverToBoxAdapter(
            child: CategoryShortcutRow(
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
          ),
        ],

        // Google Maps delivery location section (feature flagged)
        if (kEnableCatalogMap && !kHideHomeMapSection)
          SliverToBoxAdapter(
            child: DeliveryLocationSection(
              customerId: widget.customer['id'],
              onLocationSelected: (locationData) async {
                final address = (locationData['address'] as String?) ?? '';
                final subtotal = await _safeGetCartSubtotal();
                print(
                  '🧩 CATALOG-FEE: Map selection → addr="$address", subtotal=₹${subtotal.toStringAsFixed(0)}',
                );
                await _calculateAndShowDeliveryFee(address, subtotal);
              },
            ),
          ),

        // Product Grid
        _isLoading
            ? SliverToBoxAdapter(child: _buildLoadingState())
            : _buildResponsiveProductGrid(isTablet),
      ],
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
          // Phase 4A: Back button removed for logged-in users
          // Users should only be able to exit by logging out
          const SizedBox(width: 12), // Maintain spacing
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
              // Phase 4C: Order History and Notification icons moved to Account section
              // Phase 4C: Logout moved to Account section only
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final horizontalMargin = isTablet ? 24.0 : 12.0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: 12),
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

    // Phase 4H: Updated regular grid to match responsive improvements
    return GridView.builder(
      padding: const EdgeInsets.all(10), // Phase 4H: Reduced padding
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82, // Phase 4H: Better proportions
        crossAxisSpacing: 10, // Phase 4H: Tighter spacing
        mainAxisSpacing: 10, // Phase 4H: Tighter spacing
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  /// Build responsive product grid as a Sliver for CustomScrollView
  Widget _buildResponsiveProductGrid(bool isTablet) {
    if (_products.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          height: 300,
          child: Center(
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
          ),
        ),
      );
    }

    // Responsive grid configuration - Phase 4H: Optimized proportions
    final crossAxisCount = isTablet ? 3 : 2;
    final childAspectRatio = isTablet
        ? 0.85
        : 0.82; // Phase 4H: Better proportions
    final padding = isTablet ? 20.0 : 10.0; // Phase 4H: Reduced padding
    final spacing = isTablet ? 14.0 : 10.0; // Phase 4H: Tighter spacing

    return SliverPadding(
      padding: EdgeInsets.all(padding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final product = _products[index];
          return _buildProductCard(product);
        }, childCount: _products.length),
      ),
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
                  // Phase 4H: Compact image section with better proportions
                  Hero(
                    tag: 'product-${product['id']}',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 80, // Phase 4H: Reduced from 100px to 80px
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
                            size: 36, // Phase 4H: Slightly smaller icon
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Phase 4H: Optimized content section with better spacing
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        10,
                        8,
                        10,
                        8,
                      ), // Phase 4H: Asymmetric padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // Phase 4H: Better distribution
                        children: [
                          // Top content section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] ?? 'Product',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  height: 1.2, // Phase 4H: Tighter line height
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(
                                height: 6,
                              ), // Phase 4H: Optimized spacing
                              Text(
                                '₹${product['price'] ?? 0}/kg',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (product['sellers'] != null) ...[
                                const SizedBox(
                                  height: 3,
                                ), // Phase 4H: Minimal spacing
                                Text(
                                  'by ${product['sellers']['seller_name']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                    height:
                                        1.1, // Phase 4H: Compact line height
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(
                                height: 6,
                              ), // Phase 4H: Compact spacing
                              ProductReviewSummary(
                                productId: product['id'],
                                showFullStats: false,
                              ),
                            ],
                          ),

                          // Bottom button section - Phase 4H: No spacer, fixed positioning
                          SizedBox(
                            width: double.infinity,
                            height: 32, // Phase 4H: Slightly taller button
                            child: ElevatedButton(
                              onPressed: () => _addToCart(product),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    8,
                                  ), // Phase 4H: Slightly more rounded
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ), // Phase 4H: Better padding
                                elevation: 0, // Phase 4H: Flat design
                              ),
                              child: const Text(
                                'Add to Cart',
                                style: TextStyle(
                                  fontSize:
                                      12, // Phase 4H: Slightly larger text
                                  fontWeight: FontWeight.w600,
                                  letterSpacing:
                                      0.3, // Phase 4H: Better letter spacing
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Future<void> _calculateAndShowDeliveryFee(
    String address,
    double subtotal,
  ) async {
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
        final errorType = DeliveryErrorNotificationService.determineErrorType(
          result,
        );
        DeliveryErrorNotificationService.showDeliveryError(
          context,
          errorType: errorType,
          customMessage: DeliveryErrorNotificationService.getErrorMessage(
            result['error'].toString(),
          ),
        );
      }
      return;
    }

    final fee = (result['fee'] as num).toDouble();
    final distanceKm = (result['distance_km'] as num?)?.toDouble();
    final tier = result['tier'] as String?;
    final reason = result['reason'] as String?;

    print(
      '💰 CATALOG-FEE: success fee=₹${fee.toStringAsFixed(0)} dist=${distanceKm?.toStringAsFixed(2)}km tier=$tier reason=${reason ?? '-'}',
    );

    if (mounted) {
      setState(() {
        _lastDeliveryFee = fee;
        _lastDistanceKm = distanceKm;
        _lastFeeTier = tier;
        _lastFeeReason = reason;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reason == 'free_delivery_threshold'
                ? 'Free delivery applied (subtotal qualifies)'
                : 'Estimated delivery fee: ₹${fee.toStringAsFixed(0)}',
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
          // Phase 4B: _updateCartCount() removed - using bottom navigation cart instead
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

  // Phase 4B: _updateCartCount() method removed - using bottom navigation cart instead

  /// Phase 4I: Optimized notification count with caching for performance
  Future<void> _updateNotificationCount() async {
    try {
      final cache = NotificationCountCache();
      final count = await cache.getNotificationCount(widget.customer['id']);

      if (mounted) {
        setState(() {
          _notificationCount = count;
        });
      }
    } catch (e) {
      // Silently handle error - notification count is not critical
      if (kDebugMode) {
        print('❌ PERFORMANCE: Notification count update failed: $e');
      }
      if (mounted) {
        setState(() {
          _notificationCount = 0;
        });
      }
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

  // Phase 4B: _navigateToShoppingCart() method removed - using bottom navigation cart instead

  /// Phase 4I: Optimized navigation with cache invalidation
  void _navigateToNotifications() {
    FeatureFlags.logFeatureUsage('notifications', 'navigation_from_catalog');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerNotificationsScreen(customer: widget.customer),
      ),
    ).then((_) {
      // Phase 4I: Invalidate cache when returning from notifications
      final cache = NotificationCountCache();
      cache.invalidateCache(widget.customer['id']);
      _updateNotificationCount();
    });
  }

  // Phase 4E: Logout methods removed - logout functionality moved to Account section only
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
