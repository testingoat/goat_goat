import 'package:flutter_test/flutter_test.dart';
import 'package:goat_goat/services/auth_service.dart';
import 'package:goat_goat/services/supabase_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Mock classes for testing
class MockSupabaseService extends Mock implements SupabaseService {}

@GenerateMocks([MockSupabaseService])
void main() {
  group('AuthService Tests', () {
    late AuthService authService;
    late MockSupabaseService mockSupabaseService;

    setUp(() {
      mockSupabaseService = MockSupabaseService();
      authService = AuthService();
      // Inject mock service (you may need to modify AuthService to accept this)
    });

    tearDown(() {
      // Clean up after each test
    });

    group('Customer Authentication', () {
      test('should send OTP for valid phone number', () async {
        // Arrange
        final phoneNumber = '+1234567890';
        when(mockSupabaseService.sendOTP(any)).thenAnswer((_) async => true);

        // Act
        final result = await authService.sendOTP(phoneNumber);

        // Assert
        expect(result, true);
        verify(mockSupabaseService.sendOTP(phoneNumber)).called(1);
      });

      test('should fail OTP sending for invalid phone number', () async {
        // Arrange
        final invalidPhoneNumber = 'invalid';
        when(mockSupabaseService.sendOTP(any)).thenAnswer((_) async => false);

        // Act
        final result = await authService.sendOTP(invalidPhoneNumber);

        // Assert
        expect(result, false);
      });

      test('should login with valid OTP', () async {
        // Arrange
        final phoneNumber = '+1234567890';
        final otp = '123456';
        when(mockSupabaseService.verifyOTP(any, any))
            .thenAnswer((_) async => true);

        // Act
        final result = await authService.loginWithOTP(phoneNumber, otp);

        // Assert
        expect(result, true);
        verify(mockSupabaseService.verifyOTP(phoneNumber, otp)).called(1);
      });

      test('should fail login with invalid OTP', () async {
        // Arrange
        final phoneNumber = '+1234567890';
        final invalidOtp = '000000';
        when(mockSupabaseService.verifyOTP(any, any))
            .thenAnswer((_) async => false);

        // Act
        final result = await authService.loginWithOTP(phoneNumber, invalidOtp);

        // Assert
        expect(result, false);
      });
    });

    group('Session Management', () {
      test('should maintain user session after login', () async {
        // Arrange
        when(mockSupabaseService.getCurrentUser())
            .thenReturn({'id': 'user123', 'phone': '+1234567890'});

        // Act
        final user = authService.currentUser;

        // Assert
        expect(user, isNotNull);
        expect(user!['id'], 'user123');
      });

      test('should clear session on logout', () async {
        // Arrange
        when(mockSupabaseService.signOut()).thenAnswer((_) async => true);

        // Act
        await authService.signOut();
        final user = authService.currentUser;

        // Assert
        expect(user, isNull);
      });
    });
  });
}
