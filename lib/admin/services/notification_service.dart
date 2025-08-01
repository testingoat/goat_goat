import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../services/otp_service_fallback.dart';
import 'admin_auth_service.dart';

/// Notification Service for Admin Panel
///
/// This service follows the zero-risk pattern:
/// - Extends existing Fast2SMS infrastructure (OTPServiceFallback)
/// - No modifications to existing services
/// - Feature flags for gradual rollout
/// - 100% backward compatibility
class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final OTPServiceFallback _smsService = OTPServiceFallback();
  final AdminAuthService _adminAuth = AdminAuthService();

  // Feature flags for gradual rollout
  static const bool _enableSMSNotifications = true;
  static const bool _enableBulkOperations = true;
  static const bool _enableTemplateManagement = true;
  static const bool _enableAnalytics = true;

  // FCM Push Notification feature flags (disabled for web builds)
  static const bool _enablePushNotifications = !kIsWeb;
  static const bool _enableTopicNotifications = !kIsWeb;
  static const bool _enableTargetedNotifications = !kIsWeb;

  // ===== TEMPLATE MANAGEMENT =====

  /// Get all notification templates with optional filtering
  Future<Map<String, dynamic>> getNotificationTemplates({
    String? templateType,
    bool? isActive,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      if (!_enableTemplateManagement) {
        return {
          'success': false,
          'message': 'Template management feature is currently disabled',
          'templates': [],
        };
      }

      print('📋 Getting notification templates...');

      var query = _supabase.from('notification_templates').select('*');

      // Apply filters
      if (templateType != null) {
        query = query.eq('template_type', templateType);
      }
      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      await _adminAuth.logAction(
        action: 'get_notification_templates',
        resourceType: 'notification_template',
        metadata: {
          'filters': {'template_type': templateType, 'is_active': isActive},
          'result_count': response.length,
        },
      );

      return {
        'success': true,
        'templates': response,
        'total_count': response.length,
      };
    } catch (e) {
      print('❌ Error getting notification templates: $e');
      return {
        'success': false,
        'message': 'Failed to retrieve templates: ${e.toString()}',
        'templates': [],
      };
    }
  }

  /// Create a new notification template
  Future<Map<String, dynamic>> createNotificationTemplate({
    required String templateName,
    required String templateType,
    required String titleTemplate,
    required String messageTemplate,
    List<String> templateVariables = const [],
    List<String> deliveryMethods = const ['sms'],
    bool isActive = true,
  }) async {
    try {
      if (!_enableTemplateManagement) {
        return {
          'success': false,
          'message': 'Template management feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      print('📝 Creating notification template: $templateName');

      final response = await _supabase
          .from('notification_templates')
          .insert({
            'template_name': templateName,
            'template_type': templateType,
            'title_template': titleTemplate,
            'message_template': messageTemplate,
            'template_variables': templateVariables,
            'delivery_methods': deliveryMethods,
            'is_active': isActive,
            'created_by': adminId,
          })
          .select()
          .single();

      await _adminAuth.logAction(
        action: 'create_notification_template',
        resourceType: 'notification_template',
        resourceId: response['id'],
        metadata: {
          'template_name': templateName,
          'template_type': templateType,
          'variables_count': templateVariables.length,
        },
      );

      return {
        'success': true,
        'message': 'Template created successfully',
        'template': response,
      };
    } catch (e) {
      print('❌ Error creating notification template: $e');
      return {
        'success': false,
        'message': 'Failed to create template: ${e.toString()}',
      };
    }
  }

  /// Update an existing notification template
  Future<Map<String, dynamic>> updateNotificationTemplate({
    required String templateId,
    String? templateName,
    String? templateType,
    String? titleTemplate,
    String? messageTemplate,
    List<String>? templateVariables,
    List<String>? deliveryMethods,
    bool? isActive,
  }) async {
    try {
      if (!_enableTemplateManagement) {
        return {
          'success': false,
          'message': 'Template management feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      print('✏️ Updating notification template: $templateId');

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (templateName != null) updateData['template_name'] = templateName;
      if (templateType != null) updateData['template_type'] = templateType;
      if (titleTemplate != null) updateData['title_template'] = titleTemplate;
      if (messageTemplate != null)
        updateData['message_template'] = messageTemplate;
      if (templateVariables != null)
        updateData['template_variables'] = templateVariables;
      if (deliveryMethods != null)
        updateData['delivery_methods'] = deliveryMethods;
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await _supabase
          .from('notification_templates')
          .update(updateData)
          .eq('id', templateId)
          .select()
          .single();

      await _adminAuth.logAction(
        action: 'update_notification_template',
        resourceType: 'notification_template',
        resourceId: templateId,
        metadata: {'updated_fields': updateData.keys.toList()},
      );

      return {
        'success': true,
        'message': 'Template updated successfully',
        'template': response,
      };
    } catch (e) {
      print('❌ Error updating notification template: $e');
      return {
        'success': false,
        'message': 'Failed to update template: ${e.toString()}',
      };
    }
  }

  /// Delete a notification template
  Future<Map<String, dynamic>> deleteNotificationTemplate(
    String templateId,
  ) async {
    try {
      if (!_enableTemplateManagement) {
        return {
          'success': false,
          'message': 'Template management feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      print('🗑️ Deleting notification template: $templateId');

      // Get template details before deletion for audit trail
      final templateBefore = await _supabase
          .from('notification_templates')
          .select('*')
          .eq('id', templateId)
          .single();

      await _supabase
          .from('notification_templates')
          .delete()
          .eq('id', templateId);

      await _adminAuth.logAction(
        action: 'delete_notification_template',
        resourceType: 'notification_template',
        resourceId: templateId,
        metadata: {
          'template_name': templateBefore['template_name'],
          'template_type': templateBefore['template_type'],
        },
      );

      return {'success': true, 'message': 'Template deleted successfully'};
    } catch (e) {
      print('❌ Error deleting notification template: $e');
      return {
        'success': false,
        'message': 'Failed to delete template: ${e.toString()}',
      };
    }
  }

  // ===== TEMPLATE RENDERING =====

  /// Render a template with variables
  Future<Map<String, dynamic>> renderTemplate({
    required String templateId,
    required Map<String, dynamic> variables,
  }) async {
    try {
      print('🎨 Rendering template: $templateId');

      // Get template
      final template = await _supabase
          .from('notification_templates')
          .select('*')
          .eq('id', templateId)
          .eq('is_active', true)
          .single();

      String renderedTitle = template['title_template'];
      String renderedMessage = template['message_template'];

      // Replace variables in title and message
      variables.forEach((key, value) {
        renderedTitle = renderedTitle.replaceAll('{$key}', value.toString());
        renderedMessage = renderedMessage.replaceAll(
          '{$key}',
          value.toString(),
        );
      });

      return {
        'success': true,
        'rendered_title': renderedTitle,
        'rendered_message': renderedMessage,
        'template': template,
      };
    } catch (e) {
      print('❌ Error rendering template: $e');
      return {
        'success': false,
        'message': 'Failed to render template: ${e.toString()}',
      };
    }
  }

  /// Preview template rendering
  Future<Map<String, dynamic>> previewTemplate({
    required String titleTemplate,
    required String messageTemplate,
    required Map<String, dynamic> variables,
  }) async {
    try {
      String renderedTitle = titleTemplate;
      String renderedMessage = messageTemplate;

      // Replace variables
      variables.forEach((key, value) {
        renderedTitle = renderedTitle.replaceAll('{$key}', value.toString());
        renderedMessage = renderedMessage.replaceAll(
          '{$key}',
          value.toString(),
        );
      });

      return {
        'success': true,
        'rendered_title': renderedTitle,
        'rendered_message': renderedMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to preview template: ${e.toString()}',
      };
    }
  }

  // ===== SMS NOTIFICATION METHODS =====

  /// Send SMS notification using template
  Future<Map<String, dynamic>> sendSMSNotification({
    required String recipientId,
    required String recipientType, // 'customer' or 'seller'
    required String templateId,
    required Map<String, dynamic> variables,
    String? customMessage,
  }) async {
    try {
      if (!_enableSMSNotifications) {
        return {
          'success': false,
          'message': 'SMS notifications feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      print('📱 Sending SMS notification to $recipientType: $recipientId');

      // Get recipient details
      final recipientData = await _getRecipientData(recipientId, recipientType);
      if (!recipientData['success']) {
        return recipientData;
      }

      final recipient = recipientData['recipient'];
      final phoneNumber =
          recipient['phone_number'] ?? recipient['contact_phone'];

      if (phoneNumber == null || phoneNumber.isEmpty) {
        return {
          'success': false,
          'message': 'Recipient phone number not found',
        };
      }

      // Check notification preferences
      final preferencesCheck = await _checkNotificationPreferences(
        recipientId,
        recipientType,
        'sms',
      );
      if (!preferencesCheck['allowed']) {
        return {
          'success': true,
          'message': 'Notification skipped due to user preferences',
          'skipped': true,
        };
      }

      String finalMessage;
      String finalTitle;
      Map<String, dynamic>? template;

      if (customMessage != null) {
        finalMessage = customMessage;
        finalTitle = 'Custom Notification';
      } else {
        // Render template
        final renderResult = await renderTemplate(
          templateId: templateId,
          variables: variables,
        );

        if (!renderResult['success']) {
          return renderResult;
        }

        finalMessage = renderResult['rendered_message'];
        finalTitle = renderResult['rendered_title'];
        template = renderResult['template'];
      }

      // Create notification log entry
      final logEntry = await _supabase
          .from('notification_logs')
          .insert({
            '${recipientType}_id': recipientId,
            'recipient_phone': phoneNumber,
            'template_id': customMessage == null ? templateId : null,
            'notification_type': template?['template_type'] ?? 'custom',
            'title': finalTitle,
            'message': finalMessage,
            'delivery_method': 'sms',
            'delivery_status': 'pending',
            'scheduled_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Send SMS using existing Fast2SMS service
      final smsResult = await _sendSMSDirectly(phoneNumber, finalMessage);

      // Update log entry with result
      await _supabase
          .from('notification_logs')
          .update({
            'delivery_status': smsResult['success'] ? 'sent' : 'failed',
            'external_id': smsResult['external_id'],
            'error_message': smsResult['success'] ? null : smsResult['message'],
            'sent_at': smsResult['success']
                ? DateTime.now().toIso8601String()
                : null,
            'delivery_attempts': 1,
          })
          .eq('id', logEntry['id']);

      await _adminAuth.logAction(
        action: 'send_sms_notification',
        resourceType: 'notification',
        resourceId: logEntry['id'],
        metadata: {
          'recipient_type': recipientType,
          'recipient_id': recipientId,
          'template_id': templateId,
          'delivery_status': smsResult['success'] ? 'sent' : 'failed',
        },
      );

      return {
        'success': smsResult['success'],
        'message': smsResult['message'],
        'notification_id': logEntry['id'],
        'recipient_phone': phoneNumber,
      };
    } catch (e) {
      print('❌ Error sending SMS notification: $e');
      return {
        'success': false,
        'message': 'Failed to send SMS notification: ${e.toString()}',
      };
    }
  }

  /// Send bulk SMS notifications
  Future<Map<String, dynamic>> sendBulkSMSNotification({
    required List<Map<String, String>>
    recipients, // [{'id': '...', 'type': 'customer|seller'}]
    required String templateId,
    required Map<String, dynamic> variables,
    String? customMessage,
  }) async {
    try {
      if (!_enableBulkOperations) {
        return {
          'success': false,
          'message': 'Bulk operations feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      if (recipients.isEmpty) {
        return {
          'success': false,
          'message': 'No recipients specified for bulk notification',
        };
      }

      print(
        '📱 Sending bulk SMS notification to ${recipients.length} recipients',
      );

      final results = <String, dynamic>{
        'successful': <String>[],
        'failed': <Map<String, String>>[],
        'skipped': <String>[],
      };

      for (final recipient in recipients) {
        try {
          final result = await sendSMSNotification(
            recipientId: recipient['id']!,
            recipientType: recipient['type']!,
            templateId: templateId,
            variables: variables,
            customMessage: customMessage,
          );

          if (result['success']) {
            if (result['skipped'] == true) {
              results['skipped'].add(recipient['id']!);
            } else {
              results['successful'].add(recipient['id']!);
            }
          } else {
            results['failed'].add({
              'recipient_id': recipient['id']!,
              'error': result['message'],
            });
          }
        } catch (e) {
          results['failed'].add({
            'recipient_id': recipient['id']!,
            'error': e.toString(),
          });
        }
      }

      await _adminAuth.logAction(
        action: 'send_bulk_sms_notification',
        resourceType: 'notification',
        metadata: {
          'total_recipients': recipients.length,
          'successful_count': results['successful'].length,
          'failed_count': results['failed'].length,
          'skipped_count': results['skipped'].length,
          'template_id': templateId,
        },
      );

      return {
        'success': true,
        'message': 'Bulk SMS notification completed',
        'results': results,
        'total_processed': recipients.length,
        'successful_count': results['successful'].length,
        'failed_count': results['failed'].length,
        'skipped_count': results['skipped'].length,
      };
    } catch (e) {
      print('❌ Error in bulk SMS notification: $e');
      return {
        'success': false,
        'message': 'Bulk SMS notification failed: ${e.toString()}',
      };
    }
  }

  // ===== HELPER METHODS =====

  /// Get recipient data (customer or seller)
  Future<Map<String, dynamic>> _getRecipientData(
    String recipientId,
    String recipientType,
  ) async {
    try {
      final table = recipientType == 'customer' ? 'customers' : 'sellers';
      final phoneField = recipientType == 'customer'
          ? 'phone_number'
          : 'contact_phone';

      // Select appropriate name field based on table
      final nameField = table == 'customers' ? 'full_name' : 'seller_name';

      final response = await _supabase
          .from(table)
          .select('id, $nameField, $phoneField')
          .eq('id', recipientId)
          .maybeSingle();

      if (response == null) {
        return {
          'success': false,
          'message': '${recipientType.capitalize()} not found',
        };
      }

      return {'success': true, 'recipient': response};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get recipient data: ${e.toString()}',
      };
    }
  }

  /// Check notification preferences for recipient
  Future<Map<String, dynamic>> _checkNotificationPreferences(
    String recipientId,
    String recipientType,
    String deliveryMethod,
  ) async {
    try {
      // For now, allow all notifications (preferences can be implemented later)
      // This follows the zero-risk pattern - start simple and expand
      return {'allowed': true, 'reason': 'Default allow policy'};
    } catch (e) {
      // Default to allowing notifications if preference check fails
      return {
        'allowed': true,
        'reason': 'Preference check failed, defaulting to allow',
      };
    }
  }

  /// Send SMS directly using existing Fast2SMS infrastructure
  Future<Map<String, dynamic>> _sendSMSDirectly(
    String phoneNumber,
    String message,
  ) async {
    try {
      // Use the existing OTPServiceFallback infrastructure but for custom messages
      // This reuses the Fast2SMS API key and infrastructure
      const apiKey =
          'TBXtyM2OVn0ra5SPdRCH48pghNkzm3w1xFoKIsYJGDEeb7Lvl6wShBusoREfqr0kO3M5jJdexvGQctbn';

      final response = await _supabase.functions.invoke(
        'fast2sms-custom',
        body: {
          'phone_number': phoneNumber,
          'message': message,
          'api_key': apiKey,
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'message': 'SMS sent successfully',
          'external_id': response.data['external_id'],
        };
      } else {
        return {
          'success': false,
          'message': response.data?['message'] ?? 'SMS sending failed',
        };
      }
    } catch (e) {
      print('❌ Error sending SMS directly: $e');
      return {
        'success': false,
        'message': 'SMS sending failed: ${e.toString()}',
      };
    }
  }

  // ===== ANALYTICS METHODS =====

  /// Get notification analytics and statistics
  Future<Map<String, dynamic>> getNotificationAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    String? notificationType,
    String? deliveryMethod,
  }) async {
    try {
      if (!_enableAnalytics) {
        return {
          'success': false,
          'message': 'Analytics feature is currently disabled',
        };
      }

      print('📊 Getting notification analytics...');

      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get delivery statistics
      var query = _supabase
          .from('notification_logs')
          .select(
            'delivery_status, delivery_method, notification_type, created_at',
          )
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String());

      if (notificationType != null) {
        query = query.eq('notification_type', notificationType);
      }
      if (deliveryMethod != null) {
        query = query.eq('delivery_method', deliveryMethod);
      }

      final logs = await query;

      // Calculate statistics
      final stats = {
        'total_sent': 0,
        'total_delivered': 0,
        'total_failed': 0,
        'total_pending': 0,
        'delivery_rate': 0.0,
        'by_method': <String, int>{},
        'by_type': <String, int>{},
        'by_status': <String, int>{},
        'daily_stats': <String, int>{},
      };

      for (final log in logs) {
        final status = log['delivery_status'] as String;
        final method = log['delivery_method'] as String;
        final type = log['notification_type'] as String;
        final date = DateTime.parse(
          log['created_at'],
        ).toIso8601String().split('T')[0];

        // Update counters
        stats['total_sent'] = (stats['total_sent'] as int) + 1;

        switch (status) {
          case 'delivered':
          case 'sent':
            stats['total_delivered'] = (stats['total_delivered'] as int) + 1;
            break;
          case 'failed':
            stats['total_failed'] = (stats['total_failed'] as int) + 1;
            break;
          case 'pending':
            stats['total_pending'] = (stats['total_pending'] as int) + 1;
            break;
        }

        // Update breakdowns
        final byMethod = stats['by_method'] as Map<String, int>;
        byMethod[method] = (byMethod[method] ?? 0) + 1;

        final byType = stats['by_type'] as Map<String, int>;
        byType[type] = (byType[type] ?? 0) + 1;

        final byStatus = stats['by_status'] as Map<String, int>;
        byStatus[status] = (byStatus[status] ?? 0) + 1;

        final dailyStats = stats['daily_stats'] as Map<String, int>;
        dailyStats[date] = (dailyStats[date] ?? 0) + 1;
      }

      // Calculate delivery rate
      final totalSent = stats['total_sent'] as int;
      final totalDelivered = stats['total_delivered'] as int;
      stats['delivery_rate'] = totalSent > 0
          ? (totalDelivered / totalSent * 100)
          : 0.0;

      await _adminAuth.logAction(
        action: 'get_notification_analytics',
        resourceType: 'analytics',
        metadata: {
          'date_range':
              '${start.toIso8601String()} to ${end.toIso8601String()}',
          'total_notifications': totalSent,
        },
      );

      return {
        'success': true,
        'analytics': stats,
        'date_range': {
          'start': start.toIso8601String(),
          'end': end.toIso8601String(),
        },
      };
    } catch (e) {
      print('❌ Error getting notification analytics: $e');
      return {
        'success': false,
        'message': 'Failed to retrieve analytics: ${e.toString()}',
      };
    }
  }

  /// Get recent notifications with pagination
  Future<Map<String, dynamic>> getRecentNotifications({
    int limit = 20,
    int offset = 0,
    String? deliveryStatus,
    String? notificationType,
  }) async {
    try {
      print('📋 Getting recent notifications...');
      print('📋 Limit: $limit, Offset: $offset');
      print('📋 Filters - Status: $deliveryStatus, Type: $notificationType');

      // First, try a simple query to see if we can get basic data
      final simpleResponse = await _supabase
          .from('notification_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      print('📋 Simple query returned ${simpleResponse.length} records');

      if (simpleResponse.isNotEmpty) {
        print('📋 Sample record: ${simpleResponse.first}');
      }

      // Now try the complex query with joins
      var query = _supabase.from('notification_logs').select('''
        *,
        customers(id, full_name, phone_number),
        sellers(id, seller_name, contact_phone),
        notification_templates(template_name, template_type)
      ''');

      if (deliveryStatus != null) {
        query = query.eq('delivery_status', deliveryStatus);
      }
      if (notificationType != null) {
        query = query.eq('notification_type', notificationType);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('📋 Complex query returned ${response.length} records');

      return {
        'success': true,
        'notifications': response,
        'total_count': response.length,
        'has_more': response.length == limit,
        'debug_info': {
          'simple_count': simpleResponse.length,
          'complex_count': response.length,
          'query_filters': {
            'delivery_status': deliveryStatus,
            'notification_type': notificationType,
          },
        },
      };
    } catch (e) {
      print('❌ Error getting recent notifications: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      return {
        'success': false,
        'message': 'Failed to retrieve notifications: ${e.toString()}',
        'notifications': [],
        'error_details': e.toString(),
      };
    }
  }

  // ===== TEMPLATE NOTIFICATION METHODS =====

  /// Send notification using a template
  Future<Map<String, dynamic>> sendTemplateNotification({
    required String templateId,
    required String targetUserId,
    required String targetUserType,
    required Map<String, String> templateVariables,
  }) async {
    try {
      print('📧 Sending template notification...');
      print('📧 Template ID: $templateId');
      print('📧 Target: $targetUserId ($targetUserType)');
      print('📧 Variables: $templateVariables');

      // Get the template
      final templateResponse = await _supabase
          .from('notification_templates')
          .select('*')
          .eq('id', templateId)
          .eq('is_active', true)
          .maybeSingle();

      if (templateResponse == null) {
        return {'success': false, 'message': 'Template not found or inactive'};
      }

      // Process template variables
      String title = templateResponse['title_template'] ?? '';
      String message = templateResponse['message_template'] ?? '';

      // Replace variables in title and message
      templateVariables.forEach((key, value) {
        title = title.replaceAll('{$key}', value);
        message = message.replaceAll('{$key}', value);
      });

      // Determine target based on type
      String? recipientId;
      String? phoneNumber;
      String recipientType = 'customer'; // default

      if (targetUserType == 'phone') {
        phoneNumber = targetUserId;
        // Try to find customer by phone
        final customerResponse = await _supabase
            .from('customers')
            .select('id')
            .eq('phone_number', '+91$targetUserId')
            .maybeSingle();

        if (customerResponse != null) {
          recipientId = customerResponse['id'];
        }
      } else if (targetUserType == 'customer_id') {
        recipientId = targetUserId;
        recipientType = 'customer';

        // Get phone number
        final customerResponse = await _supabase
            .from('customers')
            .select('phone_number')
            .eq('id', targetUserId)
            .maybeSingle();

        if (customerResponse != null) {
          phoneNumber = customerResponse['phone_number'];
        }
      } else if (targetUserType == 'seller_id') {
        recipientId = targetUserId;
        recipientType = 'seller';

        // Get phone number
        final sellerResponse = await _supabase
            .from('sellers')
            .select('contact_phone')
            .eq('id', targetUserId)
            .maybeSingle();

        if (sellerResponse != null) {
          phoneNumber = sellerResponse['contact_phone'];
        }
      }

      if (phoneNumber == null) {
        return {
          'success': false,
          'message': 'Could not determine recipient phone number',
        };
      }

      // Send SMS notification using existing method
      final smsResult = await sendSMSNotification(
        recipientId: recipientId ?? 'unknown',
        recipientType: recipientType,
        templateId: templateId,
        variables: templateVariables,
      );

      if (!smsResult['success']) {
        return smsResult;
      }

      // Try to send push notification as well if FCM token exists
      if (recipientId != null) {
        try {
          await sendPushNotification(
            title: title,
            body: message,
            targetUserId: recipientId,
            targetUserType: recipientType,
          );
        } catch (e) {
          print('⚠️ Push notification failed, but SMS succeeded: $e');
        }
      }

      return {
        'success': true,
        'message': 'Template notification sent successfully',
        'notification_id': smsResult['notification_id'],
        'delivery_methods': ['sms'],
      };
    } catch (e) {
      print('❌ Error sending template notification: $e');
      return {
        'success': false,
        'message': 'Failed to send template notification: ${e.toString()}',
      };
    }
  }

  // ===== FCM PUSH NOTIFICATION METHODS =====

  /// Send push notification using Firebase Cloud Messaging
  Future<Map<String, dynamic>> sendPushNotification({
    required String title,
    required String body,
    String? targetUserId,
    String? targetUserType, // 'customer', 'seller', or 'admin'
    String? topic,
    Map<String, dynamic>? data,
    String? deepLinkUrl,
  }) async {
    try {
      if (!_enablePushNotifications) {
        return {
          'success': false,
          'message': 'Push notifications feature is currently disabled',
        };
      }

      final adminId = _adminAuth.currentAdminId;
      if (adminId == null) {
        return {'success': false, 'message': 'Admin authentication required'};
      }

      print('🔔 Sending push notification: $title');

      // Call Supabase edge function to send FCM notification
      final response = await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'title': title,
          'body': body,
          'target_user_id': targetUserId,
          'target_user_type': targetUserType,
          'topic': topic,
          'data': data ?? {},
          'deep_link_url': deepLinkUrl,
          'admin_id': adminId,
        },
      );

      if (response.status == 200) {
        final responseData = response.data as Map<String, dynamic>;

        await _adminAuth.logAction(
          action: 'send_push_notification',
          resourceType: 'notification',
          metadata: {
            'title': title,
            'target_user_id': targetUserId,
            'target_user_type': targetUserType,
            'topic': topic,
            'has_deep_link': deepLinkUrl != null,
            'test_mode': responseData['delivery_info']?['test_mode'] ?? false,
            'message_id': responseData['message_id'],
          },
        );

        // Check if it's test mode and provide appropriate feedback
        String successMessage =
            responseData['message'] ?? 'Push notification sent successfully';

        if (responseData['delivery_info']?['test_mode'] == true) {
          successMessage +=
              '\n\n⚠️ Note: FCM is in test mode. Configure Firebase Cloud Messaging for production use.';
        }

        return {
          'success': true,
          'message': successMessage,
          'data': responseData,
          'test_mode': responseData['delivery_info']?['test_mode'] ?? false,
          'warning': responseData['warning'],
        };
      } else {
        return {
          'success': false,
          'message':
              'Failed to send push notification: HTTP ${response.status}',
          'error_details': response.data,
        };
      }
    } catch (e) {
      print('❌ Error sending push notification: $e');
      return {
        'success': false,
        'message': 'Error sending push notification: ${e.toString()}',
      };
    }
  }

  /// Send push notification to topic (broadcast)
  Future<Map<String, dynamic>> sendTopicPushNotification({
    required String title,
    required String body,
    required String topic,
    Map<String, dynamic>? data,
    String? deepLinkUrl,
  }) async {
    if (!_enableTopicNotifications) {
      return {
        'success': false,
        'message': 'Topic notifications feature is currently disabled',
      };
    }

    return await sendPushNotification(
      title: title,
      body: body,
      topic: topic,
      data: data,
      deepLinkUrl: deepLinkUrl,
    );
  }

  /// Send targeted push notification to specific user
  Future<Map<String, dynamic>> sendTargetedPushNotification({
    required String title,
    required String body,
    required String targetUserId,
    required String targetUserType,
    Map<String, dynamic>? data,
    String? deepLinkUrl,
  }) async {
    if (!_enableTargetedNotifications) {
      return {
        'success': false,
        'message': 'Targeted notifications feature is currently disabled',
      };
    }

    return await sendPushNotification(
      title: title,
      body: body,
      targetUserId: targetUserId,
      targetUserType: targetUserType,
      data: data,
      deepLinkUrl: deepLinkUrl,
    );
  }

  // ===== UTILITY METHODS =====

  /// Check if SMS notifications are enabled
  bool get isSMSNotificationsEnabled => _enableSMSNotifications;

  /// Check if bulk operations are enabled
  bool get isBulkOperationsEnabled => _enableBulkOperations;

  /// Check if template management is enabled
  bool get isTemplateManagementEnabled => _enableTemplateManagement;

  /// Check if analytics are enabled
  bool get isAnalyticsEnabled => _enableAnalytics;

  /// Check if push notifications are enabled
  bool get isPushNotificationsEnabled => _enablePushNotifications;

  /// Check if topic notifications are enabled
  bool get isTopicNotificationsEnabled => _enableTopicNotifications;

  /// Check if targeted notifications are enabled
  bool get isTargetedNotificationsEnabled => _enableTargetedNotifications;
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
