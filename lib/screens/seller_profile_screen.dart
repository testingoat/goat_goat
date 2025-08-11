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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _sellerNameController = TextEditingController(
      text: widget.seller['seller_name'] ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: widget.seller['contact_phone'] ?? '',
    );
    _businessCityController = TextEditingController(
      text: widget.seller['business_city'] ?? '',
    );
    _businessAddressController = TextEditingController(
      text: widget.seller['business_address'] ?? '',
    );
    _businessPincodeController = TextEditingController(
      text: widget.seller['business_pincode'] ?? '',
    );
    _gstinController = TextEditingController(
      text: widget.seller['gstin'] ?? '',
    );
    _fssaiLicenseController = TextEditingController(
      text: widget.seller['fssai_license'] ?? '',
    );
    _bankAccountController = TextEditingController(
      text: widget.seller['bank_account_number'] ?? '',
    );
    _ifscCodeController = TextEditingController(
      text: widget.seller['ifsc_code'] ?? '',
    );
    _accountHolderController = TextEditingController(
      text: widget.seller['account_holder_name'] ?? '',
    );
    _aadhaarController = TextEditingController(
      text: widget.seller['aadhaar_number'] ?? '',
    );

    // Initialize notification preferences
    _emailNotifications = widget.seller['notification_email'] ?? true;
    _smsNotifications = widget.seller['notification_sms'] ?? true;
    _pushNotifications = widget.seller['notification_push'] ?? false;
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
              _buildTextField(
                controller: _sellerNameController,
                label: 'Seller Name *',
                icon: Icons.person,
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Seller name is required';
                  }
                  return null;
                },
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
              _buildReadOnlyField(
                label: 'Seller Type',
                value:
                    widget.seller['seller_type']?.toString().toUpperCase() ??
                    'NOT SET',
                icon: Icons.category,
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
                    widget.seller['approval_status']
                        ?.toString()
                        .toUpperCase() ??
                    'PENDING',
                icon: Icons.verified_user,
                valueColor: widget.seller['approval_status'] == 'approved'
                    ? Colors.green[700]
                    : Colors.orange[700],
              ),
              const SizedBox(height: 16),

              _buildReadOnlyField(
                label: 'Member Since',
                value: _formatDate(widget.seller['created_at']),
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
      // Prepare updated data with all profile fields
      final updatedData = {
        // Personal Information
        'seller_name': _sellerNameController.text.trim(),
        'contact_phone': _contactPhoneController.text.trim(),
        'aadhaar_number': _aadhaarController.text.trim().isEmpty
            ? null
            : _aadhaarController.text.trim(),

        // Business Details
        'business_address': _businessAddressController.text.trim().isEmpty
            ? null
            : _businessAddressController.text.trim(),
        'business_city': _businessCityController.text.trim().isEmpty
            ? null
            : _businessCityController.text.trim(),
        'business_pincode': _businessPincodeController.text.trim().isEmpty
            ? null
            : _businessPincodeController.text.trim(),

        // Licenses & Compliance
        'gstin': _gstinController.text.trim().isEmpty
            ? null
            : _gstinController.text.trim(),
        'fssai_license': _fssaiLicenseController.text.trim().isEmpty
            ? null
            : _fssaiLicenseController.text.trim(),

        // Banking Information
        'bank_account_number': _bankAccountController.text.trim().isEmpty
            ? null
            : _bankAccountController.text.trim(),
        'ifsc_code': _ifscCodeController.text.trim().isEmpty
            ? null
            : _ifscCodeController.text.trim(),
        'account_holder_name': _accountHolderController.text.trim().isEmpty
            ? null
            : _accountHolderController.text.trim(),

        // Notification Preferences
        'notification_email': _emailNotifications,
        'notification_sms': _smsNotifications,
        'notification_push': _pushNotifications,

        // Audit
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Update seller in Supabase
      final result = await _supabaseService.updateSeller(
        widget.seller['id'],
        updatedData,
      );

      if (mounted) {
        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Color(0xFF059669),
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
