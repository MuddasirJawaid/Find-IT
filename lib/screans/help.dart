// widgets/helpPage.dart
import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          children: [
            const Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF5DEB3), size: 28),
            const SizedBox(width: 8),
            const Text(
              'HELP & SUPPORT',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

          ],
        ),
      ),
      backgroundColor: const Color(0xFFF5DEB3),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: const [
            Text(
              'FAQs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('Q: How to reset my password?\nA: Go to the drawer > Reset Password.'),
            SizedBox(height: 20),
            Text('Q: How to contact support?\nA: Email us at support@bookstore.com'),
            SizedBox(height: 30),
            Text(
              'Need More Help?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text('You can also reach out via the profile page or call us at +92-XXX-XXXXXXX'),
          ],
        ),
      ),
    );
  }
}
