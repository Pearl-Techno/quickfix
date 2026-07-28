import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/services/license_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LicenseService Tests', () {
    late LicenseService licenseService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      licenseService = LicenseService();
    });

    test('Initial status when no key activated is notActivated', () async {
      final info = await licenseService.getLicenseStatus();
      expect(info.status, equals(LicenseStatus.notActivated));
      expect(info.isValid, isFalse);
    });

    test('Activating trial key quantyx001 grants 14-day trial', () async {
      final result = await licenseService.activateKey('quantyx001');
      expect(result.success, isTrue);
      expect(result.status, equals(LicenseStatus.trialActive));

      final info = await licenseService.getLicenseStatus();
      expect(info.status, equals(LicenseStatus.trialActive));
      expect(info.isValid, isTrue);
      expect(info.daysRemaining, greaterThanOrEqualTo(13));
    });

    test('Activating annual key 110196 grants annual license', () async {
      final result = await licenseService.activateKey('110196');
      expect(result.success, isTrue);
      expect(result.status, equals(LicenseStatus.annualActive));

      final info = await licenseService.getLicenseStatus();
      expect(info.status, equals(LicenseStatus.annualActive));
      expect(info.isValid, isTrue);
      expect(info.daysRemaining, greaterThanOrEqualTo(364));
    });

    test('Invalid key fails activation', () async {
      final result = await licenseService.activateKey('INVALID_KEY_123');
      expect(result.success, isFalse);
      expect(result.message, contains('Invalid activation key'));

      final info = await licenseService.getLicenseStatus();
      expect(info.status, equals(LicenseStatus.notActivated));
      expect(info.isValid, isFalse);
    });
  });
}
