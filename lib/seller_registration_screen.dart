import 'package:flutter/material.dart';
import 'dart:ui';
import 'services/otp_service_fallback.dart';
import 'screens/otp_verification_screen.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _entityNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _registeredAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _mobileController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstinController = TextEditingController();

  // Services
  final OTPServiceFallback _otpService = OTPServiceFallback();

  // Form state
  String _selectedType = 'Individual'; // Individual or Registered
  String _selectedSellerType = ''; // Meat, Livestock, Both
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _entityNameController.dispose();
    _addressController.dispose();
    _registeredAddressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _mobileController.dispose();
    _aadhaarController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // For larger screens, center the content
              if (constraints.maxWidth > 600) {
                return SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildContent(),
                    ),
                  ),
                );
              }
              // For smaller screens, use full width with padding
              return SingleChildScrollView(child: _buildContent());
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Colors.green.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          width: 1,
          color: Colors.white.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Form
              _buildForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          left: 8,
          right: 16,
          top: 8,
          bottom: 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF059669), // emerald-600
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Seller Registration',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type selection
            _buildTypeSelection(),
            const SizedBox(height: 24),

            // Seller type selection
            _buildSellerTypeSelection(),
            const SizedBox(height: 24),

            // Dynamic form fields based on type
            if (_selectedType == 'Individual') ..._buildIndividualFields(),
            if (_selectedType == 'Registered') ..._buildRegisteredFields(),

            const SizedBox(height: 32),

            // Login link
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                },
                child: RichText(
                  text: TextSpan(
                    text: 'Already Registered? ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Login Here',
                        style: TextStyle(
                          color: const Color(0xFF059669),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Send OTP button
            _buildSendOTPButton(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildRadioOption(
              'Individual',
              _selectedType == 'Individual',
              (value) {
                setState(() {
                  _selectedType = 'Individual';
                });
              },
            ),
            _buildRadioOption(
              'Registered',
              _selectedType == 'Registered',
              (value) {
                setState(() {
                  _selectedType = 'Registered';
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSellerTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Type of Seller *',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildRadioOption('Meat', _selectedSellerType == 'Meat', (value) {
              setState(() {
                _selectedSellerType = 'Meat';
              });
            }),
            _buildRadioOption('Livestock',
                _selectedSellerType == 'Livestock', (value) {
              setState(() {
                _selectedSellerType = 'Livestock';
              });
            }),
            _buildRadioOption('Both', _selectedSellerType == 'Both', (value) {
              setState(() {
                _selectedSellerType = 'Both';
              });
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildRadioOption(
    String title,
    bool isSelected,
    Function(bool?) onChanged,
  ) {
    return GestureDetector(
      onTap: () => onChanged(true),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 110),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF059669).withValues(alpha: 0.1)
                : Colors.grey[50],
            border: Border.all(
              color: isSelected ? const Color(0xFF059669) : Colors.grey[300]!,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF059669)
                        : Colors.grey[400]!,
                    width: 2,
                  ),
                  color: isSelected
                      ? const Color(0xFF059669)
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF059669)
                        : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildIndividualFields() {
    return [
      // First Name and Last Name row
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _firstNameController,
              label: 'First Name *',
              hint: 'Enter first name',
              isRequired: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTextField(
              controller: _lastNameController,
              label: 'Last Name',
              hint: 'Enter last name',
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Address
      _buildTextField(
        controller: _addressController,
        label: 'Address *',
        hint: 'Enter your address',
        isRequired: true,
      ),
      const SizedBox(height: 20),

      // City and Pincode row
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _cityController,
              label: 'City *',
              hint: 'Enter city',
              isRequired: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTextField(
              controller: _pincodeController,
              label: 'Pincode *',
              hint: '6-digit pincode',
              isRequired: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Mobile and Aadhaar row
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _mobileController,
              label: 'Mobile Number *',
              hint: '10-digit mobile number',
              isRequired: true,
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTextField(
              controller: _aadhaarController,
              label: 'Aadhaar Number *',
              hint: '12-digit Aadhaar',
              isRequired: true,
              keyboardType: TextInputType.number,
              maxLength: 12,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Email
      _buildTextField(
        controller: _emailController,
        label: 'Email',
        hint: 'example@email.com',
        keyboardType: TextInputType.emailAddress,
      ),
    ];
  }

  List<Widget> _buildRegisteredFields() {
    return [
      // Entity Full Name
      _buildTextField(
        controller: _entityNameController,
        label: 'Entity Full Name *',
        hint: 'Enter company/entity name',
        isRequired: true,
      ),
      const SizedBox(height: 20),

      // Registered Address
      _buildTextField(
        controller: _registeredAddressController,
        label: 'Registered Address *',
        hint: 'Enter registered address',
        isRequired: true,
      ),
      const SizedBox(height: 20),

      // City and Pincode row
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _cityController,
              label: 'City *',
              hint: 'Enter city',
              isRequired: true,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTextField(
              controller: _pincodeController,
              label: 'Pincode *',
              hint: '6-digit pincode',
              isRequired: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // GSTIN and Mobile row
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _gstinController,
              label: 'GSTIN (if applicable)',
              hint: 'Enter GSTIN',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTextField(
              controller: _mobileController,
              label: 'Mobile Number *',
              hint: '10-digit mobile',
              isRequired: true,
              keyboardType: TextInputType.phone,
              maxLength: 10,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // Email
      _buildTextField(
        controller: _emailController,
        label: 'Email',
        hint: 'example@email.com',
        keyboardType: TextInputType.emailAddress,
      ),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: const Color(0xFF059669).withValues(alpha: 0.6),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF059669), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            counterText: '', // Hide character counter
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildSendOTPButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _sendOTP,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF059669),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Send OTP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSellerType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select seller type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_mobileController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter mobile number'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if seller already exists
      final existsResult = await _otpService.checkSellerExists(
        _mobileController.text.trim(),
      );

      if (existsResult['exists'] == true) {
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Mobile number already registered. Please use login instead.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Send OTP
      final result = await _otpService.sendOTP(_mobileController.text.trim());

      setState(() {
        _isLoading = false;
      });

      if (result['success']) {
        // Navigate to OTP verification screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(
                phoneNumber: _mobileController.text.trim(),
                purpose: 'registration',
                sellerData: _buildSellerData(),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send OTP. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _buildSellerData() {
    // Database expects exact enum values: "Meat", "Livestock", "Both"
    Map<String, dynamic> data = {
      'seller_type': _selectedSellerType, // Use exact UI value
      'contact_email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'business_city': _cityController.text.trim(),
      'business_pincode': _pincodeController.text.trim(),
    };

    if (_selectedType == 'Individual') {
      data['seller_name'] =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
              .trim();
      data['business_address'] = _addressController.text.trim();
      data['aadhaar_number'] = _aadhaarController.text.trim();
      data['user_type'] = 'seller'; // Fixed: database expects 'seller'
    } else {
      data['seller_name'] = _entityNameController.text.trim();
      data['business_address'] = _registeredAddressController.text.trim();
      data['gstin'] = _gstinController.text.trim().isEmpty
          ? null
          : _gstinController.text.trim();
      data['user_type'] = 'seller'; // Fixed: database expects 'seller'
    }

    // Set seller capabilities
    if (_selectedSellerType == 'Meat') {
      data['meat_shop_status'] = true;
      data['livestock_status'] = false;
    } else if (_selectedSellerType == 'Livestock') {
      data['meat_shop_status'] = false;
      data['livestock_status'] = true;
    } else {
      // Both
      data['meat_shop_status'] = true;
      data['livestock_status'] = true;
    }

    return data;
  }
}
