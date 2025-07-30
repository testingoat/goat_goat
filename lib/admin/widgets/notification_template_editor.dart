import 'package:flutter/material.dart';
import '../services/notification_service.dart';

/// Notification Template Editor Widget
///
/// Features:
/// - Create/edit notification templates
/// - Variable substitution preview
/// - Template validation
/// - Zero-risk implementation with feature flags
class NotificationTemplateEditor extends StatefulWidget {
  final Map<String, dynamic>? template;
  final VoidCallback? onSaved;
  final VoidCallback? onCancelled;

  const NotificationTemplateEditor({
    super.key,
    this.template,
    this.onSaved,
    this.onCancelled,
  });

  @override
  State<NotificationTemplateEditor> createState() =>
      _NotificationTemplateEditorState();
}

class _NotificationTemplateEditorState
    extends State<NotificationTemplateEditor> {
  final NotificationService _notificationService = NotificationService();
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _templateNameController = TextEditingController();
  final _titleTemplateController = TextEditingController();
  final _messageTemplateController = TextEditingController();
  final _variablesController = TextEditingController();

  // Form state
  String _selectedTemplateType = 'custom';
  bool _isActive = true;
  bool _isLoading = false;
  String? _error;

  // Delivery method state
  bool _enableSMS = true;
  bool _enablePushNotification = true;
  String _pushTarget = 'all';
  final _specificUserController = TextEditingController();
  final _deepLinkController = TextEditingController();

  // Preview state
  Map<String, dynamic> _previewVariables = {};
  String _previewTitle = '';
  String _previewMessage = '';

  final List<String> _templateTypes = [
    'order',
    'review',
    'promotion',
    'system',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _titleTemplateController.dispose();
    _messageTemplateController.dispose();
    _variablesController.dispose();
    _specificUserController.dispose();
    _deepLinkController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.template != null) {
      final template = widget.template!;
      _templateNameController.text = template['template_name'] ?? '';
      _titleTemplateController.text = template['title_template'] ?? '';
      _messageTemplateController.text = template['message_template'] ?? '';
      _selectedTemplateType = template['template_type'] ?? 'custom';
      _isActive = template['is_active'] ?? true;

      // Convert template variables array to comma-separated string
      final variables = template['template_variables'] as List<dynamic>? ?? [];
      _variablesController.text = variables.join(', ');

      // Initialize preview variables with sample data
      _initializePreviewVariables(variables.cast<String>());
    }

    // Add listeners for real-time preview
    _titleTemplateController.addListener(_updatePreview);
    _messageTemplateController.addListener(_updatePreview);
    _variablesController.addListener(_updatePreview);
  }

  void _initializePreviewVariables(List<String> variables) {
    _previewVariables = {};
    for (final variable in variables) {
      switch (variable.toLowerCase()) {
        case 'customer_name':
          _previewVariables[variable] = 'John Doe';
          break;
        case 'order_number':
        case 'order_id':
          _previewVariables[variable] = 'ORD-12345';
          break;
        case 'total_amount':
          _previewVariables[variable] = '₹299.99';
          break;
        case 'product_name':
          _previewVariables[variable] = 'Fresh Chicken';
          break;
        case 'delivery_date':
          _previewVariables[variable] = 'Tomorrow';
          break;
        case 'stock_count':
          _previewVariables[variable] = '5';
          break;
        default:
          _previewVariables[variable] = 'Sample Value';
      }
    }
    _updatePreview();
  }

  void _updatePreview() {
    final variables = _variablesController.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    // Update preview variables if new variables are added
    for (final variable in variables) {
      if (!_previewVariables.containsKey(variable)) {
        _previewVariables[variable] = 'Sample Value';
      }
    }

    // Remove variables that are no longer in the list
    _previewVariables.removeWhere((key, value) => !variables.contains(key));

    // Update preview
    _notificationService
        .previewTemplate(
          titleTemplate: _titleTemplateController.text,
          messageTemplate: _messageTemplateController.text,
          variables: _previewVariables,
        )
        .then((result) {
          if (result['success'] && mounted) {
            setState(() {
              _previewTitle = result['rendered_title'] ?? '';
              _previewMessage = result['rendered_message'] ?? '';
            });
          }
        });
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final variables = _variablesController.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();

      Map<String, dynamic> result;

      if (widget.template != null) {
        // Update existing template
        result = await _notificationService.updateNotificationTemplate(
          templateId: widget.template!['id'],
          templateName: _templateNameController.text,
          templateType: _selectedTemplateType,
          titleTemplate: _titleTemplateController.text,
          messageTemplate: _messageTemplateController.text,
          templateVariables: variables,
          isActive: _isActive,
        );
      } else {
        // Create new template
        result = await _notificationService.createNotificationTemplate(
          templateName: _templateNameController.text,
          templateType: _selectedTemplateType,
          titleTemplate: _titleTemplateController.text,
          messageTemplate: _messageTemplateController.text,
          templateVariables: variables,
          isActive: _isActive,
        );
      }

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.green,
            ),
          );
          widget.onSaved?.call();
        }
      } else {
        setState(() {
          _error = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save template: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.description, size: 24, color: Colors.green[600]),
                const SizedBox(width: 12),
                Text(
                  widget.template != null ? 'Edit Template' : 'Create Template',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onCancelled,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red[600]),
                      ),
                    ),
                  ],
                ),
              ),

            // Form and Preview
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Section
                  Expanded(flex: 1, child: _buildFormSection()),

                  const SizedBox(width: 24),

                  // Preview Section
                  Expanded(flex: 1, child: _buildPreviewSection()),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancelled,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveTemplate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(widget.template != null ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Template Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Template Name
            TextFormField(
              controller: _templateNameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'e.g., order_confirmed',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Template name is required';
                }
                if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                  return 'Use only lowercase letters, numbers, and underscores';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Template Type
            DropdownButtonFormField<String>(
              value: _selectedTemplateType,
              decoration: const InputDecoration(
                labelText: 'Template Type',
                border: OutlineInputBorder(),
              ),
              items: _templateTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTemplateType = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            // Title Template
            TextFormField(
              controller: _titleTemplateController,
              decoration: const InputDecoration(
                labelText: 'Title Template',
                hintText: 'e.g., Order #{order_number} Confirmed',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Title template is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Message Template
            TextFormField(
              controller: _messageTemplateController,
              decoration: const InputDecoration(
                labelText: 'Message Template',
                hintText: 'Your order #{order_number} has been confirmed...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Message template is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Template Variables
            TextFormField(
              controller: _variablesController,
              decoration: const InputDecoration(
                labelText: 'Template Variables',
                hintText: 'order_number, customer_name, total_amount',
                helperText: 'Comma-separated list of variables',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Methods Section
            _buildDeliveryMethodSection(),

            const SizedBox(height: 16),

            // Active Toggle
            SwitchListTile(
              title: const Text('Active'),
              subtitle: const Text('Enable this template for use'),
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // Variable Help
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[600], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Variable Usage',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use {variable_name} in your templates. Common variables:\n'
                    '• {customer_name} - Customer\'s name\n'
                    '• {order_number} - Order ID\n'
                    '• {total_amount} - Order total\n'
                    '• {product_name} - Product name\n'
                    '• {delivery_date} - Delivery date',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Preview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Preview
                Text(
                  'Title:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _previewTitle.isEmpty
                      ? 'Enter title template...'
                      : _previewTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _previewTitle.isEmpty
                        ? Colors.grey[400]
                        : Colors.black,
                  ),
                ),

                const SizedBox(height: 16),

                // Message Preview
                Text(
                  'Message:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _previewMessage.isEmpty
                      ? 'Enter message template...'
                      : _previewMessage,
                  style: TextStyle(
                    color: _previewMessage.isEmpty
                        ? Colors.grey[400]
                        : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Preview Variables
          if (_previewVariables.isNotEmpty) ...[
            Text(
              'Sample Variables:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _previewVariables.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '{${entry.key}} → ${entry.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build delivery method selection section
  Widget _buildDeliveryMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Delivery Methods',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // SMS Toggle
        CheckboxListTile(
          title: const Text('SMS'),
          subtitle: const Text('Send via SMS using Fast2SMS'),
          value: _enableSMS,
          onChanged: (value) => setState(() => _enableSMS = value ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),

        // Push Notification Toggle
        if (_notificationService.isPushNotificationsEnabled)
          CheckboxListTile(
            title: const Text('Push Notification'),
            subtitle: const Text('Send via Firebase Cloud Messaging'),
            value: _enablePushNotification,
            onChanged: (value) =>
                setState(() => _enablePushNotification = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
          ),

        // Push Notification Options
        if (_enablePushNotification &&
            _notificationService.isPushNotificationsEnabled) ...[
          const SizedBox(height: 16),
          _buildPushNotificationOptions(),
        ],
      ],
    );
  }

  /// Build push notification options
  Widget _buildPushNotificationOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Push Notification Options',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Target Selection
          DropdownButtonFormField<String>(
            value: _pushTarget,
            decoration: const InputDecoration(
              labelText: 'Target Audience',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Users')),
              DropdownMenuItem(
                value: 'customers',
                child: Text('Customers Only'),
              ),
              DropdownMenuItem(value: 'sellers', child: Text('Sellers Only')),
              DropdownMenuItem(value: 'specific', child: Text('Specific User')),
            ],
            onChanged: (value) => setState(() => _pushTarget = value ?? 'all'),
          ),

          // Specific User Input
          if (_pushTarget == 'specific') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _specificUserController,
              decoration: const InputDecoration(
                labelText: 'User ID or Phone Number',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Deep Link URL
          TextFormField(
            controller: _deepLinkController,
            decoration: const InputDecoration(
              labelText: 'Deep Link URL (optional)',
              hintText: '/product/123 or /orders',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

          const SizedBox(height: 8),

          // Help text
          Text(
            'Deep links allow users to navigate directly to specific screens when they tap the notification.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
