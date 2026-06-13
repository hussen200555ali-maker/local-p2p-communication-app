import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await Permission.location.request();
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isLoggedIn_v3') ?? false) {
      // **الإصلاح**: نحتاج إلى إنشاء المستخدم وبدء الخدمة هنا
      final userId = prefs.getString('user_uuid');
      final username = prefs.getString('username');

      if (userId != null && username != null) {
        // الخدمة بدأت بالفعل من main.dart - لا داعي لتكرار البدء
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // إذا كانت البيانات غير كاملة، اذهب لتسجيل الدخول
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
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
