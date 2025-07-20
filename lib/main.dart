import 'package:findit/screans/home.dart';
import 'package:findit/screans/login.dart';
import 'package:findit/screans/splashscrean.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'provider/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Find-IT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF256D85)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F9FC),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/splash': (_) => const SplashScreen(),
        '/home': (_) => const Homescreen(),
      },
    );
  }
}
