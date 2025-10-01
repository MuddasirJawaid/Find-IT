import 'dart:convert'; // For base64Decode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user UID
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyItemClaimsScreen extends StatefulWidget {
  final String foundItemId; // The ID of the found item report
  final String founderItemName; // To display the item name for context

  const MyItemClaimsScreen({
    super.key,
    required this.foundItemId,
    required this.founderItemName,
  });

  @override
  State<MyItemClaimsScreen> createState() => _MyItemClaimsScreenState();
}

class _MyItemClaimsScreenState extends State<MyItemClaimsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A4140),
          title: const Text('My Item Claims', style: TextStyle(color: Color(0xFFFFFFFF))),
          iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        ),
        body: const Center(
          child: Text(
            "Please login to view claims for your items.",
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3), // Consistent background color
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4140),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFFF5DEB3), size: 28),
            const SizedBox(width: 8),
            Expanded( // Use Expanded to handle long names
              child: Text(
                'Claims for "${widget.founderItemName}"',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 18, // Slightly smaller font for longer titles
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis, // Handle overflow
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query claims where 'itemId' matches the specific foundItemId
        stream: _firestore
            .collection('claims')
            .where('itemId', isEqualTo: widget.foundItemId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A4140)), // Your theme color
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading claims: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final claims = snapshot.data!.docs;

          if (claims.isEmpty) {
            return const Center(
              child: Text(
                "No claims have been made for this item yet.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF1A4140), fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final claimDoc = claims[index];
              final claimData = claimDoc.data() as Map<String, dynamic>;

              final claimerEmail = claimData['claimerEmail'] ?? 'N/A';
              final claimerAnswer = claimData['claimerAnswer'] ?? 'N/A';
              final claimStatus = claimData['status'] ?? 'pending';
              final Timestamp? timestamp = claimData['timestamp'] as Timestamp?;
              final String formattedTimestamp = timestamp != null
                  ? DateFormat('MMM d, yyyy - hh:mm a').format(timestamp.toDate())
                  : 'N/A';

              // Determine color for status
              Color statusColor;
              switch (claimStatus) {
                case 'approved':
                  statusColor = Colors.green.shade600;
                  break;
                case 'rejected':
                  statusColor = Colors.red.shade600;
                  break;
                default: // pending
                  statusColor = Colors.orange.shade600;
                  break;
              }

              return Card(
                color: Color(0xFF1A4140), // <<< Removed 'const' here
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(0xFFF5DEB3), // <<< Removed 'const' here
                          child: Icon(Icons.person, color: Color(0xFF1A4140)), // <<< Removed 'const' here
                        ),
                        title: Text(
                          "Claimer: $claimerEmail",
                          style: const TextStyle(color: Color(0xFFFFF8E7), fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Corrected Code:
                            Text(
                              "Answer: ${claimerAnswer.isEmpty ? 'No answer provided' : claimerAnswer}",
                              style: TextStyle(color: Color(0xFFFFF8E7).withOpacity(0.8), fontSize: 13), // <<< Removed 'const'
                            ),
                            Text(
                              "Claim Date: $formattedTimestamp",
                              style: TextStyle(color: Color(0xFFFFF8E7).withOpacity(0.7), fontSize: 12), // <<< Removed 'const'
                            ),
                            Text(
                              "Status: ${claimStatus.toUpperCase()}",
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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