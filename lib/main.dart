import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/screens.dart';
import 'services/services.dart';
import 'providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for desktop
  await windowManager.ensureInitialized();
  
  // Set window options
  const windowOptions = WindowOptions(
    size: Size(475, 800), // 默认窗口大小：宽475，高800
    minimumSize: Size(475, 600), // 最小窗口大小
    center: true, // 窗口居中显示
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'ImagingEdge Next',
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  // Initialize notification service
  try {
    await NotificationService.initialize();
    await NotificationService.requestPermissions();
  } catch (e) {
    print('Warning: Failed to initialize notifications: $e');
  }
  
  runApp(const ProviderScope(child: ImagingEdgeApp()));
}

class ImagingEdgeApp extends ConsumerWidget {
  const ImagingEdgeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    Locale? locale;
    if (settings.localeCode != null && settings.localeCode!.isNotEmpty && settings.localeCode != 'system') {
      locale = Locale(settings.localeCode!);
    }

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'ImagingEdge Next',
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
        if (settings.localeCode != null && settings.localeCode!.isNotEmpty && settings.localeCode != 'system') {
          return Locale(settings.localeCode!);
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
        '/settings': (context) => const SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
