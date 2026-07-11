import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'router.dart';
import 'theme.dart';
import '../features/settings/providers/settings_provider.dart';

class ILBApp extends ConsumerWidget {
  const ILBApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    Locale getLocale() {
      switch (settings.appLanguage) {
        case 'Indonesia': return const Locale('id', '');
        case '中文': return const Locale('zh', 'CN');
        default: return const Locale('en', '');
      }
    }
    
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'IWIP TalkBridge',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.darkMode ? ThemeMode.dark : ThemeMode.light,
      locale: getLocale(), // Apply language
      routerConfig: appRouter,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('id', ''),
        Locale('zh', 'CN'),
      ],
    );
  }
}
