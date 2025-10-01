import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class AdminFoundReportsScreen extends StatelessWidget {
  const AdminFoundReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A38),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: const Text(
          'Found Item Reports',
          style: TextStyle(
            color: Color(0xFFFFF8E7),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .where('reportType', isEqualTo: 'found') // ensure your Firestore uses 'found'
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No found item reports found.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final itemName = data['itemName'] ?? '';
              final color = data['color'] ?? '';
              final contact = data['contact'] ?? '';
              final description = data['description'] ?? '';
              final locationDetails = data['locationDetails'] ?? '';
              final reportedBy = data['reportedBy'] ?? '';
              final timestamp = data['timestamp'] != null
                  ? DateFormat.yMMMd().add_jm().format(data['timestamp'].toDate())
                  : 'No Time';
              final lat = data['latitude'] ?? 0.0;
              final lng = data['longitude'] ?? 0.0;
              final base64Image = data['imageBase64'] ?? '';
              Uint8List? imageBytes = base64Image.isNotEmpty && base64Image != 'null'
                  ? base64Decode(base64Image)
                  : null;

              return Card(
                margin: const EdgeInsets.all(10),
                color: const Color(0xFF1E2A38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      imageBytes != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          imageBytes,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                          : Container(
                        height: 180,
                        color: Colors.black26,
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.white70, size: 50),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(itemName,
                          style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("Color: $color", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      Text("Contact: $contact", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      Text("Description: $description", style: const TextStyle(color: Colors.white, fontSize: 14)),
                      Text("Location Details: $locationDetails", style: const TextStyle(color: Colors.white, fontSize: 14)),
                      Text("Reported By: $reportedBy", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      Text("Time: $timestamp", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat, lng),
                            initialZoom: 15,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.findit',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lat, lng),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                                ),
                              ],
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
