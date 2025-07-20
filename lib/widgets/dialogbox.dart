import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../provider/auth_provider.dart';

void showForgotPasswordDialog(BuildContext context) {
  final TextEditingController emailController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(
        controller: emailController,
        decoration: const InputDecoration(hintText: 'Enter your email'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final email = emailController.text.trim();
            if (email.isEmpty || !email.contains('@')) {
              Fluttertoast.showToast(msg: "Enter a valid email");
              return;
            }

            try {
              await Provider.of<AuthProvider>(context, listen: false)
                  .sendPasswordResetEmail(email);
              Fluttertoast.showToast(msg: "Reset link sent to $email");
            } catch (e) {
              Fluttertoast.showToast(msg: "Error: ${e.toString()}");
            }

            Navigator.pop(context);
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
}
