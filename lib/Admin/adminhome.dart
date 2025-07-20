import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart' as myAuth;
import 'AdminSelectReportForStepperScreen.dart';
import 'admin_claims.dart';
import 'admin_found_reports.dart';
import 'admin_missing_reports.dart';
import 'admin_stepper.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  int userCount = 0;
  int reportCount = 0;
  final Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    fetchCounts();
  }

  Future<void> fetchCounts() async {
    try {
      final usersSnapshot =
      await FirebaseFirestore.instance.collection('users').get();
      final reportsSnapshot =
      await FirebaseFirestore.instance.collection('reports').get();

      setState(() {
        userCount = usersSnapshot.size;
        reportCount = reportsSnapshot.size;
      });
    } catch (e) {
      Fluttertoast.showToast(msg: "Error fetching counts: $e");
    }
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    final key = '$lat,$lng';
    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }

    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json');

    final response = await http.get(url, headers: {'User-Agent': 'FlutterApp'});

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final address = data['display_name'] ?? 'Address not found';
      _addressCache[key] = address;
      return address;
    } else {
      return 'Address not found';
    }
  }

  Widget _buildCountCard(String title, int count, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A38),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.travel_explore_rounded,
                color: Color(0xFFFF9800), size: 28),
            SizedBox(width: 8),
            Text(
              'Find-IT Admin Map',
              style: TextStyle(
                color: Color(0xFFFFF8E7),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E2A38),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1E2A38)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.admin_panel_settings,
                      color: Colors.orange, size: 50),
                  SizedBox(height: 10),
                  Text(
                    "Admin Panel",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.map, color: Colors.white),
              title: const Text('Live Map',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.assignment_turned_in, color: Colors.orange),
              title: const Text("Claims Handover", style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminSelectReportForStepperScreen(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.assignment_turned_in, color: Colors.orange),
              title: const Text("Claims Handover",
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAllClaimsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.white),
              title: const Text('Missing Reports',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminMissingReportsScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.publish, color: Colors.white),
              title: const Text('Found Reports',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AdminFoundReportsScreen())),
            ),
            const Divider(color: Colors.white70),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await Provider.of<myAuth.AuthProvider>(context, listen: false).logout();
                Fluttertoast.showToast(msg: "Logout successful");
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),

          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                _buildCountCard("Users", userCount, Colors.teal),
                _buildCountCard("Reports", reportCount, Colors.orange),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text("No reports found."));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final lat = data['latitude'] ?? 0.0;
                    final lng = data['longitude'] ?? 0.0;
                    final email = data['reportedBy'] ?? '';
                    final itemName = data['itemName'] ?? '';
                    final reportType = data['reportType'] ?? '';
                    final base64Image = data['imageBase64'] ?? '';
                    Uint8List? imageBytes;
                    if (base64Image != null && base64Image != 'null' && base64Image != '') {
                      imageBytes = base64Decode(base64Image);
                    }

                    return FutureBuilder<String>(
                      future: _getAddressFromLatLng(lat, lng),
                      builder: (context, addressSnapshot) {
                        final address =
                            addressSnapshot.data ?? 'Loading address...';
                        return Card(
                          margin: const EdgeInsets.all(10),
                          color: const Color(0xFF1E2A38),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
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
                                    child: Icon(Icons.image,
                                        color: Colors.white70, size: 50),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  itemName,
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  "Report Type: $reportType",
                                  style: const TextStyle(
                                      color: Colors.tealAccent, fontSize: 14),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  email,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  address,
                                  style:
                                  const TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 200,
                                  child: FlutterMap(
                                    options: MapOptions(
                                      initialCenter: LatLng(lat, lng),
                                      initialZoom: 15,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                        userAgentPackageName:
                                        'com.example.findit',
                                      ),
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: LatLng(lat, lng),
                                            width: 50,
                                            height: 50,
                                            child: const Icon(Icons.location_pin,
                                                size: 40, color: Colors.red),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
