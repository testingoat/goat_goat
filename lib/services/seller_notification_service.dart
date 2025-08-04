import 'package:supabase_flutter/supabase_flutter.dart';

/// Seller Notification Service
///
/// Handles fetching and managing notifications for sellers
/// from the admin panel notification system
class SellerNotificationService {
  static final SellerNotificationService _instance =
      SellerNotificationService._internal();
  factory SellerNotificationService() => _instance;
  SellerNotificationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get notifications for a specific seller
  Future<Map<String, dynamic>> getSellerNotifications({
    required String sellerId,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      print('📱 Fetching notifications for seller: $sellerId');

      // Build query based on parameters
      List<Map<String, dynamic>> response;

      if (unreadOnly) {
        // For unread notifications, we'll use delivery_status = 'sent' as a proxy
        // since is_read column doesn't exist in current schema
        if (limit > 0) {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('seller_id', sellerId)
              .eq('delivery_status', 'sent')
              .order('created_at', ascending: false)
              .limit(limit);
        } else {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('seller_id', sellerId)
              .eq('delivery_status', 'sent')
              .order('created_at', ascending: false);
        }
      } else {
        if (limit > 0) {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('seller_id', sellerId)
              .order('created_at', ascending: false)
              .limit(limit);
        } else {
          response = await _supabase
              .from('notification_logs')
              .select('*')
              .eq('seller_id', sellerId)
              .order('created_at', ascending: false);
        }
      }

      print('✅ Found ${response.length} notifications for seller');

      return {
        'success': true,
        'notifications': response,
        'count': response.length,
      };
    } catch (e) {
      print('❌ Error fetching seller notifications: $e');
      return {
        'success': false,
        'message': 'Failed to fetch notifications',
        'notifications': [],
        'count': 0,
      };
    }
  }

  /// Get unread notification count for badge
  Future<int> getUnreadNotificationCount(String sellerId) async {
    try {
      // Use delivery_status = 'sent' as proxy for unread notifications
      final response = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('seller_id', sellerId)
          .eq('delivery_status', 'sent');

      return response.length;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark a specific notification as read
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

  /// Mark all notifications as read for a seller
  Future<bool> markAllNotificationsAsRead(String sellerId) async {
    try {
      // Change all 'sent' notifications to 'delivered' to mark as read
      await _supabase
          .from('notification_logs')
          .update({
            'delivery_status': 'delivered',
            'delivered_at': DateTime.now().toIso8601String(),
          })
          .eq('seller_id', sellerId)
          .eq('delivery_status', 'sent');

      print('✅ All notifications marked as read for seller: $sellerId');
      return true;
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notification_logs')
          .delete()
          .eq('id', notificationId);

      print('✅ Notification deleted: $notificationId');
      return true;
    } catch (e) {
      print('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Get notification statistics for seller
  Future<Map<String, dynamic>> getNotificationStats(String sellerId) async {
    try {
      // Get total count
      final totalResponse = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('seller_id', sellerId);

      // Get unread count (using delivery_status = 'sent' as proxy)
      final unreadResponse = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('seller_id', sellerId)
          .eq('delivery_status', 'sent');

      // Get recent count (last 7 days)
      final recentResponse = await _supabase
          .from('notification_logs')
          .select('id')
          .eq('seller_id', sellerId)
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

  /// Get notifications by type
  Future<Map<String, dynamic>> getNotificationsByType({
    required String sellerId,
    required String notificationType,
    int limit = 20,
  }) async {
    try {
      final response = await _supabase
          .from('notification_logs')
          .select('*')
          .eq('seller_id', sellerId)
          .eq('notification_type', notificationType)
          .order('created_at', ascending: false)
          .limit(limit);

      return {
        'success': true,
        'notifications': response,
        'count': response.length,
      };
    } catch (e) {
      print('❌ Error fetching notifications by type: $e');
      return {
        'success': false,
        'message': 'Failed to fetch notifications by type',
        'notifications': [],
        'count': 0,
      };
    }
  }
}
