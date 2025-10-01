import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewersScreen extends StatelessWidget {
  final List<String> viewedByUids;

  const ViewersScreen({super.key, required this.viewedByUids});

  // UIDs se emails fetch karne ke liye function
  Future<List<String>> _fetchEmailsFromUids() async {
    if (viewedByUids.isEmpty) {
      return [];
    }

    final usersCollection = FirebaseFirestore.instance.collection('users');
    final List<String> emails = [];

    // Har UID ke liye user document fetch karein
    for (final uid in viewedByUids) {
      try {
        final doc = await usersCollection.doc(uid).get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final email = data['email'] ?? 'Email not found';
          emails.add(email);
        } else {
          emails.add('User not found');
        }
      } catch (e) {
        emails.add('Error fetching user');
      }
    }
    return emails;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3), // Home screen se matching color
      appBar:AppBar(
        backgroundColor: const Color(0xFF1A4140),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF5DEB3), size: 28),
            SizedBox(width: 8),
            Text('Viewrs',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: FutureBuilder<List<String>>(
        future: _fetchEmailsFromUids(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A4140)));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No one has viewed this report yet.',
                style: TextStyle(color: Color(0xFF1A4140), fontSize: 16),
              ),
            );
          }

          final emails = snapshot.data!;
          return ListView.builder(
            itemCount: emails.length,
            itemBuilder: (context, index) {
              final email = emails[index];
              return Card(
                color: const Color(0xFF1A4140),
                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFFF5DEB3)),
                  title: Text(
                    email,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}