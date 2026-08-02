import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/local_network_service.dart';
import '../../chat/screens/home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }


  Future<void> _navigate() async {
    if (!Platform.isWindows && !Platform.isLinux) {
      final status = await Permission.location.request();
      if (status.isGranted) {
        LocalNetworkService().triggerAnnouncementNow();
      }
    }

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isLoggedIn_v3') ?? false) {
      final userId = prefs.getString('user_uuid');
      final username = prefs.getString('username');

      if (userId != null && username != null) {
        await Future.wait([
          _waitForService(),
          Future.delayed(const Duration(seconds: 5)),
        ]);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  Future<void> _waitForService() async {
    while (mounted) {
      if (LocalNetworkService().isRunning) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF075E54),
      body: Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Iconsax.wifi, size: 80, color: Colors.white),
                SizedBox(height: 24),
                Text('تواصل محلي',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 30),
                CircularProgressIndicator(color: Colors.white)
              ])),
    );
  }
}
