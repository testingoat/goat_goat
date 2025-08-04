import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:async';
import '../services/otp_service_fallback.dart';
import '../services/fcm_service.dart';
import '../services/auth_service.dart';
import 'seller_dashboard_screen.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String purpose; // 'registration' or 'login'
  final Map<String, dynamic>? sellerData; // Only for registration

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.purpose,
    this.sellerData,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final OTPServiceFallback _otpService = OTPServiceFallback();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 30;
  Timer? _timer;
  String _errorMessage = '';
  final String _demoOtp = ''; // For showing demo OTP

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (_otpCode.length == 6) {
      _verifyOTP();
    }

    setState(() {
      _errorMessage = '';
    });
  }

  Future<void> _verifyOTP() async {
    if (_otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter complete 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _otpService.verifyOTP(widget.phoneNumber, _otpCode);

      if (result['success']) {
        if (widget.purpose == 'registration') {
          await _handleRegistration();
        } else {
          await _handleLogin();
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
          _isLoading = false;
        });
        _clearOTP();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Verification failed. Please try again.';
        _isLoading = false;
      });
      _clearOTP();
    }
  }

  Future<void> _handleRegistration() async {
    if (widget.sellerData == null) {
      setState(() {
        _errorMessage = 'Registration data missing';
        _isLoading = false;
      });
      return;
    }

    final result = await _otpService.registerSeller(
      phoneNumber: widget.phoneNumber,
      sellerData: widget.sellerData!,
    );

    if (result['success']) {
      _navigateToDashboard(
        result['seller'],
        'Registration successful! Welcome to GoatGoat.',
      );
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogin() async {
    final result = await _otpService.loginSeller(widget.phoneNumber);

    if (result['success']) {
      _navigateToDashboard(result['seller'], 'Login successful! Welcome back.');
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });
    }
  }

  /// Store FCM token for seller after successful login
  Future<void> _storeFCMTokenForSeller(Map<String, dynamic> seller) async {
    try {
      final fcmService = FCMService();
      if (fcmService.isInitialized && seller['id'] != null) {
        await fcmService.storeTokenForSeller(seller['id']);
      }
    } catch (e) {
      // Non-critical error - don't block login flow
      print('Warning: Failed to store FCM token for seller - $e');
    }
  }

  void _navigateToDashboard(Map<String, dynamic> seller, String message) {
    // Store FCM token for seller after successful login
    _storeFCMTokenForSeller(seller);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Icon(
          Icons.check_circle,
          color: Color(0xFF059669),
          size: 48,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog

              // Save seller session for persistent login
              await _authService.saveSellerSession(seller);

              // Navigate to dashboard and clear all previous routes
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => SellerDashboardScreen(seller: seller),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Continue to Dashboard',
              style: TextStyle(
                color: Color(0xFF059669),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearOTP() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    final result = await _otpService.resendOTP(widget.phoneNumber);

    setState(() {
      _isResending = false;
    });

    if (result['success']) {
      _startResendTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: const Color(0xFF059669),
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
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
          child: Column(children: [_buildHeader(), _buildOTPForm()]),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF059669),
        borderRadius: const BorderRadius.only(
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
          const Text(
            'Verify OTP',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF059669).withValues(alpha: 0.1),
            ),
            child: const Icon(Icons.sms, size: 48, color: Color(0xFF059669)),
          ),

          const SizedBox(height: 24),

          // Title and description
          Text(
            widget.purpose == 'registration'
                ? 'Complete Registration'
                : 'Verify Your Number',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Enter the 6-digit code sent to\n+91 ${widget.phoneNumber}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),

          const SizedBox(height: 32),

          // OTP Input Fields
          _buildOTPInputs(),

          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 32),

          // Verify Button
          _buildVerifyButton(),

          const SizedBox(height: 24),

          // Resend OTP
          _buildResendSection(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOTPInputs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 45,
          height: 55,
          child: TextFormField(
            controller: _otpControllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF059669),
            ),
            decoration: InputDecoration(
              counterText: '',
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
                borderSide: const BorderSide(
                  color: Color(0xFF059669),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _onOtpChanged(value, index),
            onTap: () {
              _otpControllers[index].selection = TextSelection.fromPosition(
                TextPosition(offset: _otpControllers[index].text.length),
              );
            },
            onEditingComplete: () {
              if (index < 5 && _otpControllers[index].text.isNotEmpty) {
                _focusNodes[index + 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _verifyOTP,
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
                'Verify OTP',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Column(
      children: [
        Text(
          "Didn't receive the code?",
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 8),
        if (_resendCountdown > 0)
          Text(
            'Resend OTP in ${_resendCountdown}s',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          )
        else
          GestureDetector(
            onTap: _isResending ? null : _resendOTP,
            child: Text(
              _isResending ? 'Sending...' : 'Resend OTP',
              style: TextStyle(
                color: _isResending
                    ? Colors.grey[500]
                    : const Color(0xFF059669),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }
}
