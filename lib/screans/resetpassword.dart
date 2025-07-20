// widgets/resetpassword.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  Future<void> resetPassword() async {
    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );

      Fluttertoast.showToast(
        msg: 'Password reset link sent',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      emailController.clear();
    } on FirebaseAuthException catch (e) {
      String message = 'Something went wrong';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }

      Fluttertoast.showToast(
        msg: message,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: const Color(0xFFF5DEB3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4140),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color.fromARGB(255, 255, 248, 231)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            const Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF5DEB3), size: 28),
            SizedBox(width: 8),
            Text(
              'RESET PASSWORD',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your email to receive reset link:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  } else if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1A4140),
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      resetPassword();
                    }
                  },
                  child: isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Send Reset Link', style: TextStyle(color: Color(0xFFF5DEB3)),),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}