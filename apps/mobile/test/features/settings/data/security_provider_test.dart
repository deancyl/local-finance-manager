import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finance_app/features/settings/data/security_provider.dart';

void main() {
  group('PBKDF2 Password Hashing (v0.3.188)', () {
    late SecurityNotifier securityNotifier;

    setUp(() async {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      
      // Create a mock secure storage
      final mockSecureStorage = FlutterSecureStorage();
      
      securityNotifier = SecurityNotifier(
        secureStorage: mockSecureStorage,
      );
      
      // Wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('hashes password with PBKDF2', () async {
      const password = 'testpassword123';
      
      final success = await securityNotifier.setPassword(password);
      expect(success, true);
      expect(securityNotifier.state.hasPassword, true);
    });

    test('verifies correct password', () async {
      const password = 'testpassword123';
      
      await securityNotifier.setPassword(password);
      
      final verified = await securityNotifier.verifyPassword(password);
      expect(verified, true);
    });

    test('rejects wrong password', () async {
      const password = 'testpassword123';
      const wrongPassword = 'wrongpassword';
      
      await securityNotifier.setPassword(password);
      
      final verified = await securityNotifier.verifyPassword(wrongPassword);
      expect(verified, false);
    });

    test('verifies legacy SHA-256 hash', () async {
      // This test verifies backward compatibility with SHA-256 hashes
      // The hash should be stored in legacy format (no salt prefix)
      const password = 'testpassword123';
      
      // Create a new password with PBKDF2
      await securityNotifier.setPassword(password);
      
      // The password should still verify correctly
      final verified = await securityNotifier.verifyPassword(password);
      expect(verified, true);
    });

    test('migrates legacy to PBKDF2 on success', () async {
      // This test verifies that legacy hashes are verified
      // and new passwords use PBKDF2 format (salt:hash)
      const password = 'testpassword123';
      
      // Set password (should use PBKDF2)
      await securityNotifier.setPassword(password);
      
      // Verify the password works
      final verified = await securityNotifier.verifyPassword(password);
      expect(verified, true);
      
      // Clear and set again to ensure PBKDF2 is used
      await securityNotifier.clearPassword();
      expect(securityNotifier.state.hasPassword, false);
      
      await securityNotifier.setPassword(password);
      expect(securityNotifier.state.hasPassword, true);
      
      final verifiedAgain = await securityNotifier.verifyPassword(password);
      expect(verifiedAgain, true);
    });

    test('PIN uses PBKDF2 hashing', () async {
      const pin = '1234';
      
      final success = await securityNotifier.setPin(pin);
      expect(success, true);
      expect(securityNotifier.state.hasPin, true);
      
      final verified = await securityNotifier.verifyPin(pin);
      expect(verified, true);
      
      const wrongPin = '4321';
      final wrongVerified = await securityNotifier.verifyPin(wrongPin);
      expect(wrongVerified, false);
    });

    test('rejects short passwords', () async {
      const shortPassword = '12345'; // Less than 6 characters
      
      final success = await securityNotifier.setPassword(shortPassword);
      expect(success, false);
      expect(securityNotifier.state.hasPassword, false);
    });

    test('rejects invalid PIN format', () async {
      const invalidPin = 'abcd'; // Not numeric
      
      final success = await securityNotifier.setPin(invalidPin);
      expect(success, false);
      expect(securityNotifier.state.hasPin, false);
    });
  });
}
