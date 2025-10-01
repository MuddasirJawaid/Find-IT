import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // For distance calculation
import 'dart:convert'; // For base64Decode
import 'dart:typed_data'; // Import Uint8List
import 'package:findit/screans/found_item_details_screen.dart'; // Found Item Details Screen

class IsThisYoursScreen extends StatefulWidget {
  const IsThisYoursScreen({super.key});

  @override
  State<IsThisYoursScreen> createState() => _IsThisYoursScreenState();
}

class _IsThisYoursScreenState extends State<IsThisYoursScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
  }

  Future<List<Map<String, dynamic>>> _findSimilarFoundItems(
      String missingItemName,
      String missingItemColor,
      double missingLat,
      double missingLng,
      String missingReportId,
      ) async {
    List<Map<String, dynamic>> similarFoundItems = [];

    // Query for found items that are not yet "claimed by real owner"
    final foundReportsSnapshot = await _firestore
        .collection('reports')
        .where('reportType', isEqualTo: 'found')
        .where('status', whereIn: ['with founder', 'at police station', 'collected at police station'])
        .get();

    for (final foundReportDoc in foundReportsSnapshot.docs) {
      final foundReportData = foundReportDoc.data();
      final String foundItemName = foundReportData['itemName'] ?? '';
      final String foundItemColor = foundReportData['color'] ?? '';
      final double foundLat = foundReportData['latitude'] ?? 0.0;
      final double foundLng = foundReportData['longitude'] ?? 0.0;
      final String foundItemStatus = foundReportData['status'] ?? 'unknown';

      // Convert to lowercase for case-insensitive comparison
      final String lowerMissingName = missingItemName.toLowerCase();
      final String lowerFoundName = foundItemName.toLowerCase();
      final String lowerMissingColor = missingItemColor.toLowerCase();
      final String lowerFoundColor = foundItemColor.toLowerCase();

      bool isSimilar = false;
      const double proximityThresholdMeters = 5000; // 5 kilometers

      double distanceInMeters = Geolocator.distanceBetween(
        missingLat,
        missingLng,
        foundLat,
        foundLng,
      );

      // --- YAHAN TABDEELI HAI: Enhanced Similarity Logic ---

      // Condition 1: Exact item name match AND within proximity (strongest match based on name)
      if (lowerMissingName == lowerFoundName && distanceInMeters <= proximityThresholdMeters) {
        isSimilar = true;
      }
      // Condition 2: Missing item name is a substring of found item name (e.g., "mouse" in "black dell mouse")
      // OR Found item name is a substring of missing item name
      // AND Color matches AND within proximity
      else if (
      (lowerFoundName.contains(lowerMissingName) || lowerMissingName.contains(lowerFoundName)) &&
          lowerMissingColor == lowerFoundColor &&
          distanceInMeters <= proximityThresholdMeters
      ) {
        isSimilar = true;
      }
      // Condition 3: Missing item name is a substring of found item name (e.g., "mouse" in "black dell mouse")
      // OR Found item name is a substring of missing item name
      // AND NO color match, but within a closer proximity (e.g., 2km for a "weak" or "average" match)
      // This is for your "average type" if color doesn't match
      else if (
      (lowerFoundName.contains(lowerMissingName) || lowerMissingName.contains(lowerFoundName)) &&
          lowerMissingColor != lowerFoundColor && // Color doesn't match
          distanceInMeters <= 2000 // Closer proximity, e.g., 2km
      ) {
        isSimilar = true;
      }


      // --- END Enhanced Similarity Logic ---

      if (isSimilar) {
        similarFoundItems.add({
          'foundReportId': foundReportDoc.id,
          'data': foundReportData,
          'status': foundItemStatus,
        });
      }
    }
    return similarFoundItems;
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Is This Yours?', style: TextStyle(color: Color(0xFFFFFFFF))),
          backgroundColor: const Color(0xFF1A4140),
          iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        ),
        backgroundColor: const Color(0xFFF5DEB3),
        body: const Center(
          child: Text(
            "Please login to see potential matches for your lost items.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF1A4140), fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(

      backgroundColor: const Color(0xFFF5DEB3),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reports')
            .where('reportType', isEqualTo: 'missing')
            .where('uid', isEqualTo: _currentUser!.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, missingReportsSnapshot) {
          if (missingReportsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A4140)));
          }

          if (missingReportsSnapshot.hasError) {
            return Center(
              child: Text('Error loading your missing reports: ${missingReportsSnapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final missingReports = missingReportsSnapshot.data!.docs;

          if (missingReports.isEmpty) {
            return const Center(
              child: Text(
                "You haven't reported any missing items yet. Report one to see potential matches here!",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF1A4140), fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            itemCount: missingReports.length,
            itemBuilder: (context, index) {
              final missingReportDoc = missingReports[index];
              final missingReportData = missingReportDoc.data() as Map<String, dynamic>;
              final String missingItemName = missingReportData['itemName'] ?? 'N/A';
              final String missingItemColor = missingReportData['color'] ?? 'N/A';
              final double missingLat = missingReportData['latitude'] ?? 0.0;
              final double missingLng = missingReportData['longitude'] ?? 0.0;
              final String missingReportId = missingReportDoc.id;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: const Color(0xFF1A4140),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Missing Item: ${missingItemName} (${missingItemColor})',
                        style: const TextStyle(
                          color: Color(0xFFF5DEB3),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _findSimilarFoundItems(
                          missingItemName,
                          missingItemColor,
                          missingLat,
                          missingLng,
                          missingReportId,
                        ),
                        builder: (context, foundItemsFutureSnapshot) {
                          if (foundItemsFutureSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(color: Color(0xFFF5DEB3)),
                              ),
                            );
                          }

                          if (foundItemsFutureSnapshot.hasError) {
                            return Text('Error finding matches: ${foundItemsFutureSnapshot.error}',
                                style: const TextStyle(color: Colors.red));
                          }

                          final similarFoundItems = foundItemsFutureSnapshot.data ?? [];

                          if (similarFoundItems.isEmpty) {
                            return const Text(
                              'No similar items found yet for this report.',
                              style: TextStyle(color: Color(0xFFFFF8E7), fontSize: 14),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Potential Matches:',
                                style: TextStyle(
                                  color: Color(0xFFFFF8E7),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: similarFoundItems.length,
                                itemBuilder: (context, foundIndex) {
                                  final foundItemDataMap = similarFoundItems[foundIndex];
                                  final String foundReportId = foundItemDataMap['foundReportId'];
                                  final Map<String, dynamic> foundItemData = foundItemDataMap['data'];
                                  final String foundItemStatus = foundItemDataMap['status'] ?? 'unknown';

                                  final String foundItemName = foundItemData['itemName'] ?? 'Unnamed Found Item';
                                  final String foundItemColor = foundItemData['color'] ?? 'N/A';
                                  final String foundLocation = foundItemData['address'] ?? foundItemData['locationDetails'] ?? 'Unknown Location';
                                  final String imageBase64 = foundItemData['imageBase64'] ?? '';
                                  final Uint8List? imageBytes = imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

                                  String statusText;
                                  Color statusColor = const Color(0xFF1A4140);

                                  if (foundItemStatus == 'at police station') {
                                    statusText = 'At Police Station';
                                    statusColor = Colors.orange.shade800;
                                  } else if (foundItemStatus == 'collected at police station') {
                                    statusText = 'Collected at police station';
                                    statusColor = Colors.blue.shade800;
                                  } else { // 'with founder'
                                    statusText = 'With Founder';
                                    statusColor = Colors.green.shade800;
                                  }

                                  return Card(
                                    color: const Color(0xFFF5DEB3),
                                    margin: const EdgeInsets.symmetric(vertical: 6),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage: imageBytes != null ? MemoryImage(imageBytes) : null,
                                        backgroundColor: Colors.grey,
                                        child: imageBytes == null ? const Icon(Icons.image, color: Colors.white) : null,
                                      ),
                                      title: Text(
                                        'Found: $foundItemName ($foundItemColor)',
                                        style: const TextStyle(
                                            color: Color(0xFF1A4140), fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Found at: $foundLocation',
                                            style: const TextStyle(color: Color(0xFF1A4140)),
                                          ),
                                          Text(
                                            'Status: $statusText',
                                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FoundItemDetailsScreen(
                                              data: foundItemData,
                                              imageBytes: imageBytes,
                                              heroTag: 'foundItem_${foundReportId}',
                                              reportId: foundReportId,
                                            ),
                                          ),
                                        );
                                      },
                                      trailing: IconButton(
                                        icon: const Icon(Icons.info_outline, color: Color(0xFF1A4140)),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => FoundItemDetailsScreen(
                                                data: foundItemData,
                                                imageBytes: imageBytes,
                                                heroTag: 'foundItem_${foundReportId}',
                                                reportId: foundReportId,
                                              ),
                                            ),
                                          );
                                        },
                                        tooltip: 'View Details',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
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