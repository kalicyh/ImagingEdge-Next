import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/screens.dart';
import 'services/services.dart';
import 'providers/providers.dart';
import 'utils/utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for desktop platforms only.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    await windowManager.ensureInitialized();

    // Set window options
    const windowOptions = WindowOptions(
      size: Size(475, 800), // 默认窗口大小：宽475，高800
      minimumSize: Size(475, 600), // 最小窗口大小
      center: true, // 窗口居中显示
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'ImagingNext',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Initialize notification service
  try {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
  } catch (e, stack) {
    logWarning('Failed to initialize notifications', error: e, stackTrace: stack);
  }
  
  runApp(const ProviderScope(child: ImagingEdgeApp()));
}

class ImagingEdgeApp extends ConsumerWidget {
  const ImagingEdgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    final localeCode = settings.localeCode;
    final Locale? locale = localeCode != 'system' && localeCode.isNotEmpty
        ? Locale(localeCode)
        : null;

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'ImagingNext',
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ja'),
        Locale('zh'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeListResolutionCallback: (locales, supported) {
        final overrideCode = settings.localeCode;
        if (overrideCode.isNotEmpty && overrideCode != 'system') {
          return Locale(overrideCode);
        }
        if (locales != null) {
          for (final localeOption in locales) {
            if (supported.contains(Locale(localeOption.languageCode))) {
              return Locale(localeOption.languageCode);
            }
          }
        }
        return const Locale('en');
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const ConnectionScreen(),
        '/images': (context) => const ImagesScreen(),
        '/gallery': (context) => const GalleryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
