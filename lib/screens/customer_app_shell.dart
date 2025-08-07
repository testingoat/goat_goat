import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../config/ui_flags.dart';
import '../services/shopping_cart_service.dart';
import '../widgets/category_shortcut_row.dart';
import 'customer_product_catalog_screen.dart';
import 'customer_shopping_cart_screen.dart';
import 'customer_order_history_screen.dart';
import 'customer_notifications_screen.dart'; // Phase 4C: Added for notifications in Account section

/// CustomerAppShell
/// UI-only shell that provides a bottom navigation bar with 4 tabs:
/// Home, Explore, Cart, Account. It reuses existing screens and services.
/// No business logic is modified; this only changes the scaffold and navigation.
class CustomerAppShell extends StatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerAppShell({super.key, required this.customer});

  @override
  State<CustomerAppShell> createState() => _CustomerAppShellState();
}

class _CustomerAppShellState extends State<CustomerAppShell> {
  final ShoppingCartService _cartService = ShoppingCartService();

  int _currentIndex = 0;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshCartCount();
  }

  /// Phase 4I: Optimized cart count refresh with better error handling
  Future<void> _refreshCartCount() async {
    try {
      final summary = await _cartService.getCartSummary(widget.customer['id']);
      if (!mounted) return;
      setState(() {
        _cartCount = summary['total_items'] ?? 0;
      });
    } catch (e) {
      // UI-only: ignore errors - cart count is not critical for navigation
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      // Home
      CustomerProductCatalogScreen(customer: widget.customer),

      // Explore (lightweight categories surface reusing existing widget)
      _ExploreScreen(customer: widget.customer),

      // Cart - Phase 4D: Hide back button when accessed from app shell
      CustomerShoppingCartScreen(
        customer: widget.customer,
        hideBackButton: true,
      ),

      // Account hub
      _AccountHubScreen(customer: widget.customer),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: const Color(0xFF059669).withValues(alpha: 0.1),
              hoverColor: const Color(0xFF059669).withValues(alpha: 0.05),
              gap: 8,
              activeColor: const Color(0xFF059669),
              iconSize: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: const Color(
                0xFF059669,
              ).withValues(alpha: 0.1),
              color: const Color(0xFF6B7280),
              tabs: [
                const GButton(icon: Icons.home, text: 'Home'),
                const GButton(icon: Icons.grid_view, text: 'Explore'),
                GButton(
                  icon: Icons.shopping_bag,
                  text: 'Cart',
                  leading: _cartCount > 0
                      ? Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.shopping_bag, size: 24),
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF0000),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    _cartCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
                const GButton(icon: Icons.person, text: 'Account'),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) async {
                setState(() {
                  _currentIndex = index;
                });
                if (index == 2) {
                  await _refreshCartCount();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Explore Screen
/// Lightweight UI that surfaces the existing category shortcuts within a scaffold.
/// This is UI-only composition and does not alter business logic.
class _ExploreScreen extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _ExploreScreen({required this.customer});

  @override
  Widget build(BuildContext context) {
    // A minimal scaffold that reuses the CategoryShortcutRow from catalog
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Explore',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF047857)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Popular categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          // Reuse the same list as catalog via a small inline copy to avoid importing private const
          CategoryShortcutRow(
            categories: const [
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
              CategoryShortcut(
                id: 'fish',
                label: 'Fish',
                icon: Icons.water,
                query: 'fish',
              ),
              CategoryShortcut(
                id: 'prawns',
                label: 'Prawns',
                icon: Icons.emoji_food_beverage,
                query: 'prawns',
              ),
              CategoryShortcut(
                id: 'eggs',
                label: 'Eggs',
                icon: Icons.egg,
                query: 'eggs',
              ),
              CategoryShortcut(
                id: 'marinades',
                label: 'Ready to Cook',
                icon: Icons.kitchen,
                query: 'marinated',
              ),
            ],
            onTap: (cat) {
              // UI-only: navigate to Home tab and prefill search can be added later if needed
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Explore: ${cat.label}'),
                  duration: const Duration(milliseconds: 900),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Discover more soon',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Account Hub Screen
/// Lists navigation shortcuts to Orders, Addresses, Profile, and Logout destination.
/// Uses existing screens where available; actions are UI-only navigations.
class _AccountHubScreen extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _AccountHubScreen({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF047857)],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _SectionHeader(title: 'My Activity'),
          _Tile(
            icon: Icons.receipt_long,
            color: Colors.green[600]!,
            title: 'Orders',
            subtitle: 'Your past orders and tracking',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerOrderHistoryScreen(
                    customer: customer,
                    hideBackButton:
                        true, // Phase 4D: Hide back button from Account section
                  ),
                ),
              );
            },
          ),
          // Phase 4C: Notifications moved from header to Account section
          _Tile(
            icon: Icons.notifications,
            color: Colors.orange[600]!,
            title: 'Notifications',
            subtitle: 'View your notifications and updates',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomerNotificationsScreen(
                    customer: customer,
                    hideBackButton:
                        true, // Phase 4D: Hide back button from Account section
                  ),
                ),
              );
            },
          ),
          _Tile(
            icon: Icons.location_on,
            color: Colors.teal[600]!,
            title: 'Addresses',
            subtitle: 'Manage delivery locations',
            onTap: () {
              // UI-only: Reuse the existing customer catalog screen which hosts address widgets,
              // or navigate to a dedicated selector if needed. Keeping simple here.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CustomerProductCatalogScreen(customer: customer),
                ),
              );
            },
          ),
          _SectionHeader(title: 'My Profile'),
          _Tile(
            icon: Icons.person,
            color: Colors.blueGrey[600]!,
            title: 'Profile',
            subtitle: 'View or update your profile',
            onTap: () {
              // UI-only: Navigate to catalog for now; integration point for a dedicated profile
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CustomerProductCatalogScreen(customer: customer),
                ),
              );
            },
          ),
          _Tile(
            icon: Icons.logout,
            color: Colors.red[600]!,
            title: 'Logout',
            subtitle: 'Sign out from this device',
            onTap: () {
              // UI-only: Pop to root; actual logout flow is handled where invoked
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
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          if (UiFlags.enableCustomerBottomNav)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'Bottom navigation is enabled',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
