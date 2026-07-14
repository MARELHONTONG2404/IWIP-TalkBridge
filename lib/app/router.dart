import 'package:go_router/go_router.dart';

import '../features/splash/presentation/splash_page.dart';
import '../features/welcome/presentation/welcome_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/conversation/presentation/pages/conversation_page.dart';
import '../features/history/presentation/pages/history_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/offline/presentation/offline_page.dart';
import '../features/favorite/presentation/pages/favorite_page.dart';
import '../features/camera/presentation/camera_translate_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',

  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomePage(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/translate',
      builder: (context, state) => const ConversationPage(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryPage(),
    ),
    GoRoute(
      path: '/favorite',
      builder: (context, state) => const FavoritePage(),
    ),
    GoRoute(
      path: '/offline',
      builder: (context, state) => const OfflinePage(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/camera',
      builder: (context, state) => const CameraTranslatePage(),
    ),
  ],
);