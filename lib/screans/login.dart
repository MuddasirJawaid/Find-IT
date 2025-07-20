import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../provider/auth_provider.dart';
import '../widgets/button.dart';
import '../widgets/dialogbox.dart';
import '../widgets/logo.dart';

import '../screans/home.dart';
import '../screans/registration.dart';
import '../Admin/adminhome.dart';
import '../widgets/textfield.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5DEB3), Color(0xFF1A4140)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            child: Center(
              child: Column(
                children: [
                  const AppLogo(sizeFactor: 0.3, alignTop: true),
                  const SizedBox(height: 20),
                  Container(
                    width: 350,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (authProvider.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                authProvider.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),

                          /// Email Field
                          CustomTextField(
                            controller: emailController,
                            label: 'Email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) =>
                            value == null || !value.contains('@')
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          /// Password Field
                          CustomTextField(
                            controller: passwordController,
                            label: 'Password',
                            icon: Icons.lock,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (value) => value == null || value.length < 6
                                ? 'Minimum 6 characters'
                                : null,
                          ),

                          /// Forgot Password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => showForgotPasswordDialog(context),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          /// Login Button or Loader
                          LoadingButton(
                            isLoading: authProvider.isLoading,
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await _handleLogin(context);
                              }
                            },
                            label: "Login",
                            icon: Icons.login,
                          ),

                          const SizedBox(height: 20),

                          /// Register Text
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const Registration()),
                              );
                            },
                            child: const Text(
                              "Don't have an account? Register",
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: LoadingAnimationWidget.fourRotatingDots(
          color: Color(0xFF1A4140),
          size: 50,
        ),
      ),
    );

    bool success = await authProvider.login(email, password);

    Navigator.pop(context); // close loader

    if (success) {
      Fluttertoast.showToast(msg: "Login Successful");

      if (email == 'admin@gmail.com' && password == '123123') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminMapScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Homescreen()),
        );
      }
    } else {
      Fluttertoast.showToast(
        msg: authProvider.errorMessage ?? "Login Failed",
      );
    }
  }
}
