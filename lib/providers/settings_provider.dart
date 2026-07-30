import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyDarkMode = 'dark_mode_enabled';
  static const String _keyOfflineMode = 'offline_mode_enabled';
  static const String _keyLanguage = 'language_code';
  static const String _keyAutoSync = 'auto_sync_enabled';
  static const String _keyCompressImages = 'compress_images';
  static const String _keyLastSync = 'last_sync_time';
  static const String _keyDataUsage = 'data_usage_saving';
  static const String _keyVatEnabled = 'vat_enabled';

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _offlineModeEnabled = true;
  bool _autoSyncEnabled = true;
  bool _compressImages = true;
  bool _dataSavingMode = false;
  bool _vatEnabled = false; // Disabled by default unless explicitly enabled in settings
  String _languageCode = 'en';
  DateTime? _lastSyncTime;

  SettingsProvider() {
    _loadSettings();
  }

  // ============= GETTERS =============
  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;
  bool get offlineModeEnabled => _offlineModeEnabled;
  bool get autoSyncEnabled => _autoSyncEnabled;
  bool get compressImages => _compressImages;
  bool get dataSavingMode => _dataSavingMode;
  bool get vatEnabled => _vatEnabled;
  String get languageCode => _languageCode;
  DateTime? get lastSyncTime => _lastSyncTime;

  // ============= SETTERS =============
  Future<void> setVatEnabled(bool value) async {
    if (_vatEnabled == value) return;
    _vatEnabled = value;
    await _saveSetting(_keyVatEnabled, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    if (_notificationsEnabled == value) return;
    _notificationsEnabled = value;
    await _saveSetting(_keyNotifications, value);
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool value) async {
    if (_darkModeEnabled == value) return;
    _darkModeEnabled = value;
    await _saveSetting(_keyDarkMode, value);
    notifyListeners();
  }

  Future<void> setOfflineModeEnabled(bool value) async {
    if (_offlineModeEnabled == value) return;
    _offlineModeEnabled = value;
    await _saveSetting(_keyOfflineMode, value);
    notifyListeners();
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    if (_autoSyncEnabled == value) return;
    _autoSyncEnabled = value;
    await _saveSetting(_keyAutoSync, value);
    notifyListeners();
  }

  Future<void> setCompressImages(bool value) async {
    if (_compressImages == value) return;
    _compressImages = value;
    await _saveSetting(_keyCompressImages, value);
    notifyListeners();
  }

  Future<void> setDataSavingMode(bool value) async {
    if (_dataSavingMode == value) return;
    _dataSavingMode = value;
    await _saveSetting(_keyDataUsage, value);
    notifyListeners();
  }

  Future<void> setLanguageCode(String value) async {
    if (_languageCode == value) return;
    _languageCode = value;
    await _saveSetting(_keyLanguage, value);
    notifyListeners();
  }

  Future<void> updateLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    await _saveSetting(_keyLastSync, _lastSyncTime!.toIso8601String());
    notifyListeners();
  }

  // ============= PERSISTENCE =============
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
      _darkModeEnabled = prefs.getBool(_keyDarkMode) ?? false;
      _offlineModeEnabled = prefs.getBool(_keyOfflineMode) ?? true;
      _autoSyncEnabled = prefs.getBool(_keyAutoSync) ?? true;
      _compressImages = prefs.getBool(_keyCompressImages) ?? true;
      _dataSavingMode = prefs.getBool(_keyDataUsage) ?? false;
      _vatEnabled = prefs.getBool(_keyVatEnabled) ?? false;
      _languageCode = prefs.getString(_keyLanguage) ?? 'en';

      final lastSyncStr = prefs.getString(_keyLastSync);
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading settings: $e');
      }
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving setting $key: $e');
      }
    }
  }

  // ============= BATCH OPERATIONS =============
  Future<void> resetSettings() async {
    await setNotificationsEnabled(true);
    await setDarkModeEnabled(false);
    await setOfflineModeEnabled(true);
    await setAutoSyncEnabled(true);
    await setCompressImages(true);
    await setDataSavingMode(false);
    await setLanguageCode('en');
    notifyListeners();
  }

  Future<void> applyRecommendedSettings() async {
    await setNotificationsEnabled(true);
    await setOfflineModeEnabled(true);
    await setAutoSyncEnabled(true);
    await setCompressImages(true);
    await setDataSavingMode(false);
    notifyListeners();
  }

  // ============= UTILITY METHODS =============
  bool shouldShowOnboarding() {
    // Check if user has seen onboarding before
    return true; // Implement logic as needed
  }

  void setOnboardingSeen() {
    // Mark onboarding as seen
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationsEnabled': _notificationsEnabled,
      'darkModeEnabled': _darkModeEnabled,
      'offlineModeEnabled': _offlineModeEnabled,
      'autoSyncEnabled': _autoSyncEnabled,
      'compressImages': _compressImages,
      'dataSavingMode': _dataSavingMode,
      'languageCode': _languageCode,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'SettingsProvider(${toMap()})';
  }
}
