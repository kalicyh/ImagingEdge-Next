import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const List<Locale> _supportedLocales = [Locale('en'), Locale('ja'), Locale('zh')];
  
  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;
    
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettingsLinux = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    
    const initializationSettingsMacOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      linux: initializationSettingsLinux,
      macOS: initializationSettingsMacOS,
    );
    
    await _notifications.initialize(initializationSettings);
    _initialized = true;
  }

  static Locale _resolveLocale(String? localeCode) {
    if (localeCode != null && localeCode.isNotEmpty && localeCode != 'system') {
      final match = _supportedLocales.firstWhere(
        (locale) => locale.languageCode == localeCode,
        orElse: () => const Locale('en'),
      );
      return match;
    }

    final deviceLocale = PlatformDispatcher.instance.locale;
    final match = _supportedLocales.firstWhere(
      (locale) => locale.languageCode == deviceLocale.languageCode,
      orElse: () => const Locale('en'),
    );
    return match;
  }

  static Future<AppLocalizations> _loadLocalizations(String? localeCode) {
    final locale = _resolveLocale(localeCode);
    return AppLocalizations.delegate.load(locale);
  }
  
  /// Show transfer start notification
  static Future<void> showTransferStartNotification({String? localeCode}) async {
    final l10n = await _loadLocalizations(localeCode);
    await _showNotification(
      id: 1,
      title: l10n.notificationTransferTitle,
      body: l10n.notificationTransferStartBody,
      importance: Importance.defaultImportance,
      l10n: l10n,
    );
  }

  /// Show transfer end notification
  static Future<void> showTransferEndNotification({String? localeCode}) async {
    final l10n = await _loadLocalizations(localeCode);
    await _showNotification(
      id: 2,
      title: l10n.notificationTransferTitle,
      body: l10n.notificationTransferEndBody,
      importance: Importance.defaultImportance,
      l10n: l10n,
    );
  }

  /// Show download start notification
  static Future<void> showDownloadStartNotification(int fileCount, {String? localeCode}) async {
    final l10n = await _loadLocalizations(localeCode);
    await _showNotification(
      id: 3,
      title: l10n.notificationDownloadTitle,
      body: l10n.notificationDownloadStartBody(fileCount),
      importance: Importance.defaultImportance,
      l10n: l10n,
    );
  }

  /// Show download completed notification
  static Future<void> showDownloadCompletedNotification(int fileCount, String directory, {String? localeCode}) async {
    final l10n = await _loadLocalizations(localeCode);
    await _showNotification(
      id: 4,
      title: l10n.notificationDownloadCompleteTitle,
      body: l10n.notificationDownloadCompleteBody(fileCount, directory),
      importance: Importance.high,
      l10n: l10n,
    );
  }

  /// Show download error notification
  static Future<void> showDownloadErrorNotification(String error, {String? localeCode}) async {
    final l10n = await _loadLocalizations(localeCode);
    await _showNotification(
      id: 5,
      title: l10n.notificationDownloadErrorTitle,
      body: l10n.notificationDownloadErrorBody(error),
      importance: Importance.high,
      l10n: l10n,
    );
  }

  /// Show connection error notification
  static Future<void> showConnectionErrorNotification({String? localeCode}) async {
    final l10n = await _loadLocalizations(localeCode);
    await _showNotification(
      id: 6,
      title: l10n.notificationConnectionErrorTitle,
      body: l10n.notificationConnectionErrorBody,
      importance: Importance.high,
      l10n: l10n,
    );
  }
  
  /// Show progress notification (for ongoing downloads)
  static Future<void> showProgressNotification({
    required int currentFile,
    required int totalFiles,
    required String fileName,
    required double progress,
    String? localeCode,
  }) async {
    final l10n = await _loadLocalizations(localeCode);
    final androidDetails = AndroidNotificationDetails(
      'download_progress',
      l10n.notificationChannelProgress,
      channelDescription: l10n.notificationChannelProgressDescription,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: (progress * 100).round(),
      indeterminate: false,
      ongoing: true,
      autoCancel: false,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );
    
    const linuxDetails = LinuxNotificationDetails();
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );
    
    await _notifications.show(
      7, // Progress notification ID
      l10n.notificationProgressTitle(currentFile, totalFiles),
      fileName,
      details,
    );
  }
  
  /// Cancel progress notification
  static Future<void> cancelProgressNotification() async {
    await _notifications.cancel(7);
  }
  
  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
  
  /// Private method to show basic notification
  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    required AppLocalizations l10n,
    Importance importance = Importance.defaultImportance,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'imagingedge_main',
      l10n.notificationChannelMain,
      channelDescription: l10n.notificationChannelMainDescription,
      importance: importance,
      priority: _importanceToPriority(importance),
    );
    
    const iosDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );
    
    await _notifications.show(id, title, body, details);
  }
  
  /// Convert importance to priority for Android
  static Priority _importanceToPriority(Importance importance) {
    switch (importance) {
      case Importance.max:
        return Priority.max;
      case Importance.high:
        return Priority.high;
      case Importance.defaultImportance:
        return Priority.defaultPriority;
      case Importance.low:
        return Priority.low;
      case Importance.min:
        return Priority.min;
      default:
        return Priority.defaultPriority;
    }
  }
  
  /// Request notification permissions (mainly for iOS)
  static Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();
    
    final result = await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    
    return result ?? true; // Default to true for other platforms
  }
}
