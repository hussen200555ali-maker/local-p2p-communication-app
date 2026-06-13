import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/local_network_service.dart';
import '../../chat/screens/home_screen.dart'; // سيتم إنشاؤه لاحقاً
import '../models/user_model.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال اسم المستخدم')));
      return;
    }
    setState(() {
      _isLoading = true;
    });

    String? currentIp;
    int attempts = 0;
    while (currentIp == null && attempts < 5) {
      currentIp = await LocalNetworkService().getWifiIP();
      if (currentIp == null) await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }

    if (currentIp == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('فشل الاتصال بالشبكة. تأكد من اتصالك بالـ WiFi.'),
          backgroundColor: Colors.red));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = const Uuid().v4();
    final user = User(id: userId, username: _usernameController.text);

    await prefs.setBool('isLoggedIn_v3', true);
    await prefs.setString('username', user.username);
    await prefs.setString('user_uuid', user.id);

    await LocalNetworkService().start(user);

    if (mounted) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('تسجيل الدخول',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                  labelText: 'اسم المستخدم',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.user))),
          const SizedBox(height: 30),
          SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('دخول', style: TextStyle(fontSize: 18)),
              )),
        ]),
      ),
    );
  }
}
