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

      // Production authentication (to be implemented with admin_users table)
      // For now, return error for non-development credentials
      return {
        'success': false,
        'message': 'Admin authentication not yet implemented for production. Use development credentials.',
      };

    } catch (e) {
      print('❌ Admin login error: $e');
      return {
        'success': false,
        'message': 'Login failed: ${e.toString()}',
      };
    }
  }

  /// Check if admin is authenticated
  Future<bool> isAuthenticated() async {
    try {
      // In development, check if we have a mock session
      if (AdminConstants.isDevelopment && _currentAdminId != null) {
        return true;
      }

      // Production authentication check (to be implemented)
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

      print('📝 Admin Action: $action on $resourceType${resourceId != null ? ' ($resourceId)' : ''}');
      
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
