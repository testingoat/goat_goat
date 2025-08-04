import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class OTPService {
  static final OTPService _instance = OTPService._internal();
  factory OTPService() => _instance;
  OTPService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Temporary storage for OTPs (in production, this should be in database)
  final Map<String, Map<String, dynamic>> _otpStorage = {};

  /// Generate a 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send OTP to phone number using Fast2SMS edge function
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

      // Generate OTP
      final otpCode = _generateOTP();

      // Call the Fast2SMS edge function
      final response = await _supabase.functions.invoke(
        'fast2sms-otp',
        body: {
          'phone_number': cleanPhoneNumber,
          'otp_code': otpCode,
          'action': 'send',
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'message': 'OTP sent successfully to $cleanPhoneNumber',
          'phone_number': cleanPhoneNumber,
        };
      } else {
        return {
          'success': false,
          'message': response.data?['message'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      print('Error sending OTP: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  /// Verify OTP code
  Future<Map<String, dynamic>> verifyOTP(
    String phoneNumber,
    String otpCode,
  ) async {
    try {
      // Clean phone number
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

      // Clean OTP code
      final cleanOtpCode = otpCode.replaceAll(RegExp(r'[^\d]'), '');

      if (cleanOtpCode.length != 6) {
        return {
          'success': false,
          'message': 'Please enter a valid 6-digit OTP',
        };
      }

      // Call the Fast2SMS edge function to verify
      final response = await _supabase.functions.invoke(
        'fast2sms-otp',
        body: {
          'phone_number': cleanPhoneNumber,
          'otp_code': cleanOtpCode,
          'action': 'verify',
        },
      );

      if (response.data != null && response.data['success'] == true) {
        return {
          'success': true,
          'message': 'OTP verified successfully',
          'phone_number': cleanPhoneNumber,
        };
      } else {
        return {
          'success': false,
          'message': response.data?['message'] ?? 'Invalid or expired OTP',
        };
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  /// Resend OTP (same as send OTP but with different message)
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

      final response = await _supabase
          .from('sellers')
          .insert(sellerData)
          .select()
          .single();

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

      final response = await _supabase
          .from('sellers')
          .select()
          .eq('contact_phone', cleanPhoneNumber)
          .single();

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
