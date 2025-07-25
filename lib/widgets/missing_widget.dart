import 'dart:convert'; // For base64Decode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // For distance calculation

class MissingItemsTab extends StatelessWidget {
  final int crossAxisCount;
  final double aspectRatio;
  final String searchQuery;
  final Position? nearbyPosition;
  // --- ADDED: distanceFilterKm parameter ---
  final double distanceFilterKm;

  const MissingItemsTab({
    super.key,
    required this.crossAxisCount,
    required this.aspectRatio,
    this.searchQuery = '',
    this.nearbyPosition,
    // --- ADDED: distanceFilterKm to constructor ---
    this.distanceFilterKm = 1.0, // Default to 1 km
  });

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double imageHeight = screenHeight * 0.18; // Responsive image height
    double paddingValue = screenHeight * 0.01;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('reportType', isEqualTo: 'missing')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No missing items reported yet.'));
        }

        final filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final itemName = (data['itemName'] ?? '').toString().toLowerCase();
          final description = (data['description'] ?? '').toString().toLowerCase();

          // --- Search Query Filter ---
          final query = searchQuery.toLowerCase();
          final matchesSearch = itemName.contains(query) || description.contains(query) || query.isEmpty;
          if (!matchesSearch) return false;

          // --- Nearby Position Filter (if active) ---
          if (nearbyPosition != null && data['latitude'] != null && data['longitude'] != null) {
            final itemLat = data['latitude'] as double;
            final itemLng = data['longitude'] as double;

            // Calculate distance in meters
            final double distanceInMeters = Geolocator.distanceBetween(
              nearbyPosition!.latitude,
              nearbyPosition!.longitude,
              itemLat,
              itemLng,
            );

            // Filter for items within the specified distanceFilterKm (converted to meters)
            // Corrected: distance > 1000 for 1km, not 5000.
            return distanceInMeters <= (distanceFilterKm * 1000); // e.g., 1km = 1000 meters
          }

          return true; // If no nearby filter or no location data, and passed search, include.
        }).toList();

        if (filteredDocs.isEmpty) {
          String message = 'No available missing items matching your criteria.';
          if (nearbyPosition != null) {
            message = 'No missing items within ${distanceFilterKm}km radius matching your criteria.';
          } else if (searchQuery.isNotEmpty) {
            message = 'No missing items matching "${searchQuery}".';
          }
          return Center(child: Text(message, style: const TextStyle(color: Colors.black54, fontSize: 16)));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final base64Image = data['imageBase64'];
            final reportedBy = data['reportedBy'] ?? 'Unknown';
            ImageProvider? imageProvider;
            if (base64Image != null && base64Image.isNotEmpty) {
              imageProvider = MemoryImage(base64Decode(base64Image));
            }

            // You might want to add a GestureDetector here to navigate to a MissingItemDetailsScreen
            // similar to FoundItemDetailsScreen, if you have one.
            return Card(
              color: const Color(0xFF1A4140),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageProvider != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image(
                          image: imageProvider,
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
                          color: Color(0xFFFFF8E7),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                            data['itemName'] ?? 'Unnamed',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF5DEB3),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Reported by: $reportedBy',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Add other missing item specific details here if available, e.g., last seen date, contact info
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
  }
}