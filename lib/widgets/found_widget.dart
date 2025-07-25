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
  final Position? nearbyPosition; // User's current location (nullable)
  final double distanceFilterKm; // New parameter for 1km filter (default to 1.0)

  const FoundItemsTab({
    super.key,
    required this.crossAxisCount,
    required this.aspectRatio,
    required this.searchQuery,
    this.nearbyPosition,
    this.distanceFilterKm = 1.0, // Default to 1 km
  });

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double imageHeight = screenHeight * 0.18;
    double paddingValue = screenHeight * 0.01;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .orderBy('timestamp', descending: true)
          .where('status', isNotEqualTo: 'claimed by real owner')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.teal));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No items reported yet.'));
        }

        final allFoundItems = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final reportType = data['reportType'] ?? '';
          return reportType == 'found'; // Only include 'found' items
        }).toList();

        final filteredDocs = allFoundItems.where((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // --- Search Query Filter ---
          final itemName = (data['itemName'] ?? '').toString().toLowerCase();
          final description = (data['description'] ?? '').toString().toLowerCase();
          final query = searchQuery.toLowerCase();
          final matchesSearch = itemName.contains(query) || description.contains(query) || query.isEmpty;
          if (!matchesSearch) return false; // If it doesn't match search, exclude it

          // --- Nearby Position Filter (if active) ---
          if (nearbyPosition != null && data['latitude'] != null && data['longitude'] != null) {
            final itemLat = data['latitude'] as double;
            final itemLng = data['longitude'] as double;

            // Calculate distance in meters
            final double distanceInMeters = Geolocator.distanceBetween(
                nearbyPosition!.latitude,
                nearbyPosition!.longitude,
                itemLat,
                itemLng);

            // Filter for items within the specified distanceFilterKm (converted to meters)
            return distanceInMeters <= (distanceFilterKm * 1000); // 1 km = 1000 meters
          }

          // If nearbyPosition is null (filter not active), or no location data,
          // and it passed the search filter, include it.
          return true;
        }).toList();

        if (filteredDocs.isEmpty) {
          String message = 'No available found items matching your criteria.';
          if (nearbyPosition != null) {
            message = 'No found items within ${distanceFilterKm}km radius matching your criteria.';
          } else if (searchQuery.isNotEmpty) {
            message = 'No found items matching "${searchQuery}".';
          }
          return Center(child: Text(message, style: const TextStyle(color: Colors.black54, fontSize: 16)));
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
              final reportedBy = data['reportedBy'] ?? 'Unknown';
              final reportId = filteredDocs[index].id;
              final itemStatus = data['status'] ?? 'unknown';

              String statusDisplay = '';
              Color statusColor = Colors.white70;
              if (itemStatus == 'at police station') {
                statusDisplay = 'At Police Station';
                statusColor = Colors.orange.shade300;
              } else if (itemStatus == 'collected at police station') {
                statusDisplay = 'Collected at Police Station';
                statusColor = Colors.blue.shade300;
              } else if (itemStatus == 'with founder') {
                statusDisplay = 'With Founder';
                statusColor = Colors.green.shade300;
              } else if (itemStatus == 'awaiting collection') {
                statusDisplay = 'Awaiting Collection';
                statusColor = Colors.purple.shade300;
              }


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
                  color: const Color(0xFF1A4140),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (imageBytes != null)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10)),
                            child: Image.memory(
                              imageBytes,
                              height: imageHeight,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: imageHeight,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE0F7FA),
                              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'No Image Found',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.all(paddingValue),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF5DEB3),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reported by: $reportedBy',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (statusDisplay.isNotEmpty)
                                Text(
                                  'Status: $statusDisplay',
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
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