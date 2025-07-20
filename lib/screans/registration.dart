import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../provider/auth_provider.dart';
import '../widgets/button.dart';
import '../widgets/logo.dart';

import '../widgets/textfield.dart';
import 'home.dart';
import 'login.dart';

class Registration extends StatefulWidget {
  const Registration({super.key});

  @override
  State<Registration> createState() => _RegistrationState();
}

class _RegistrationState extends State<Registration> {
  final _formKey = GlobalKey<FormState>();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final cityController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    cityController.dispose();
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
                  const AppLogo(sizeFactor: 0.25, alignTop: true),
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

                          /// First Name
                          CustomTextField(
                            controller: firstNameController,
                            label: 'First Name',
                            icon: Icons.person,
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Enter first name' : null,
                          ),
                          const SizedBox(height: 10),

                          /// Last Name
                          CustomTextField(
                            controller: lastNameController,
                            label: 'Last Name',
                            icon: Icons.person,
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Enter last name' : null,
                          ),
                          const SizedBox(height: 10),

                          /// Email
                          CustomTextField(
                            controller: emailController,
                            label: 'Email',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) => value == null || !value.contains('@')
                                ? 'Enter a valid email'
                                : null,
                          ),
                          const SizedBox(height: 10),

                          /// Phone Number
                          CustomTextField(
                            controller: phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: (value) =>
                            value == null || value.length < 10 ? 'Enter valid phone number' : null,
                          ),
                          const SizedBox(height: 10),

                          /// City
                          CustomTextField(
                            controller: cityController,
                            label: 'City',
                            icon: Icons.location_city,
                            validator: (value) =>
                            value == null || value.isEmpty ? 'Enter your city' : null,
                          ),
                          const SizedBox(height: 10),

                          /// Password
                          CustomTextField(
                            controller: passwordController,
                            label: 'Password',
                            icon: Icons.lock,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (value) => value == null || value.length < 6
                                ? 'Minimum 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 15),

                          /// Register Button
                          LoadingButton(
                            isLoading: authProvider.isLoading,
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await _handleRegister(context);
                              }
                            },
                            label: "Register", // ✅ shows "Register"
                            icon: Icons.app_registration, // ✅ shows register icon
                          ),

                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: const Text(
                      "Already have an account? Login",
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
        ),
      ),
    );
  }

  Future<void> _handleRegister(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final city = cityController.text.trim();
    final password = passwordController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: LoadingAnimationWidget.fourRotatingDots(
          color: Colors.orange,
          size: 50,
        ),
      ),
    );

    bool success = await authProvider.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      city: city,
    );

    Navigator.pop(context); // Close loader

    if (success) {
      Fluttertoast.showToast(msg: "Registration Successful");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } else {
      Fluttertoast.showToast(
        msg: authProvider.errorMessage ?? "Registration Failed",
      );
    }
  }
}
