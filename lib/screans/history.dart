import 'dart:convert'; // Import for base64Decode
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4140),
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: const Text(
          'Claimed Items History',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // This query is correct for fetching all items with the specific status
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('status', isEqualTo: 'claimed by real owner')
            .orderBy('handoverTimestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No claimed items in history yet.',
                style: TextStyle(color: Color(0xFF1A4140), fontSize: 16),
              ),
            );
          }

          final claimedItems = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: claimedItems.length,
            itemBuilder: (context, index) {
              var item = claimedItems[index];
              var itemData = item.data() as Map<String, dynamic>? ?? {};

              String itemId = item.id; // Get the ID of the reported item

              // Extract item data
              String itemName = itemData['itemName'] ?? 'Unknown Item';
              String itemDescription = itemData['description'] ?? 'No description provided';
              String itemLocation = itemData['address'] ?? 'Unknown Location';
              String itemColor = itemData['color'] ?? 'N/A';
              String itemType = itemData['reportType'] == 'missing' ? 'Missing Item' : 'Found Item'; // More dynamic type

              String imageBase64String = itemData['imageBase64'] ?? '';
              Uint8List? imageBytes;
              if (imageBase64String.isNotEmpty) {
                try {
                  imageBytes = base64Decode(imageBase64String);
                } catch (e) {
                  print('Error decoding base64 image: $e');
                  imageBytes = null;
                }
              }

              Timestamp? claimedDateTimestamp = itemData['handoverTimestamp'];
              String formattedClaimDate = claimedDateTimestamp != null
                  ? DateFormat('dd MMM yyyy, hh:mm a').format(claimedDateTimestamp.toDate())
                  : 'N/A';

              // FutureBuilder to get the claimer's email for this specific item
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('claims')
                    .where('itemId', isEqualTo: itemId)
                    .where('status', isEqualTo: 'approved')
                    .limit(1)
                    .get(),
                builder: (context, claimSnapshot) {
                  String claimerEmail = 'N/A (Claimer Not Found)';

                  if (claimSnapshot.connectionState == ConnectionState.done && claimSnapshot.hasData) {
                    if (claimSnapshot.data!.docs.isNotEmpty) {
                      claimerEmail = (claimSnapshot.data!.docs.first.data() as Map<String, dynamic>? ?? {})['claimerEmail'] ?? 'Email Not Found';
                    }
                  } else if (claimSnapshot.connectionState == ConnectionState.waiting) {
                    claimerEmail = 'Loading Claimer...';
                  }

                  return Card(
                    color: const Color(0xFFFFF8E7),
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: imageBytes != null
                                    ? Image.memory(
                                  imageBytes,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                                    : const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF1A4140),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Type: $itemType',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Claimed On: $formattedClaimDate',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1A4140),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Claimed By: $claimerEmail',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF1A4140),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, thickness: 1, color: Colors.grey),
                          Text(
                            itemDescription,
                            style: const TextStyle(fontSize: 14, color: Color(0xFF1A4140)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  itemLocation,
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.color_lens, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                itemColor,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
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