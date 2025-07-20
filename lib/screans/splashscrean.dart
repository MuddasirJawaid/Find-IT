import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screans/home.dart';
import '../widgets/logo.dart';
import 'login.dart';
import 'on_boarding.dart';
import '../admin/adminhome.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), _checkAuth);
  }

  void _checkAuth() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // If user not logged in → onboarding
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else if (user.email == 'admin@gmail.com') {
      // If admin, go to admin map screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminMapScreen()),
      );
    } else {
      // If logged in user, go to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Homescreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5DEB3),
      body: Center(
        child: AppLogo(sizeFactor: 0.6),
      ),
    );
  }
}
