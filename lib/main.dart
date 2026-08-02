import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'core/services/local_network_service.dart';
import 'core/services/log_service.dart';
import 'core/services/system_notification_service.dart';
import 'features/auth/models/user_model.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void _writeCrashLog(Object error, StackTrace? stack) {
  try {
    final now = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${Directory.systemTemp.path}\\Alshami_crash_$now.log');
    file.writeAsStringSync('$error\n$stack');
  } catch (_) {}
}

Future<void> main() async {
  FlutterError.onError = (details) {
    _writeCrashLog(details.exception, details.stack);
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    _writeCrashLog(error, stack);
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();

  await LogService().init();
  LogService.i('App started. Platform: ${Platform.operatingSystem}');
  LogService.i('App data path: ${await getApplicationDocumentsDirectory()}');

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

  User? user;
  if (isLoggedIn) {
    final userId = prefs.getString('user_uuid');
    final username = prefs.getString('username');
    if (userId != null && username != null) {
      user = User(id: userId, username: username);
    }
  }

  runApp(
    Provider<LocalNetworkService>.value(
      value: localNetworkService,
      child: const LocalSocialApp(),
    ),
  );

  if (user != null) {
    localNetworkService.start(user)
        .timeout(const Duration(seconds: 15))
        .catchError((e) => _writeCrashLog(e, null));
  }
}

class LocalSocialApp extends StatefulWidget {
  const LocalSocialApp({super.key});

  @override
  State<LocalSocialApp> createState() => _LocalSocialAppState();
}

class _LocalSocialAppState extends State<LocalSocialApp> with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocalNetworkService().darkModeNotifier.addListener(_onDarkModeChanged);
    _loadTheme();
  }

  @override
  void dispose() {
    LocalNetworkService().stop();
    WidgetsBinding.instance.removeObserver(this);
    LocalNetworkService().darkModeNotifier.removeListener(_onDarkModeChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      LocalNetworkService().stop();
    }
  }

  void _onDarkModeChanged() {
    if (mounted) {
      setState(() => _themeMode = LocalNetworkService().darkModeNotifier.value ? ThemeMode.dark : ThemeMode.light);
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    LocalNetworkService().darkModeNotifier.value = isDark;
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
