import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
// import 'package:firebase_core/firebase_core.dart'; // Temporarily disabled for web testing

// Admin-specific imports
import 'admin/screens/admin_login_screen.dart';
import 'admin/screens/admin_dashboard_screen.dart';
import 'admin/services/admin_auth_service.dart';
import 'admin/utils/admin_constants.dart';

void main() async {
  // Enhanced error handling for Flutter web
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase for admin panel (web platform) - temporarily disabled
  // if (kIsWeb) {
  //   try {
  //     await Firebase.initializeApp();
  //     if (kDebugMode) {
  //       print('🔥 Firebase initialized for admin panel');
  //     }
  //   } catch (e) {
  //     if (kDebugMode) {
  //       print('⚠️ Firebase initialization skipped for admin panel: $e');
  //       print('🔄 Admin panel will continue without Firebase features');
  //     }
  //   }
  // }

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      print('Flutter Error: ${details.exception}');
      print('Stack trace: ${details.stack}');
    }
  };

  if (kDebugMode) {
    print('🚀 Starting Goat Goat Admin Panel...');
  }

  runApp(const GoatGoatAdminApp());
}

class GoatGoatAdminApp extends StatelessWidget {
  const GoatGoatAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goat Goat Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Desktop-optimized theme
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green[600]!,
          brightness: Brightness.light,
        ),
      ),
      home: const AdminAppWrapper(),
      routes: {
        '/login': (context) => const AdminLoginScreen(),
        '/dashboard': (context) => const AdminDashboardScreen(),
      },
    );
  }
}

class AdminAppWrapper extends StatefulWidget {
  const AdminAppWrapper({super.key});

  @override
  State<AdminAppWrapper> createState() => _AdminAppWrapperState();
}

class _AdminAppWrapperState extends State<AdminAppWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _supabaseInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      if (kDebugMode) {
        print(
          '🔧 Environment: ${AdminConstants.isDevelopment ? 'Development' : 'Production'}',
        );
        print('🌐 Supabase URL: ${AdminConstants.supabaseUrl}');
      }

      // Initialize Supabase using the same method as mobile app
      if (!_supabaseInitialized) {
        try {
          await Supabase.initialize(
            url: AdminConstants.supabaseUrl,
            anonKey: AdminConstants.supabaseAnonKey,
            debug: kDebugMode,
          );
          _supabaseInitialized = true;

          if (kDebugMode) {
            print('✅ Supabase initialized successfully for admin panel');
            print(
              '🔑 Using anon key: ${AdminConstants.supabaseAnonKey.substring(0, 20)}...',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Supabase initialization failed: $e');
          }
          rethrow;
        }
      }

      // Check authentication status
      final adminAuth = AdminAuthService();
      bool isAuthenticated = await adminAuth.isAuthenticated();

      // Auto-login for development mode
      if (!isAuthenticated && AdminConstants.isDevelopment) {
        if (kDebugMode) {
          print('🔧 Development mode: Attempting auto-login...');
        }

        final loginResult = await adminAuth.login(
          email: 'admin@goatgoat.com',
          password: 'admin123',
        );

        if (loginResult['success'] == true) {
          isAuthenticated = true;
          if (kDebugMode) {
            print('✅ Development auto-login successful');
          }
        } else {
          if (kDebugMode) {
            print('❌ Development auto-login failed: ${loginResult['message']}');
          }
        }
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = isAuthenticated;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to initialize admin app: $e');
      }

      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.green[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text(
                'Initializing Admin Panel...',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Show error if initialization failed
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.red[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize admin panel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeApp();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return _isAuthenticated
        ? const AdminDashboardScreen()
        : const AdminLoginScreen();
  }
}
