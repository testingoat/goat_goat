import 'package:supabase_flutter/supabase_flutter.dart';

/// Customer Notification Service
///
/// Handles fetching and managing notifications for customers
/// from the admin panel notification system
class CustomerNotificationService {
  static final CustomerNotificationService _instance =
      CustomerNotificationService._internal();
  factory CustomerNotificationService() => _instance;
  CustomerNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get notifications for a specific customer
  Future<Map<String, dynamic>> getCustomerNotifications({
    required String customerId,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      print('📱 Fetching notifications for customer: $customerId');

      // Build query based on parameters
      List<Map<String, dynamic>> response;

      if (unreadOnly) {
        // For unread notifications, we'll use delivery_status = 'sent' as a proxy
        // since is_read column doesn't exist in current schema
        if (limit > 0) {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('customer_id', customerId)
              .eq('delivery_status', 'sent')
              .order('created_at', ascending: false)
              .limit(limit);
        } else {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('customer_id', customerId)
              .eq('delivery_status', 'sent')
              .order('created_at', ascending: false);
        }
      } else {
        if (limit > 0) {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('customer_id', customerId)
              .order('created_at', ascending: false)
              .limit(limit);
        } else {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('customer_id', customerId)
              .order('created_at', ascending: false);
        }
      }

      print('✅ Found ${response.length} notifications for customer');

      return {
        'success': true,
        'notifications': response,
        'count': response.length,
      };
    } catch (e) {
      print('❌ Error fetching customer notifications: $e');
      return {
        'success': false,
        'message': 'Failed to fetch notifications',
        'notifications': [],
        'count': 0,
      };
    }
  }

  /// Get unread notification count for badge
  Future<int> getUnreadNotificationCount(String customerId) async {
    try {
      // Use delivery_status = 'sent' as proxy for unread notifications
      final response = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('customer_id', customerId)
          .eq('delivery_status', 'sent');

      return response.length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      // Since is_read column doesn't exist, we'll change delivery_status to 'delivered'
      await _supabase
          .from('notification_logs')
          .update({
            'delivery_status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      print('✅ Notification marked as read: $notificationId');
      return true;
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read for a customer
  Future<bool> markAllNotificationsAsRead(String customerId) async {
    try {
      // Change all 'sent' notifications to 'delivered' to mark as read
      await _supabase
          .from('notification_logs')
          .update({
            'delivery_status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('customer_id', customerId)
          .eq('delivery_status', 'sent');

      print('✅ All notifications marked as read for customer: $customerId');
      return true;
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Get notification by ID
  Future<Map<String, dynamic>?> getNotificationById(
    String notificationId,
  ) async {
    try {
      final response = await _supabase
          .from('notification_logs')
          .select('*')
          .eq('id', notificationId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Error fetching notification by ID: $e');
      return null;
    }
  }

  /// Delete notification (soft delete by marking as deleted)
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notification_logs')
          .update({
            'is_deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      print('✅ Notification deleted: $notificationId');
      return true;
    } catch (e) {
      print('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Get notification statistics for customer
  Future<Map<String, dynamic>> getNotificationStats(String customerId) async {
    try {
      // Get total count
      final totalResponse = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('customer_id', customerId);

      // Get unread count (using delivery_status = 'sent' as proxy)
      final unreadResponse = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('customer_id', customerId)
          .eq('delivery_status', 'sent');

      // Get recent count (last 7 days)
      final recentResponse = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('customer_id', customerId)
          .gte(
            'created_at',
            DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
          );

      return {
        'total': totalResponse.length,
        'unread': unreadResponse.length,
        'recent': recentResponse.length,
      };
    } catch (e) {
      print('❌ Error getting notification stats: $e');
      return {'total': 0, 'unread': 0, 'recent': 0};
    }
  }
}
