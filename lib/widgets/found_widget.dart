import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../screans/found_item_details_screen.dart'; // Make sure this path is correct

class FoundItemsTab extends StatelessWidget {
  final int crossAxisCount;
  final double aspectRatio;
  final String searchQuery;
  final Position? nearbyPosition;

  const FoundItemsTab({
    super.key,
    required this.crossAxisCount,
    required this.aspectRatio,
    required this.searchQuery,
    this.nearbyPosition,
  });

  @override
  Widget build(BuildContext context) {
    // MissingItemsTab se liye gaye responsive values
    double screenHeight = MediaQuery.of(context).size.height;
    double imageHeight = screenHeight * 0.18; // Responsive image height
    double paddingValue = screenHeight * 0.01;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.teal));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No items reported yet.'));
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final reportType = data['reportType'] ?? '';
          if (reportType != 'found') return false;

          final itemName = (data['itemName'] ?? '').toString().toLowerCase();
          final description =
          (data['description'] ?? '').toString().toLowerCase();
          final query = searchQuery.toLowerCase();

          final matchesSearch = itemName.contains(query) ||
              description.contains(query) ||
              query.isEmpty;

          if (!matchesSearch) return false;

          if (nearbyPosition != null &&
              data['latitude'] != null &&
              data['longitude'] != null) {
            final itemLat = data['latitude'];
            final itemLng = data['longitude'];
            final distance = Geolocator.distanceBetween(
                nearbyPosition!.latitude,
                nearbyPosition!.longitude,
                itemLat,
                itemLng);
            return distance <= 1000; // 10 km radius
          }

          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          return const Center(child: Text('No matching found items.'));
        }

        return Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            itemCount: filteredDocs.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: aspectRatio,
            ),
            itemBuilder: (context, index) {
              final data = filteredDocs[index].data() as Map<String, dynamic>;
              final itemName = data['itemName'] ?? 'Unnamed';
              final base64Image = data['imageBase64'] ?? '';
              final imageBytes = base64Image.isNotEmpty
                  ? base64Decode(base64Image)
                  : null;
              final reportedBy = data['reportedBy'] ?? 'Unknown'; // MissingItemsTab se copy kiya
              final reportId = filteredDocs[index].id;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => FoundItemDetailsScreen(
                            data: data,
                            imageBytes: imageBytes,
                            reportId: reportId,
                          )));
                },
                child: Card(
                  // CARD COLOR CHANGED TO MATCH MissingItemsTab
                  color: const Color(0xFF1A4140),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                  child: SingleChildScrollView( // Added SingleChildScrollView as in MissingItemsTab
                    physics: const NeverScrollableScrollPhysics(), // Added NeverScrollableScrollPhysics
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Changed to start
                      children: [
                        if (imageBytes != null) // Conditional image display
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10)), // Radius changed to 10
                            child: Image.memory(
                              imageBytes,
                              height: imageHeight, // Responsive height
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: imageHeight, // Responsive height
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0F7FA), // MissingItemsTab's No Image color
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'No Image Found', // Text for no image
                              style: TextStyle(
                                color: Colors.black, // Color for no image text
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.all(paddingValue), // Responsive padding
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF5DEB3), // Item Name color from MissingItemsTab
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reported by: $reportedBy', // Reported By text
                                style: const TextStyle(color: Colors.white70, fontSize: 12), // Reported By color from MissingItemsTab
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // Aap yahan aur details add kar sakte hain agar MissingItemsTab mein hain
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}