import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart'; // Provider ko import karein
import '../provider/auth_provider.dart' as myAuth; // AuthProvider ka path
import '../screans/missing_item_details_screen.dart';

class MissingItemsTab extends StatelessWidget {
  final String searchQuery;
  final Position? nearbyPosition;
  final double distanceFilterKm;

  const MissingItemsTab({
    super.key,
    this.searchQuery = '',
    this.nearbyPosition,
    this.distanceFilterKm = 1.0,
  });

  // Naya function jo views count ko update karega
  Future<void> _incrementViewCount(String reportId, String? currentUserId) async {
    if (currentUserId == null) return; // Agar user logged-in nahi hai to return kar dein

    final reportRef = FirebaseFirestore.instance.collection('reports').doc(reportId);

    // Transaction use karein taake multiple updates ek hi time par handle ho sakein
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reportRef);

      if (!snapshot.exists) {
        throw Exception("Report does not exist!");
      }

      final data = snapshot.data() as Map<String, dynamic>;
      List<String> viewedByList = List<String>.from(data['viewedBy'] ?? []);

      // Check karein ke user ne pehle se hi report dekh li hai ya nahi
      if (!viewedByList.contains(currentUserId)) {
        // Agar nahi dekha, to views count aur list dono update karein
        int newViewsCount = (data['views'] ?? 0) + 1;
        viewedByList.add(currentUserId);

        transaction.update(reportRef, {
          'views': newViewsCount,
          'viewedBy': viewedByList,
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double imageHeight = screenHeight * 0.18;
    double paddingValue = screenHeight * 0.01;

    // AuthProvider se current user ki ID lein
    final currentUserId = Provider.of<myAuth.AuthProvider>(context, listen: false).user?.uid;

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
          final query = searchQuery.toLowerCase();
          final matchesSearch = itemName.contains(query) || description.contains(query) || query.isEmpty;
          if (!matchesSearch) return false;

          if (nearbyPosition != null && data['latitude'] != null && data['longitude'] != null) {
            final itemLat = data['latitude'] as double;
            final itemLng = data['longitude'] as double;
            final double distanceInMeters = Geolocator.distanceBetween(
              nearbyPosition!.latitude,
              nearbyPosition!.longitude,
              itemLat,
              itemLng,
            );
            return distanceInMeters <= (distanceFilterKm * 1000);
          }

          return true;
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

        return Padding(
          padding: const EdgeInsets.all(8),
          child: GridView.builder(
            itemCount: filteredDocs.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 240,
            ),
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final reportId = doc.id; // Report ID ko lein
              final base64Image = data['imageBase64'];
              final reportedBy = data['reportedBy'] ?? 'Unknown';
              final contactNumber = data['contact'] ?? 'Not provided';
              ImageProvider? imageProvider;
              Uint8List? imageBytes;
              if (base64Image != null && base64Image.isNotEmpty) {
                imageBytes = base64Decode(base64Image);
                imageProvider = MemoryImage(imageBytes);
              }

              final heroTag = 'missing-item-$reportId';

              return GestureDetector(
                onTap: () {
                  // Clicks ko track karne wala function call karein
                  _incrementViewCount(reportId, currentUserId);

                  // MissingItemDetailsScreen ko open karein
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MissingItemDetailsScreen(
                        itemName: data['itemName'] ?? 'Unnamed',
                        reportedBy: reportedBy,
                        contactNumber: contactNumber,
                        imageBytes: imageBytes,
                      ),
                    ),
                  );
                },
                child: Card(
                  color: const Color(0xFF1A4140),
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageProvider != null)
                        Hero(
                          tag: heroTag,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image(
                              image: imageProvider,
                              height: imageHeight,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
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
                            // Yahan par views count show kar sakte hain, agar aap chahein
                            // ya phir MyReportsScreen par dikhana behtar hai.
                            // Text('Views: ${data['views'] ?? 0}'),
                          ],
                        ),
                      ),
                    ],
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