import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class MissingItemsTab extends StatelessWidget {
  final int crossAxisCount;
  final double aspectRatio;
  final String searchQuery;
  final Position? nearbyPosition;

  const MissingItemsTab({
    super.key,
    required this.crossAxisCount,
    required this.aspectRatio,
    this.searchQuery = '',
    this.nearbyPosition,
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
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final itemName = (data['itemName'] ?? '').toString().toLowerCase();
          final description = (data['description'] ?? '').toString().toLowerCase();

          if (searchQuery.isNotEmpty) {
            final query = searchQuery.toLowerCase();
            if (!itemName.contains(query) && !description.contains(query)) {
              return false;
            }
          }

          if (nearbyPosition != null) {
            final itemLat = data['latitude'];
            final itemLng = data['longitude'];
            if (itemLat != null && itemLng != null) {
              double distance = Geolocator.distanceBetween(
                nearbyPosition!.latitude,
                nearbyPosition!.longitude,
                itemLat,
                itemLng,
              );
              if (distance > 5000) {
                return false;
              }
            }
          }

          return true;
        }).toList();

        if (docs.isEmpty) {
          return const Center(child: Text('No nearby missing items found.'));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final base64Image = data['imageBase64'];
            final reportedBy = data['reportedBy'] ?? 'Unknown';
            ImageProvider? imageProvider;
            if (base64Image != null && base64Image.isNotEmpty) {
              imageProvider = MemoryImage(base64Decode(base64Image));
            }

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
