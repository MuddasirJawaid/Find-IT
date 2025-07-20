import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'found_item_details_screen.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  Future<void> _markAsDeliveredToPolice(BuildContext context, String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFF5DEB3),
          title: const Text(
            "Confirm Delivery",
            style: TextStyle(color: Color(0xFF1A4140),),
          ),
          content: const Text(
            "Are you sure you have handed over this item to the police station?",
            style: TextStyle(color: Color(0xFF1A4140),),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF1A4140),)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF1A4140),),
              child: const Text("Confirm", style: TextStyle(color: Color(0xFFF5DEB3)),),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('reports')
            .doc(docId)
            .update({'status': 'at police station'});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Status updated to 'At Police Station'")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    }
  }

  // _markAsRecovered function has been removed as per your request.
  // Missing reports status will now only be changed by admin.

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login to view your reports")),
      );
    }
    final uid = user.uid;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4140),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF5DEB3), size: 28),
            const SizedBox(width: 8),
            const Text('My Reports',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF1A4140),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('uid', isEqualTo: uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A4140)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No reports yet.',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
            );
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final data = reports[index].data() as Map<String, dynamic>;
              final docId = reports[index].id;
              final imageTag = "reportImageTag_$docId";

              final status = (data['status'] ?? 'with founder').toString();
              final reportType = (data['reportType'] ?? '').toString(); // Get report type

              // Condition for showing "Mark as Delivered to Police" button
              final canMarkDelivered = reportType == 'found' && status == 'with founder';

              // Determine status text to display
              String displayStatusText;
              if (reportType == 'missing') {
                displayStatusText = "Status: Admin Controlled"; // Changed for missing reports
              } else {
                displayStatusText = "Status: $status";
              }

              return Card(
                color: const Color(0xFF1A4140),
                child: ListTile(
                  leading: (data['imageBase64'] != null &&
                      data['imageBase64'] != 'null' &&
                      (data['imageBase64'] as String).isNotEmpty)
                      ? Hero(
                    tag: imageTag,
                    child: CircleAvatar(
                      backgroundImage: MemoryImage(base64Decode(data['imageBase64'])),
                      radius: 24,
                    ),
                  )
                      : const Icon(Icons.assignment, color: Color(0xFFF5DEB3)),
                  title: Text(
                    data['itemName'] ?? 'Unnamed',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['reportType'] ?? '',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        displayStatusText, // Use the determined status text
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FoundItemDetailsScreen(
                          data: data,
                          imageBytes: (data['imageBase64'] != null &&
                              data['imageBase64'] != 'null' &&
                              (data['imageBase64'] as String).isNotEmpty)
                              ? base64Decode(data['imageBase64'])
                              : null,
                          heroTag: imageTag,
                          reportId: docId,
                        ),
                      ),
                    );
                  },
                  trailing: canMarkDelivered
                      ? IconButton(
                    icon: const Icon(Icons.local_police, color: Color(0xFFF5DEB3)),
                    tooltip: "Mark as Delivered to Police",
                    onPressed: () {
                      _markAsDeliveredToPolice(context, docId);
                    },
                  )
                      : null, // No button for missing items or other statuses
                ),
              );
            },
          );
        },
      ),
    );
  }
}
