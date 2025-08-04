import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Authentication Service for Persistent Login
/// 
/// Handles storing and retrieving user login state using SharedPreferences
/// Supports both customer and seller authentication sessions
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // SharedPreferences keys
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserRole = 'user_role';
  static const String _keyUserData = 'user_data';
  static const String _keyLoginTimestamp = 'login_timestamp';

  /// Check if user is currently logged in
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsLoggedIn) ?? false;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  /// Get current user role (customer or seller)
  Future<String?> getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserRole);
    } catch (e) {
      print('Error getting user role: $e');
      return null;
    }
  }

  /// Get current user data
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_keyUserData);
      if (userDataString != null) {
        return Map<String, dynamic>.from(json.decode(userDataString));
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Save customer login session
  Future<bool> saveCustomerSession(Map<String, dynamic> customerData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserRole, 'customer');
      await prefs.setString(_keyUserData, json.encode(customerData));
      await prefs.setString(_keyLoginTimestamp, DateTime.now().toIso8601String());

      print('✅ Customer session saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving customer session: $e');
      return false;
    }
  }

  /// Save seller login session
  Future<bool> saveSellerSession(Map<String, dynamic> sellerData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserRole, 'seller');
      await prefs.setString(_keyUserData, json.encode(sellerData));
      await prefs.setString(_keyLoginTimestamp, DateTime.now().toIso8601String());

      print('✅ Seller session saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving seller session: $e');
      return false;
    }
  }

  /// Clear all login session data (logout)
  Future<bool> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_keyIsLoggedIn);
      await prefs.remove(_keyUserRole);
      await prefs.remove(_keyUserData);
      await prefs.remove(_keyLoginTimestamp);

      print('✅ Session cleared successfully');
      return true;
    } catch (e) {
      print('❌ Error clearing session: $e');
      return false;
    }
  }

  /// Get login timestamp
  Future<DateTime?> getLoginTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampString = prefs.getString(_keyLoginTimestamp);
      if (timestampString != null) {
        return DateTime.parse(timestampString);
      }
      return null;
    } catch (e) {
      print('Error getting login timestamp: $e');
      return null;
    }
  }

  /// Check if session is valid (not expired)
  Future<bool> isSessionValid({Duration maxAge = const Duration(days: 30)}) async {
    try {
      final isLoggedIn = await this.isLoggedIn();
      if (!isLoggedIn) return false;

      final loginTimestamp = await getLoginTimestamp();
      if (loginTimestamp == null) return false;

      final now = DateTime.now();
      final sessionAge = now.difference(loginTimestamp);

      return sessionAge <= maxAge;
    } catch (e) {
      print('Error checking session validity: $e');
      return false;
    }
  }

  /// Get session info for debugging
  Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final isLoggedIn = await this.isLoggedIn();
      final userRole = await getUserRole();
      final userData = await getUserData();
      final loginTimestamp = await getLoginTimestamp();

      return {
        'is_logged_in': isLoggedIn,
        'user_role': userRole,
        'user_data': userData,
        'login_timestamp': loginTimestamp?.toIso8601String(),
        'session_valid': await isSessionValid(),
      };
    } catch (e) {
      print('Error getting session info: $e');
      return {
        'is_logged_in': false,
        'user_role': null,
        'user_data': null,
        'login_timestamp': null,
        'session_valid': false,
      };
    }
  }

  /// Update user data (for profile updates)
  Future<bool> updateUserData(Map<String, dynamic> newUserData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserData, json.encode(newUserData));
      
      print('✅ User data updated successfully');
      return true;
    } catch (e) {
      print('❌ Error updating user data: $e');
      return false;
    }
  }

  /// Refresh session timestamp (extend session)
  Future<bool> refreshSession() async {
    try {
      final isLoggedIn = await this.isLoggedIn();
      if (!isLoggedIn) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLoginTimestamp, DateTime.now().toIso8601String());
      
      print('✅ Session refreshed successfully');
      return true;
    } catch (e) {
      print('❌ Error refreshing session: $e');
      return false;
    }
  }
}
