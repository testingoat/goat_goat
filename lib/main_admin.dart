import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

// Admin-specific imports
import 'admin/screens/admin_login_screen.dart';
import 'admin/screens/admin_dashboard_screen.dart';
import 'admin/services/admin_auth_service.dart';
import 'admin/utils/admin_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase with environment-specific configuration
  await Supabase.initialize(
    url: AdminConstants.supabaseUrl,
    anonKey: AdminConstants.supabaseAnonKey,
    debug: kDebugMode,
  );

  runApp(const GoatGoatAdminApp());
}

class GoatGoatAdminApp extends StatelessWidget {
  const GoatGoatAdminApp({Key? key}) : super(key: key);

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
  const AdminAppWrapper({Key? key}) : super(key: key);

  @override
  State<AdminAppWrapper> createState() => _AdminAppWrapperState();
}

class _AdminAppWrapperState extends State<AdminAppWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isAuthenticated = await AdminAuthService().isAuthenticated();
      setState(() {
        _isAuthenticated = isAuthenticated;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _isAuthenticated
        ? const AdminDashboardScreen()
        : const AdminLoginScreen();
  }
}
