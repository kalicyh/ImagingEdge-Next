import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings configuration class
class AppSettings {
  final String cameraAddress;
  final int cameraPort;
  final String outputDirectory;
  final bool debugMode;
  final bool notificationsEnabled;
  final bool daemonMode;
  final String localeCode;

  const AppSettings({
    this.cameraAddress = '192.168.122.1',
    this.cameraPort = 64321,
    this.outputDirectory = '',
    this.debugMode = false,
    this.notificationsEnabled = true,
    this.daemonMode = false,
    this.localeCode = 'system',
  });

  AppSettings copyWith({
    String? cameraAddress,
    int? cameraPort,
    String? outputDirectory,
    bool? debugMode,
    bool? notificationsEnabled,
    bool? daemonMode,
    String? localeCode,
  }) {
    return AppSettings(
      cameraAddress: cameraAddress ?? this.cameraAddress,
      cameraPort: cameraPort ?? this.cameraPort,
      outputDirectory: outputDirectory ?? this.outputDirectory,
      debugMode: debugMode ?? this.debugMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      daemonMode: daemonMode ?? this.daemonMode,
      localeCode: localeCode ?? this.localeCode,
    );
  }

  @override
  String toString() {
    return 'AppSettings(cameraAddress: $cameraAddress, cameraPort: $cameraPort, outputDirectory: $outputDirectory, debugMode: $debugMode, notificationsEnabled: $notificationsEnabled, daemonMode: $daemonMode, localeCode: $localeCode)';
  }
}

/// Settings provider implementation
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const String _keyAddress = 'camera_address';
  static const String _keyPort = 'camera_port';
  static const String _keyOutputDir = 'output_directory';
  static const String _keyDebugMode = 'debug_mode';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyDaemonMode = 'daemon_mode';
  static const String _keyLocale = 'app_locale';

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      state = AppSettings(
        cameraAddress: prefs.getString(_keyAddress) ?? '192.168.122.1',
        cameraPort: prefs.getInt(_keyPort) ?? 64321,
        outputDirectory: prefs.getString(_keyOutputDir) ?? '',
        debugMode: prefs.getBool(_keyDebugMode) ?? false,
        notificationsEnabled: prefs.getBool(_keyNotifications) ?? true,
        daemonMode: prefs.getBool(_keyDaemonMode) ?? false,
        localeCode: prefs.getString(_keyLocale) ?? 'system',
      );
    } catch (e) {
      // Handle error, keep default settings
      print('Error loading settings: $e');
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_keyAddress, state.cameraAddress);
      await prefs.setInt(_keyPort, state.cameraPort);
      await prefs.setString(_keyOutputDir, state.outputDirectory);
      await prefs.setBool(_keyDebugMode, state.debugMode);
      await prefs.setBool(_keyNotifications, state.notificationsEnabled);
      await prefs.setBool(_keyDaemonMode, state.daemonMode);
      await prefs.setString(_keyLocale, state.localeCode);
    } catch (e) {
      print('Error saving settings: $e');
    }
  }

  /// Update camera address
  Future<void> setCameraAddress(String address) async {
    state = state.copyWith(cameraAddress: address);
    await _saveSettings();
  }

  /// Update camera port
  Future<void> setCameraPort(int port) async {
    state = state.copyWith(cameraPort: port);
    await _saveSettings();
  }

  /// Update output directory
  Future<void> setOutputDirectory(String directory) async {
    state = state.copyWith(outputDirectory: directory);
    await _saveSettings();
  }

  /// Toggle debug mode
  Future<void> setDebugMode(bool enabled) async {
    state = state.copyWith(debugMode: enabled);
    await _saveSettings();
  }

  /// Toggle notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    state = state.copyWith(notificationsEnabled: enabled);
    await _saveSettings();
  }

  /// Toggle daemon mode
  Future<void> setDaemonMode(bool enabled) async {
    state = state.copyWith(daemonMode: enabled);
    await _saveSettings();
  }

  /// Update language preference
  Future<void> setLocaleCode(String locale) async {
    state = state.copyWith(localeCode: locale);
    await _saveSettings();
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    state = const AppSettings();
    await _saveSettings();
  }
}

/// Settings provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
