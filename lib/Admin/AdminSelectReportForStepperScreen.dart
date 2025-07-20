import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_stepper.dart';

class AdminSelectReportForStepperScreen extends StatelessWidget {
  const AdminSelectReportForStepperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A38),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Text('Select Report for Handover Stepper',
            style: TextStyle(color: Colors.orange)),
        iconTheme: const IconThemeData(color: Colors.orange),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('status', whereIn: ['with founder', 'at police station'])
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No reports available for handover.',
                  style: TextStyle(color: Colors.white70, fontSize: 18)),
            );
          }

          final reports = snapshot.data!.docs;

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final data = reports[index].data() as Map<String, dynamic>;
              final docId = reports[index].id;
              final imageBase64 = data['imageBase64'] ?? '';
              final imageBytes =
              imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

              final itemName = data['itemName'] ?? 'Unnamed';
              final status = data['status'] ?? 'with founder';

              return Card(
                color: const Color(0xFF2E3B4E),
                child: ListTile(
                  leading: imageBytes != null
                      ? CircleAvatar(
                    backgroundImage: MemoryImage(imageBytes),
                    radius: 25,
                  )
                      : const Icon(Icons.assignment, color: Colors.orange),
                  title: Text(itemName,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text("Status: $status",
                      style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.orange, size: 18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminStepperScreen(reportId: docId),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
