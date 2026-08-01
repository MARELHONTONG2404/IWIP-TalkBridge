import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/database/isar_provider.dart';
import 'core/database/isar_service.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/splash/presentation/splash_page.dart';

Future<void> bootstrap() async {
  debugPrint('--- AUDIT: bootstrap() called');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootstrapApp());
}

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late Future<List<dynamic>> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<List<dynamic>> _initialize() async {
    debugPrint('--- AUDIT: _initialize() called');
    final stopwatch = Stopwatch()..start();
    
    // Ambil SharedPreferences dan Application Directory secara konkuren
    final results = await Future.wait([
      SharedPreferences.getInstance(),
      getApplicationDocumentsDirectory(),
    ]);
    
    final prefs = results[0] as SharedPreferences;
    final dir = results[1] as dynamic; // Directory
    
    final isar = await IsarService.openWithDir(prefs, dir.path as String);

    stopwatch.stop();
    log('[Startup] ILB App initialized in ${stopwatch.elapsedMilliseconds}ms');

    // Beri waktu setidaknya 1500ms agar animasi Splash selesai sebelum ganti layar
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 1500) {
      await Future.delayed(Duration(milliseconds: 1500 - elapsed));
    }

    return [prefs, isar];
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('--- AUDIT: BootstrapApp build() called');
    return FutureBuilder<List<dynamic>>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: SplashPage(),
          );
        } else if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Error: ${snapshot.error}')),
            ),
          );
        }

        final prefs = snapshot.data![0] as SharedPreferences;
        final isar = snapshot.data![1] as dynamic;

        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isarProvider.overrideWithValue(isar),
          ],
          child: const ILBApp(),
        );
      },
    );
  }
}