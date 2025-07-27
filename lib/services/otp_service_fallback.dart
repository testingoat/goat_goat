import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class OTPServiceFallback {
  static final OTPServiceFallback _instance = OTPServiceFallback._internal();
  factory OTPServiceFallback() => _instance;
  OTPServiceFallback._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Temporary storage for OTPs (in production, this should be in database)
  final Map<String, Map<String, dynamic>> _otpStorage = {};

  /// Generate a 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send OTP with multiple fallback methods
  Future<Map<String, dynamic>> sendOTP(String phoneNumber) async {
    try {
      // Clean phone number (remove any spaces, dashes, etc.)
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Validate phone number format (should be 10 digits for Indian numbers)
      if (cleanPhoneNumber.length != 10) {
        return {
          'success': false,
          'message': 'Please enter a valid 10-digit mobile number',
        };
      }

      // Special case for development number to avoid SMS spamming
      String otpCode;
      bool isDevelopmentNumber = cleanPhoneNumber == '6362924334';

      if (isDevelopmentNumber) {
        // Use fixed OTP for development to avoid spamming
        otpCode = '123456';
      } else {
        // Generate random OTP for other numbers
        otpCode = _generateOTP();
      }

      // Store OTP locally for verification
      _otpStorage[cleanPhoneNumber] = {
        'otp': otpCode,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'attempts': 0,
      };

      // Try to send via Fast2SMS API directly (skip for development number)
      bool smsSent = false;
      if (!isDevelopmentNumber) {
        try {
          await _sendOTPDirectly(cleanPhoneNumber, otpCode);
          smsSent = true;
        } catch (e) {
          print('Direct SMS failed: $e');
          // Continue with demo mode
        }
      } else {
        // For development number, mark as "sent" but don't actually send SMS
        smsSent = true;
      }

      // Also try to store in Supabase for backup
      try {
        await _supabase.from('otp_verifications').insert({
          'phone_number': cleanPhoneNumber,
          'otp_code': otpCode,
          'expires_at': DateTime.now()
              .add(Duration(minutes: 5))
              .toIso8601String(),
          'verified': false,
          'attempts': 0,
        });
      } catch (e) {
        print('Supabase storage failed: $e');
        // Continue anyway
      }

      String message;
      if (isDevelopmentNumber) {
        message = 'Development OTP: 123456 (Fixed for testing)';
      } else if (smsSent) {
        message = 'OTP sent successfully to $cleanPhoneNumber';
      } else {
        message = 'OTP generated for $cleanPhoneNumber (Demo: $otpCode)';
      }

      return {
        'success': true,
        'message': message,
        'phone_number': cleanPhoneNumber,
        'demo_otp': otpCode, // For testing purposes
      };
    } catch (e) {
      print('Error sending OTP: $e');
      return {
        'success': false,
        'message': 'Failed to send OTP. Please try again.',
      };
    }
  }

  /// Direct Fast2SMS API call
  Future<void> _sendOTPDirectly(String phoneNumber, String otpCode) async {
    const apiKey =
        'TBXtyM2OVn0ra5SPdRCH48pghNkzm3w1xFoKIsYJGDEeb7Lvl6wShBusoREfqr0kO3M5jJdexvGQctbn';

    final url = Uri.parse('https://www.fast2sms.com/dev/bulkV2');

    final response = await http.post(
      url,
      headers: {
        'authorization': apiKey,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'variables_values': otpCode,
        'route': 'otp',
        'numbers': phoneNumber,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Fast2SMS API failed: ${response.body}');
    }

    final responseData = json.decode(response.body);
    if (responseData['return'] != true) {
      throw Exception('Fast2SMS API error: ${responseData['message']}');
    }
  }

  /// Verify OTP code
  Future<Map<String, dynamic>> verifyOTP(
    String phoneNumber,
    String otpCode,
  ) async {
    try {
      // Clean phone number and OTP
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
      final cleanOtpCode = otpCode.replaceAll(RegExp(r'[^\d]'), '');

      if (cleanOtpCode.length != 6) {
        return {
          'success': false,
          'message': 'Please enter a valid 6-digit OTP',
        };
      }

      // Check local storage first
      if (_otpStorage.containsKey(cleanPhoneNumber)) {
        final storedData = _otpStorage[cleanPhoneNumber]!;
        final storedOtp = storedData['otp'];
        final timestamp = storedData['timestamp'];
        final attempts = storedData['attempts'];

        // Check if OTP is expired (5 minutes)
        if (DateTime.now().millisecondsSinceEpoch - timestamp > 5 * 60 * 1000) {
          _otpStorage.remove(cleanPhoneNumber);
          return {
            'success': false,
            'message': 'OTP has expired. Please request a new one.',
          };
        }

        // Check attempts
        if (attempts >= 3) {
          _otpStorage.remove(cleanPhoneNumber);
          return {
            'success': false,
            'message': 'Too many failed attempts. Please request a new OTP.',
          };
        }

        // Verify OTP
        if (storedOtp == cleanOtpCode) {
          _otpStorage.remove(cleanPhoneNumber);

          // Mark as verified in Supabase if possible
          try {
            await _supabase
                .from('otp_verifications')
                .update({'verified': true})
                .eq('phone_number', cleanPhoneNumber)
                .eq('otp_code', cleanOtpCode);
          } catch (e) {
            print('Supabase update failed: $e');
          }

          return {
            'success': true,
            'message': 'OTP verified successfully',
            'phone_number': cleanPhoneNumber,
          };
        } else {
          // Increment attempts
          _otpStorage[cleanPhoneNumber]!['attempts'] = attempts + 1;
          return {
            'success': false,
            'message': 'Invalid OTP. Please try again.',
          };
        }
      }

      // Fallback: Check Supabase database
      try {
        final response = await _supabase
            .from('otp_verifications')
            .select()
            .eq('phone_number', cleanPhoneNumber)
            .eq('otp_code', cleanOtpCode)
            .eq('verified', false)
            .gte('expires_at', DateTime.now().toIso8601String())
            .maybeSingle();

        if (response != null) {
          await _supabase
              .from('otp_verifications')
              .update({'verified': true})
              .eq('id', response['id']);

          return {
            'success': true,
            'message': 'OTP verified successfully',
            'phone_number': cleanPhoneNumber,
          };
        }
      } catch (e) {
        print('Supabase verification failed: $e');
      }

      return {'success': false, 'message': 'Invalid or expired OTP'};
    } catch (e) {
      print('Error verifying OTP: $e');
      return {
        'success': false,
        'message': 'Verification failed. Please try again.',
      };
    }
  }

  /// Resend OTP
  Future<Map<String, dynamic>> resendOTP(String phoneNumber) async {
    final result = await sendOTP(phoneNumber);
    if (result['success']) {
      result['message'] =
          'OTP resent successfully to ${result['phone_number']}';
    }
    return result;
  }

  /// Check if phone number exists in sellers table
  Future<Map<String, dynamic>> checkSellerExists(String phoneNumber) async {
    try {
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      final response = await _supabase
          .from('sellers')
          .select('id, seller_name, contact_phone, approval_status')
          .eq('contact_phone', cleanPhoneNumber)
          .maybeSingle();

      if (response != null) {
        return {'exists': true, 'seller': response};
      } else {
        return {'exists': false};
      }
    } catch (e) {
      print('Error checking seller: $e');
      return {'exists': false, 'error': 'Failed to check seller status'};
    }
  }

  /// Register new seller after OTP verification
  Future<Map<String, dynamic>> registerSeller({
    required String phoneNumber,
    required Map<String, dynamic> sellerData,
  }) async {
    try {
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Add phone number to seller data
      sellerData['contact_phone'] = cleanPhoneNumber;
      sellerData['approval_status'] = 'pending';
      sellerData['created_at'] = DateTime.now().toIso8601String();
      sellerData['updated_at'] = DateTime.now().toIso8601String();

      // Create seller in database first
      final response = await _supabase
          .from('sellers')
          .insert(sellerData)
          .select()
          .single();

      // Authentication handled via API keys in edge functions
      print(
        '🔐 Seller registered - using API key authentication for edge functions',
      );

      return {
        'success': true,
        'message': 'Registration successful! Your account is pending approval.',
        'seller': response,
      };
    } catch (e) {
      print('Error registering seller: $e');
      return {
        'success': false,
        'message': 'Registration failed. Please try again.',
      };
    }
  }

  /// Login existing seller after OTP verification
  Future<Map<String, dynamic>> loginSeller(String phoneNumber) async {
    try {
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Get seller from database
      final response = await _supabase
          .from('sellers')
          .select()
          .eq('contact_phone', cleanPhoneNumber)
          .single();

      // Authentication handled via API keys in edge functions
      print(
        '🔐 Seller logged in - using API key authentication for edge functions',
      );

      return {
        'success': true,
        'message': 'Login successful!',
        'seller': response,
      };
    } catch (e) {
      print('Error logging in seller: $e');
      return {'success': false, 'message': 'Login failed. Please try again.'};
    }
  }
}
