import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/admin_constants.dart';

class AdminAuthService {
  static final AdminAuthService _instance = AdminAuthService._internal();
  factory AdminAuthService() => _instance;
  AdminAuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _currentAdminId;
  Map<String, dynamic>? _currentAdmin;

  /// Login admin user
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Admin Login Attempt: $email');

      // For development, allow default admin credentials
      if (AdminConstants.isDevelopment &&
          email == 'admin@goatgoat.com' &&
          password == 'admin123') {
        // Create mock admin session for development
        _currentAdminId = 'dev-admin-id';
        _currentAdmin = {
          'id': 'dev-admin-id',
          'email': 'admin@goatgoat.com',
          'full_name': 'Development Admin',
          'role': 'super_admin',
          'permissions': {
            'review_moderation': true,
            'notification_management': true,
            'user_management': true,
            'analytics_access': true,
            'system_administration': true,
          },
        };

        print('✅ Development admin login successful');
        return {
          'success': true,
          'admin': _currentAdmin,
          'message': 'Login successful (Development Mode)',
        };
      }

      // Production authentication with admin_users table
      try {
        // Query admin_users table for authentication
        final response = await _supabase
            .from('admin_users')
            .select('id, email, full_name, role, permissions, is_active')
            .eq('email', email)
            .eq('is_active', true)
            .maybeSingle();

        if (response == null) {
          return {'success': false, 'message': 'Invalid email or password'};
        }

        // In production, implement proper password hashing verification
        // For now, use simple password check (TEMPORARY - implement bcrypt)
        if (password == 'admin123') {
          _currentAdminId = response['id'];
          _currentAdmin = response;

          // Log successful login
          await logAction(
            action: 'login',
            resourceType: 'admin_session',
            metadata: {'email': email},
          );

          print('✅ Production admin login successful');
          return {
            'success': true,
            'admin': _currentAdmin,
            'message': 'Login successful',
          };
        } else {
          return {'success': false, 'message': 'Invalid email or password'};
        }
      } catch (e) {
        print('❌ Production authentication error: $e');
        return {
          'success': false,
          'message': 'Authentication service temporarily unavailable',
        };
      }
    } catch (e) {
      print('❌ Admin login error: $e');
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  /// Check if admin is authenticated
  Future<bool> isAuthenticated() async {
    try {
      // Check if we have a current admin session
      if (_currentAdminId != null && _currentAdmin != null) {
        return true;
      }

      // In production, could check session token validity here
      // For now, return false if no active session
      return false;
    } catch (e) {
      print('❌ Authentication check error: $e');
      return false;
    }
  }

  /// Get current admin user
  Map<String, dynamic>? get currentAdmin => _currentAdmin;
  String? get currentAdminId => _currentAdminId;

  /// Check if admin has specific permission
  bool hasPermission(String permission) {
    if (_currentAdmin == null) return false;

    final permissions = _currentAdmin!['permissions'] as Map<String, dynamic>?;
    if (permissions == null) return false;

    // Super admin has all permissions
    if (_currentAdmin!['role'] == 'super_admin') return true;

    return permissions[permission] == true;
  }

  /// Logout admin user
  Future<void> logout() async {
    try {
      _currentAdminId = null;
      _currentAdmin = null;
      print('👋 Admin logged out');
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }

  /// Validate admin session (for production)
  Future<bool> validateSession() async {
    try {
      // Development mode - always valid if logged in
      if (AdminConstants.isDevelopment && _currentAdminId != null) {
        return true;
      }

      // Production session validation (to be implemented)
      return false;
    } catch (e) {
      print('❌ Session validation error: $e');
      return false;
    }
  }

  /// Log admin action for audit trail
  Future<void> logAction({
    required String action,
    required String resourceType,
    String? resourceId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (_currentAdminId == null) return;

      print(
        '📝 Admin Action: $action on $resourceType${resourceId != null ? ' ($resourceId)' : ''}',
      );

      // In development, just log to console
      if (AdminConstants.isDevelopment) {
        print('   Admin: ${_currentAdmin?['email']}');
        print('   Metadata: $metadata');
        return;
      }

      // Production audit logging (to be implemented)
      // await _supabase.from('admin_audit_log').insert({...});
    } catch (e) {
      print('❌ Action logging error: $e');
    }
  }
}
