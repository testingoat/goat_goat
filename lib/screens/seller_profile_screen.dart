import 'package:flutter/material.dart';
import '../supabase_service.dart';

class SellerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> seller;

  const SellerProfileScreen({super.key, required this.seller});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  late TextEditingController _sellerNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _businessCityController;
  late TextEditingController _businessAddressController;
  late TextEditingController _businessPincodeController;
  late TextEditingController _gstinController;
  late TextEditingController _fssaiLicenseController;
  late TextEditingController _bankAccountController;
  late TextEditingController _ifscCodeController;
  late TextEditingController _accountHolderController;
  late TextEditingController _aadhaarController;

  // Notification preferences
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _pushNotifications = false;

  bool _isLoading = false;
  bool _isEditing = false;

  // Current seller data (updated after successful saves)
  late Map<String, dynamic> _currentSellerData;

  // Audit trail (in-memory for now)
  final List<Map<String, dynamic>> _auditTrail = [];

  @override
  void initState() {
    super.initState();
    _currentSellerData = Map<String, dynamic>.from(widget.seller);
    _initializeControllers();
  }

  void _initializeControllers() {
    _sellerNameController = TextEditingController(
      text: _currentSellerData['seller_name'] ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: _currentSellerData['contact_phone'] ?? '',
    );
    _businessCityController = TextEditingController(
      text: _currentSellerData['business_city'] ?? '',
    );
    _businessAddressController = TextEditingController(
      text: _currentSellerData['business_address'] ?? '',
    );
    _businessPincodeController = TextEditingController(
      text: _currentSellerData['business_pincode'] ?? '',
    );
    _gstinController = TextEditingController(
      text: _currentSellerData['gstin'] ?? '',
    );
    _fssaiLicenseController = TextEditingController(
      text: _currentSellerData['fssai_license'] ?? '',
    );
    _bankAccountController = TextEditingController(
      text: _currentSellerData['bank_account_number'] ?? '',
    );
    _ifscCodeController = TextEditingController(
      text: _currentSellerData['ifsc_code'] ?? '',
    );
    _accountHolderController = TextEditingController(
      text: _currentSellerData['account_holder_name'] ?? '',
    );
    _aadhaarController = TextEditingController(
      text: _currentSellerData['aadhaar_number'] ?? '',
    );

    // Initialize notification preferences
    _emailNotifications = _currentSellerData['notification_email'] ?? true;
    _smsNotifications = _currentSellerData['notification_sms'] ?? true;
    _pushNotifications = _currentSellerData['notification_push'] ?? false;
  }

  @override
  void dispose() {
    _sellerNameController.dispose();
    _contactPhoneController.dispose();
    _businessCityController.dispose();
    _businessAddressController.dispose();
    _businessPincodeController.dispose();
    _gstinController.dispose();
    _fssaiLicenseController.dispose();
    _bankAccountController.dispose();
    _ifscCodeController.dispose();
    _accountHolderController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

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
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildProfileForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF059669), const Color(0xFF047857)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Seller Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
    );
  }

  Widget _buildProfileForm() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(Icons.store, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.seller['seller_name'] ?? 'Seller Name',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.seller['approval_status'] == 'approved'
                                ? Colors.green[100]
                                : Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.seller['approval_status']
                                    ?.toString()
                                    .toUpperCase() ??
                                'PENDING',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  widget.seller['approval_status'] == 'approved'
                                  ? Colors.green[700]
                                  : Colors.orange[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Personal Information Section
              _buildSectionHeader('Personal Information'),
              _buildCriticalField(
                label: 'Seller Name *',
                value: _currentSellerData['seller_name'] ?? 'Not Set',
                icon: Icons.person,
                restrictionMessage:
                    'Please contact Admin for Seller Name Change',
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _contactPhoneController,
                label: 'Contact Phone *',
                icon: Icons.phone,
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Contact phone is required';
                  }
                  if (value.length != 10) {
                    return 'Phone number must be 10 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _aadhaarController,
                label: 'Aadhaar Number',
                icon: Icons.credit_card,
                enabled: _isEditing,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length != 12) {
                    return 'Aadhaar number must be 12 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Business Details Section
              _buildSectionHeader('Business Details'),
              _buildCriticalField(
                label: 'Seller Type',
                value:
                    _currentSellerData['seller_type']
                        ?.toString()
                        .toUpperCase() ??
                    'NOT SET',
                icon: Icons.category,
                restrictionMessage:
                    'Please contact Admin for Seller Type Change',
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _businessAddressController,
                label: 'Business Address',
                icon: Icons.location_on,
                enabled: _isEditing,
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _businessCityController,
                      label: 'Business City',
                      icon: Icons.location_city,
                      enabled: _isEditing,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _businessPincodeController,
                      label: 'Pincode',
                      icon: Icons.pin_drop,
                      enabled: _isEditing,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Licenses & Compliance Section
              _buildSectionHeader('Licenses & Compliance'),
              _buildTextField(
                controller: _gstinController,
                label: 'GSTIN',
                icon: Icons.receipt_long,
                enabled: _isEditing,
                hint: 'GST Identification Number',
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _fssaiLicenseController,
                label: 'FSSAI License',
                icon: Icons.verified,
                enabled: _isEditing,
                hint: 'Food Safety License Number',
              ),
              const SizedBox(height: 24),

              // Banking Information Section
              _buildSectionHeader('Banking Information'),
              _buildTextField(
                controller: _bankAccountController,
                label: 'Bank Account Number',
                icon: Icons.account_balance,
                enabled: _isEditing,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _ifscCodeController,
                      label: 'IFSC Code',
                      icon: Icons.code,
                      enabled: _isEditing,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _accountHolderController,
                      label: 'Account Holder Name',
                      icon: Icons.person_outline,
                      enabled: _isEditing,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notification Preferences Section
              _buildSectionHeader('Notification Preferences'),
              _buildNotificationTile(
                title: 'Email Notifications',
                subtitle: 'Receive updates via email',
                value: _emailNotifications,
                onChanged: _isEditing
                    ? (value) {
                        setState(() {
                          _emailNotifications = value;
                        });
                      }
                    : null,
                icon: Icons.email,
              ),
              const SizedBox(height: 8),

              _buildNotificationTile(
                title: 'SMS Notifications',
                subtitle: 'Receive updates via SMS',
                value: _smsNotifications,
                onChanged: _isEditing
                    ? (value) {
                        setState(() {
                          _smsNotifications = value;
                        });
                      }
                    : null,
                icon: Icons.sms,
              ),
              const SizedBox(height: 8),

              _buildNotificationTile(
                title: 'Push Notifications',
                subtitle: 'Receive app notifications',
                value: _pushNotifications,
                onChanged: _isEditing
                    ? (value) {
                        setState(() {
                          _pushNotifications = value;
                        });
                      }
                    : null,
                icon: Icons.notifications,
              ),
              const SizedBox(height: 24),

              // Account Status Section
              _buildSectionHeader('Account Status'),
              _buildReadOnlyField(
                label: 'Approval Status',
                value:
                    _currentSellerData['approval_status']
                        ?.toString()
                        .toUpperCase() ??
                    'PENDING',
                icon: Icons.verified_user,
                valueColor: _currentSellerData['approval_status'] == 'approved'
                    ? Colors.green[700]
                    : Colors.orange[700],
              ),
              const SizedBox(height: 16),

              _buildReadOnlyField(
                label: 'Member Since',
                value: _formatDate(_currentSellerData['created_at']),
                icon: Icons.calendar_today,
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (_isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _cancelEdit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: enabled ? const Color(0xFF059669) : Colors.grey,
            ),
            hintText: hint ?? 'Enter $label',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            filled: !enabled,
            fillColor: enabled ? null : Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
    });
    // Reset controllers to original values
    _initializeControllers();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Track changes for audit trail
      final changes = <String, Map<String, dynamic>>{};

      // Check each field for changes and prepare update data
      final updatedData = <String, dynamic>{};

      // Personal Information (contact_phone only - seller_name is restricted)
      if (_contactPhoneController.text.trim() !=
          (_currentSellerData['contact_phone'] ?? '')) {
        final oldValue = _currentSellerData['contact_phone'];
        final newValue = _contactPhoneController.text.trim();
        changes['contact_phone'] = {'old': oldValue, 'new': newValue};
        updatedData['contact_phone'] = newValue;
      }

      if (_aadhaarController.text.trim() !=
          (_currentSellerData['aadhaar_number'] ?? '')) {
        final oldValue = _currentSellerData['aadhaar_number'];
        final newValue = _aadhaarController.text.trim().isEmpty
            ? null
            : _aadhaarController.text.trim();
        changes['aadhaar_number'] = {'old': oldValue, 'new': newValue};
        updatedData['aadhaar_number'] = newValue;
      }

      // Business Details
      if (_businessAddressController.text.trim() !=
          (_currentSellerData['business_address'] ?? '')) {
        final oldValue = _currentSellerData['business_address'];
        final newValue = _businessAddressController.text.trim().isEmpty
            ? null
            : _businessAddressController.text.trim();
        changes['business_address'] = {'old': oldValue, 'new': newValue};
        updatedData['business_address'] = newValue;
      }

      if (_businessCityController.text.trim() !=
          (_currentSellerData['business_city'] ?? '')) {
        final oldValue = _currentSellerData['business_city'];
        final newValue = _businessCityController.text.trim().isEmpty
            ? null
            : _businessCityController.text.trim();
        changes['business_city'] = {'old': oldValue, 'new': newValue};
        updatedData['business_city'] = newValue;
      }

      if (_businessPincodeController.text.trim() !=
          (_currentSellerData['business_pincode'] ?? '')) {
        final oldValue = _currentSellerData['business_pincode'];
        final newValue = _businessPincodeController.text.trim().isEmpty
            ? null
            : _businessPincodeController.text.trim();
        changes['business_pincode'] = {'old': oldValue, 'new': newValue};
        updatedData['business_pincode'] = newValue;
      }

      // Licenses & Compliance
      if (_gstinController.text.trim() != (_currentSellerData['gstin'] ?? '')) {
        final oldValue = _currentSellerData['gstin'];
        final newValue = _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim();
        changes['gstin'] = {'old': oldValue, 'new': newValue};
        updatedData['gstin'] = newValue;
      }

      if (_fssaiLicenseController.text.trim() !=
          (_currentSellerData['fssai_license'] ?? '')) {
        final oldValue = _currentSellerData['fssai_license'];
        final newValue = _fssaiLicenseController.text.trim().isEmpty
            ? null
            : _fssaiLicenseController.text.trim();
        changes['fssai_license'] = {'old': oldValue, 'new': newValue};
        updatedData['fssai_license'] = newValue;
      }

      // Banking Information
      if (_bankAccountController.text.trim() !=
          (_currentSellerData['bank_account_number'] ?? '')) {
        final oldValue = _currentSellerData['bank_account_number'];
        final newValue = _bankAccountController.text.trim().isEmpty
            ? null
            : _bankAccountController.text.trim();
        changes['bank_account_number'] = {'old': oldValue, 'new': newValue};
        updatedData['bank_account_number'] = newValue;
      }

      if (_ifscCodeController.text.trim() !=
          (_currentSellerData['ifsc_code'] ?? '')) {
        final oldValue = _currentSellerData['ifsc_code'];
        final newValue = _ifscCodeController.text.trim().isEmpty
            ? null
            : _ifscCodeController.text.trim();
        changes['ifsc_code'] = {'old': oldValue, 'new': newValue};
        updatedData['ifsc_code'] = newValue;
      }

      if (_accountHolderController.text.trim() !=
          (_currentSellerData['account_holder_name'] ?? '')) {
        final oldValue = _currentSellerData['account_holder_name'];
        final newValue = _accountHolderController.text.trim().isEmpty
            ? null
            : _accountHolderController.text.trim();
        changes['account_holder_name'] = {'old': oldValue, 'new': newValue};
        updatedData['account_holder_name'] = newValue;
      }

      // Notification Preferences
      if (_emailNotifications !=
          (_currentSellerData['notification_email'] ?? true)) {
        final oldValue = _currentSellerData['notification_email'];
        final newValue = _emailNotifications;
        changes['notification_email'] = {'old': oldValue, 'new': newValue};
        updatedData['notification_email'] = newValue;
      }

      if (_smsNotifications !=
          (_currentSellerData['notification_sms'] ?? true)) {
        final oldValue = _currentSellerData['notification_sms'];
        final newValue = _smsNotifications;
        changes['notification_sms'] = {'old': oldValue, 'new': newValue};
        updatedData['notification_sms'] = newValue;
      }

      if (_pushNotifications !=
          (_currentSellerData['notification_push'] ?? false)) {
        final oldValue = _currentSellerData['notification_push'];
        final newValue = _pushNotifications;
        changes['notification_push'] = {'old': oldValue, 'new': newValue};
        updatedData['notification_push'] = newValue;
      }

      // If no changes, show message and return
      if (updatedData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes to save'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isEditing = false;
        });
        return;
      }

      // Add audit timestamp
      updatedData['updated_at'] = DateTime.now().toIso8601String();

      // Update seller in Supabase
      final result = await _supabaseService.updateSeller(
        _currentSellerData['id'],
        updatedData,
      );

      if (mounted) {
        if (result['success']) {
          // Update current seller data with new values
          _currentSellerData.addAll(updatedData);

          // Add to audit trail (in-memory for now)
          for (final fieldName in changes.keys) {
            _auditTrail.add({
              'seller_id': _currentSellerData['id'],
              'field_name': fieldName,
              'old_value': changes[fieldName]!['old']?.toString(),
              'new_value': changes[fieldName]!['new']?.toString(),
              'changed_at': DateTime.now().toIso8601String(),
              'changed_by': 'seller_self', // Self-service change
            });
          }

          print('🔍 AUDIT TRAIL - ${changes.length} changes recorded:');
          for (final change in changes.entries) {
            print(
              '  • ${change.key}: "${change.value['old']}" → "${change.value['new']}"',
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile updated successfully! (${changes.length} changes)',
              ),
              backgroundColor: const Color(0xFF059669),
            ),
          );

          setState(() {
            _isEditing = false;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Failed to update profile'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Build section header with consistent styling
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF059669),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Build read-only field for display-only information
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? Colors.black87,
                    fontWeight: valueColor != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build notification preference tile
  Widget _buildNotificationTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        secondary: Icon(icon, color: const Color(0xFF059669)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF059669),
        activeTrackColor: const Color(0xFF059669).withValues(alpha: 0.3),
      ),
    );
  }

  /// Build critical field with restriction message
  Widget _buildCriticalField({
    required String label,
    required String value,
    required IconData icon,
    required String restrictionMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            border: Border.all(color: Colors.red[200]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.red[600], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.red[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.lock, color: Colors.red[600], size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.red[700]),
                    const SizedBox(width: 4),
                    Text(
                      restrictionMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Format date for display
  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not available';

    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
