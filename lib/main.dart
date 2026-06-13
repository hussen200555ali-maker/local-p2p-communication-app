import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/local_network_service.dart';
import 'core/services/system_notification_service.dart';
import 'features/auth/models/user_model.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = SystemNotificationService();
  await notificationService.initialize();

  notificationService.onNotificationTap = (payload) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  };

  final localNetworkService = LocalNetworkService();

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn_v3') ?? false;

  if (isLoggedIn) {
    final userId = prefs.getString('user_uuid');
    final username = prefs.getString('username');
    if (userId != null && username != null) {
      final user = User(id: userId, username: username);
      await localNetworkService.start(user);
    }
  }

  runApp(
    Provider<LocalNetworkService>.value(
      value: localNetworkService,
      child: const LocalSocialApp(),
    ),
  );
}

class LocalSocialApp extends StatefulWidget {
  const LocalSocialApp({super.key});

  @override
  State<LocalSocialApp> createState() => _LocalSocialAppState();
}

class _LocalSocialAppState extends State<LocalSocialApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    if (mounted) {
      setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'تواصل محلي',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Cairo',
        brightness: Brightness.light,
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF075E54),
            foregroundColor: Colors.white),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Cairo',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1F1F1F),
            foregroundColor: Colors.white),
        cardColor: const Color(0xFF1E1E1E),
      ),
      themeMode: _themeMode,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
