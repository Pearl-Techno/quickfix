import 'package:shared_preferences/shared_preferences.dart';

enum LicenseStatus {
  notActivated,
  trialActive,
  trialExpired,
  annualActive,
  annualExpired,
}

class LicenseStatusInfo {
  final LicenseStatus status;
  final String message;
  final int daysRemaining;
  final DateTime? expiresAt;

  LicenseStatusInfo({
    required this.status,
    required this.message,
    required this.daysRemaining,
    this.expiresAt,
  });

  bool get isValid =>
      status == LicenseStatus.trialActive || status == LicenseStatus.annualActive;
}

class LicenseResult {
  final bool success;
  final String message;
  final LicenseStatus? status;

  LicenseResult({
    required this.success,
    required this.message,
    this.status,
  });
}

class LicenseService {
  static const String trialKey = 'quantyx001';
  static const String annualKey = '110196';

  static const String _prefKey = 'license_active_key';
  static const String _prefActivatedAt = 'license_activated_at';
  static const String _prefExpiresAt = 'license_expires_at';
  static const String _prefTrialExpiresAt = 'license_trial_expires_at';

  Future<LicenseResult> activateKey(String key) async {
    final cleanKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    if (cleanKey == trialKey) {
      final currentKey = prefs.getString(_prefKey);
      if (currentKey == annualKey) {
        final expiresAtStr = prefs.getString(_prefExpiresAt);
        if (expiresAtStr != null) {
          final expiresAt = DateTime.tryParse(expiresAtStr);
          if (expiresAt != null && expiresAt.isAfter(now)) {
            return LicenseResult(
              success: false,
              message: 'An annual license is already active on this system.',
            );
          }
        }
      }

      final expiresAt = now.add(const Duration(days: 14));
      await prefs.setString(_prefKey, trialKey);
      await prefs.setString(_prefActivatedAt, now.toIso8601String());
      await prefs.setString(_prefExpiresAt, expiresAt.toIso8601String());
      await prefs.setString(_prefTrialExpiresAt, expiresAt.toIso8601String());

      return LicenseResult(
        success: true,
        message:
            '14-Day Trial activated successfully! Valid until ${_formatDate(expiresAt)}.',
        status: LicenseStatus.trialActive,
      );
    } else if (cleanKey == annualKey) {
      final trialExpiryStr = prefs.getString(_prefTrialExpiresAt);
      DateTime baseDate = now;
      if (trialExpiryStr != null) {
        final parsedTrialExpiry = DateTime.tryParse(trialExpiryStr);
        if (parsedTrialExpiry != null &&
            parsedTrialExpiry.isAfter(
              now.subtract(const Duration(days: 30)),
            )) {
          baseDate = parsedTrialExpiry;
        }
      }

      final expiresAt = baseDate.add(const Duration(days: 365));
      await prefs.setString(_prefKey, annualKey);
      await prefs.setString(_prefActivatedAt, now.toIso8601String());
      await prefs.setString(_prefExpiresAt, expiresAt.toIso8601String());

      return LicenseResult(
        success: true,
        message:
            '1-Year Annual License activated successfully! Valid until ${_formatDate(expiresAt)}.',
        status: LicenseStatus.annualActive,
      );
    } else {
      return LicenseResult(
        success: false,
        message:
            'Invalid activation key. Please enter a valid activation key.',
      );
    }
  }

  Future<LicenseStatusInfo> getLicenseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefKey);
    final expiresAtStr = prefs.getString(_prefExpiresAt);

    if (key == null || expiresAtStr == null) {
      return LicenseStatusInfo(
        status: LicenseStatus.notActivated,
        message: 'System activation required.',
        daysRemaining: 0,
      );
    }

    final expiresAt = DateTime.tryParse(expiresAtStr);
    if (expiresAt == null) {
      return LicenseStatusInfo(
        status: LicenseStatus.notActivated,
        message: 'Invalid license data stored.',
        daysRemaining: 0,
      );
    }

    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    final daysRemaining = difference.inDays;

    if (key == trialKey) {
      if (now.isAfter(expiresAt)) {
        return LicenseStatusInfo(
          status: LicenseStatus.trialExpired,
          message:
              '14-Day Trial period has expired. Please enter the annual activation key.',
          daysRemaining: 0,
          expiresAt: expiresAt,
        );
      } else {
        return LicenseStatusInfo(
          status: LicenseStatus.trialActive,
          message: '14-Day Trial Active ($daysRemaining days remaining).',
          daysRemaining: daysRemaining < 0 ? 0 : daysRemaining,
          expiresAt: expiresAt,
        );
      }
    } else if (key == annualKey) {
      if (now.isAfter(expiresAt)) {
        return LicenseStatusInfo(
          status: LicenseStatus.annualExpired,
          message:
              'Annual License has expired. Please enter a valid annual key.',
          daysRemaining: 0,
          expiresAt: expiresAt,
        );
      } else {
        return LicenseStatusInfo(
          status: LicenseStatus.annualActive,
          message: 'Annual License Active ($daysRemaining days remaining).',
          daysRemaining: daysRemaining < 0 ? 0 : daysRemaining,
          expiresAt: expiresAt,
        );
      }
    }

    return LicenseStatusInfo(
      status: LicenseStatus.notActivated,
      message: 'System activation required.',
      daysRemaining: 0,
    );
  }

  Future<bool> isLicenseValid() async {
    final info = await getLicenseStatus();
    return info.isValid;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
