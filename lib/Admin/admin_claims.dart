import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAllClaimsScreen extends StatefulWidget {
  const AdminAllClaimsScreen({super.key});

  @override
  State<AdminAllClaimsScreen> createState() => _AdminAllClaimsScreenState();
}

class _AdminAllClaimsScreenState extends State<AdminAllClaimsScreen> {
  // Method to manually approve a claim
  Future<void> _approveClaim(String claimId) async {
    try {
      // 1. Get claim data to find claimerUid and itemId
      final claimDoc = await FirebaseFirestore.instance.collection('claims').doc(claimId).get();
      if (!claimDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim not found!')),
        );
        return;
      }
      final claimData = claimDoc.data()!;
      final String claimerUid = claimData['claimerUid'];
      final String claimerEmail = claimData['claimerEmail'] ?? 'Claimer'; // Claimer's email for founder's message
      final String itemId = claimData['itemId'];

      // 2. Get report data to find founderUid and itemName
      final reportDoc = await FirebaseFirestore.instance.collection('reports').doc(itemId).get();
      String founderUid = 'Unknown';
      String itemName = 'Unnamed Item';
      if (reportDoc.exists) {
        final reportData = reportDoc.data()!;
        founderUid = reportData['uid']; // Founder's UID is stored as 'uid' in reports
        itemName = reportData['itemName'] ?? 'Unnamed Item';
      }

      // 3. Update claim status
      await FirebaseFirestore.instance.collection('claims').doc(claimId).update({
        'status': 'approved',
        'manualVerifiedAt': FieldValue.serverTimestamp(),
      });

      // 4. Send notification to Claimer
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': claimerUid,
        'message': 'Your claim for "${itemName}" has been approved.',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'claim_approved_claimer',
        'relatedItemId': itemId,
        'relatedClaimId': claimId,
      });

      // 5. Send notification to Founder
      if (founderUid != 'Unknown') { // Ensure founderUid is valid
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': founderUid,
          'message': 'Claim for your report "${itemName}" by ${claimerEmail} has been approved.',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'claim_approved_founder',
          'relatedItemId': itemId,
          'relatedClaimId': claimId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim approved and notifications sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve claim: ${e.toString()}')),
      );
    }
  }

  // Method to manually reject a claim
  Future<void> _rejectClaim(String claimId) async {
    try {
      await FirebaseFirestore.instance.collection('claims').doc(claimId).update({
        'status': 'rejected',
        'manualVerifiedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Claim rejected!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject claim: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2A38),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Text('All Claims (Admin)', style: TextStyle(color: Colors.orange)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('claims')
            .orderBy('timestamp', descending: true) // Order by timestamp to see recent claims first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.orange));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final claims = snapshot.data!.docs;

          if (claims.isEmpty) {
            return const Center(
              child: Text("No claims yet.", style: TextStyle(color: Colors.white70, fontSize: 18)),
            );
          }

          return ListView.builder(
            itemCount: claims.length,
            itemBuilder: (context, index) {
              final claimDoc = claims[index];
              final claimId = claimDoc.id; // Get the document ID for updating
              final claimData = claimDoc.data() as Map<String, dynamic>;
              final itemId = claimData['itemId'] ?? '';
              final claimerEmail = claimData['claimerEmail'] ?? 'N/A';
              final claimerAnswer = claimData['claimerAnswer'] ?? 'N/A';
              final claimStatus = claimData['status'] ?? 'pending';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('reports').doc(itemId).get(),
                builder: (context, reportSnapshot) {
                  String itemName = 'Loading...';
                  String imageBase64 = '';
                  String reportClaimAnswer = ''; // To show report's claimAnswer

                  if (reportSnapshot.connectionState == ConnectionState.waiting) {
                    // Show a basic card with loading text while report data fetches
                    return Card(
                      color: const Color(0xFF2E3B4E),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircularProgressIndicator(color: Colors.orange, strokeWidth: 2),
                        title: const Text('Loading item details...', style: TextStyle(color: Colors.white)),
                        subtitle: Text(
                          "Claimer: $claimerEmail\nAnswer: $claimerAnswer\nStatus: $claimStatus",
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  if (reportSnapshot.hasData && reportSnapshot.data!.exists) {
                    final reportData = reportSnapshot.data!.data() as Map<String, dynamic>;
                    itemName = reportData['itemName'] ?? 'Unnamed Item';
                    imageBase64 = reportData['imageBase64'] ?? '';
                    reportClaimAnswer = (reportData['claimAnswer'] ?? 'N/A').toString().trim().toLowerCase();
                  } else {
                    itemName = 'Item Not Found';
                  }

                  final imageBytes = (imageBase64.isNotEmpty) ? base64Decode(imageBase64) : null;

                  return Card(
                    color: const Color(0xFF2E3B4E),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: imageBytes != null
                                ? CircleAvatar(backgroundImage: MemoryImage(imageBytes), radius: 25)
                                : const Icon(Icons.assignment, color: Colors.orange, size: 30),
                            title: Text(itemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Claimer: $claimerEmail", style: const TextStyle(color: Colors.white70)),
                                Text("Claimer's Answer: $claimerAnswer", style: const TextStyle(color: Colors.white70)),
                                Text("Report's Answer: $reportClaimAnswer", style: const TextStyle(color: Colors.white70)),
                                Text(
                                  "Status: ${claimStatus.toUpperCase()}",
                                  style: TextStyle(
                                    color: claimStatus == 'approved'
                                        ? Colors.green
                                        : claimStatus == 'rejected'
                                        ? Colors.red
                                        : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Show Approve/Reject buttons only if status is 'pending'
                          if (claimStatus == 'pending')
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _approveClaim(claimId),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _rejectClaim(claimId),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Reject'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          );
        },
      ),
    );
  }
}
