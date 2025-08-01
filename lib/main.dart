import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'seller_portal_screen.dart';
import 'mobile_number_modal.dart';
import 'supabase_service.dart';
import 'screens/developer_dashboard_screen.dart';
import 'screens/customer_portal_screen.dart';

// Firebase imports with platform-aware initialization (temporarily disabled - compatibility issues)
// import 'services/firebase_platform_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with zero-risk platform-aware handling
  await _initializeFirebase();

  runApp(const MyApp());
}

/// Initialize Firebase with zero-risk platform-aware handling (temporarily disabled)
Future<void> _initializeFirebase() async {
  try {
    if (kDebugMode) {
      print(
        '🔥 Firebase initialization temporarily disabled due to compatibility issues',
      );
      print('   App will continue with SMS notifications only');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Firebase initialization error: $e');
      print('   App will continue with SMS notifications only');
    }
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSupabase();
  }

  Future<void> _initializeSupabase() async {
    try {
      // Initialize Supabase with your project credentials
      // Replace these with your actual Supabase URL and anon key
      await SupabaseService().initialize(
        supabaseUrl: 'https://oaynfzqjielnsipttzbs.supabase.co',
        supabaseAnonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc_u-3dhCutpUWEA',
      );

      // FCM Service is now initialized through FirebasePlatformService
      // This provides zero-risk platform-aware initialization
    } catch (e) {
      // Handle initialization error
      print('Initialization error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Initialize FCM Service with proper error handling (temporarily disabled)
  Future<void> _initializeFCMService() async {
    // Temporarily disabled for mobile testing
    if (kDebugMode) {
      print('🔔 FCM Service initialization skipped for testing');
    }
  }

  /// Handle notification tap for deep linking
  void _handleNotificationTapped(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('🔗 Notification tapped with data: $data');
    }

    // Extract deep link URL from notification data
    final deepLinkUrl = data['deep_link_url'] as String?;

    if (deepLinkUrl != null && deepLinkUrl.isNotEmpty) {
      _handleDeepLink(deepLinkUrl);
    }

    // TODO: Implement additional deep linking logic
    // Examples:
    // - Navigate to specific product: /product/{id}
    // - Open order details: /orders/{id}
    // - Show customer portal: /customer
    // - Show seller dashboard: /seller
  }

  /// Handle deep link navigation
  void _handleDeepLink(String deepLinkUrl) {
    if (kDebugMode) {
      print('🔗 Processing deep link: $deepLinkUrl');
    }

    // TODO: Implement deep link routing
    // This would typically use Navigator or a routing package
    // to navigate to the appropriate screen based on the URL
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return MaterialApp(
      title: 'Goat Goat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green,
        ),
        useMaterial3: true,
      ),
      home: const LandingScreen(),
    );
  }
}

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFECFDF5), // emerald-50
              const Color(0xFFDCFAE6), // green-100
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // For larger screens, center the content
              if (constraints.maxWidth > 600) {
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: const _LandingContent(),
                    ),
                  ),
                );
              }
              // For smaller screens, use full width with padding
              return const SingleChildScrollView(child: _LandingContent());
            },
          ),
        ),
      ),
    );
  }
}

class _LandingContent extends StatefulWidget {
  const _LandingContent();

  @override
  State<_LandingContent> createState() => _LandingContentState();
}

class _LandingContentState extends State<_LandingContent> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onLogoTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inSeconds > 2) {
      _tapCount = 0;
    }

    _tapCount++;
    _lastTap = now;

    if (_tapCount >= 7) {
      // Secret developer access - tap logo 7 times
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DeveloperDashboardScreen(),
        ),
      );
      _tapCount = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo section
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _onLogoTap,
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.store, size: 40, color: Colors.green),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Goat Goat',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Fresh meat delivered to your door',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 48),

          // Customer Card
          _GlassCard(
            title: 'CUSTOMER',
            icon: Icons.shopping_cart,
            features: const [
              'Fresh quality meat',
              '30-minute delivery',
              'Competitive pricing',
            ],
            buttonText: 'Start Shopping',
            onTap: () {
              // Navigate to customer portal screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerPortalScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 32),

          // Seller Card
          _GlassCard(
            title: 'SELLER',
            icon: Icons.store,
            features: const [
              'Expand your business',
              'Reach more customers',
              'Simple dashboard',
            ],
            buttonText: 'Access Dashboard',
            onTap: () {
              // Navigate to seller portal screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SellerPortalScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> features;
  final String buttonText;
  final VoidCallback onTap;

  const _GlassCard({
    required this.title,
    required this.icon,
    required this.features,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.green.withOpacity(0.1),
          ],
        ),
        border: Border.all(width: 1, color: Colors.white.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      child: Icon(icon, size: 32, color: Colors.green[700]),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          feature,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
