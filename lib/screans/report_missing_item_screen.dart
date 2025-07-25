import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // Import for placemarkFromCoordinates if needed for missing item's address
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart' as myAuth;

class ReportMissingItemScreen extends StatefulWidget {
  const ReportMissingItemScreen({super.key});

  @override
  State<ReportMissingItemScreen> createState() => _ReportMissingItemScreenState();
}

class _ReportMissingItemScreenState extends State<ReportMissingItemScreen> {
  File? _imageFile;
  final itemNameController = TextEditingController();
  final categoryController = TextEditingController();
  final colorController = TextEditingController();
  final locationDetailController = TextEditingController();
  final descriptionController = TextEditingController();
  final contactController = TextEditingController();
  final picker = ImagePicker();

  bool _isLoading = false;

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
                if (picked != null) {
                  setState(() {
                    _imageFile = File(picked.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                if (picked != null) {
                  setState(() {
                    _imageFile = File(picked.path);
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadData() async {
    if (itemNameController.text.isEmpty ||
        categoryController.text.isEmpty ||
        colorController.text.isEmpty ||
        locationDetailController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        contactController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      // You can also get a reverse geocoded address for the missing item's location here if needed
      // List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      // String address = placemarks.isNotEmpty ? "${placemarks[0].street}, ${placemarks[0].locality}, ${placemarks[0].country}" : "Unknown Location";


      final userProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
      final userEmail = userProvider.user?.email ?? "Unknown";
      final userUid = userProvider.user?.uid ?? "Unknown";
      String? base64Image;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      // Save the new "missing item" report
      final newReportRef = await FirebaseFirestore.instance.collection('reports').add({
        'reportType': 'missing',
        'itemName': itemNameController.text.trim(),
        'category': categoryController.text.trim(),
        'color': colorController.text.trim(),
        'locationDetails': locationDetailController.text.trim(),
        'description': descriptionController.text.trim(),
        'contact': contactController.text.trim(),
        'reportedBy': userEmail,
        'uid': userUid,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'imageBase64': base64Image,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final String newMissingReportId = newReportRef.id;
      final String newMissingItemName = itemNameController.text.trim();
      final String newMissingItemColor = colorController.text.trim();
      final double newMissingLat = position.latitude;
      final double newMissingLng = position.longitude;

      // --- START: Check for similar FOUND items immediately ---
      final foundReportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportType', isEqualTo: 'found')
          .where('status', whereIn: ['with founder', 'at police station', 'collected at police station']) // Only consider available found items
          .get();

      for (final foundReportDoc in foundReportsSnapshot.docs) {
        final foundReportData = foundReportDoc.data();
        final String foundItemName = foundReportData['itemName'] ?? '';
        final String foundItemColor = foundReportData['color'] ?? '';
        final double foundLat = foundReportData['latitude'] ?? 0.0;
        final double foundLng = foundReportData['longitude'] ?? 0.0;
        // String foundReporterUid = foundReportData['uid'] ?? ''; // Not needed for notification to current user

        // Convert to lowercase for case-insensitive comparison
        final String lowerMissingName = newMissingItemName.toLowerCase();
        final String lowerFoundName = foundItemName.toLowerCase();
        final String lowerMissingColor = newMissingItemColor.toLowerCase();
        final String lowerFoundColor = foundItemColor.toLowerCase();

        bool isSimilar = false;
        const double proximityThresholdMeters = 5000; // 5 kilometers
        const double closerProximityMeters = 2000; // 2 kilometers for average matches

        double distanceInMeters = Geolocator.distanceBetween(
          newMissingLat,   // Newly missing item's lat
          newMissingLng,   // Newly missing item's lng
          foundLat,        // Existing found item's lat
          foundLng,        // Existing found item's lng
        );

        // Condition 1: Exact item name match AND within 5km proximity
        if (lowerMissingName == lowerFoundName && distanceInMeters <= proximityThresholdMeters) {
          isSimilar = true;
        }
        // Condition 2: Missing item name is a substring of found item name (or vice-versa)
        // AND Color matches AND within 5km proximity
        else if (
        (lowerFoundName.contains(lowerMissingName) || lowerMissingName.contains(lowerFoundName)) &&
            lowerMissingColor == lowerFoundColor &&
            distanceInMeters <= proximityThresholdMeters
        ) {
          isSimilar = true;
        }
        // Condition 3: Missing item name is a substring of found item name (or vice-versa)
        // AND Color DOES NOT match, but within a closer proximity (2km)
        else if (
        (lowerFoundName.contains(lowerMissingName) || lowerMissingName.contains(lowerFoundName)) &&
            lowerMissingColor != lowerFoundColor &&
            distanceInMeters <= closerProximityMeters
        ) {
          isSimilar = true;
        }

        if (isSimilar) {
          // Send notification to the user who just reported the missing item
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': userUid, // Notification for the current user (who just reported missing)
            'message': 'We found a similar item "${foundItemName}" to your missing report "${newMissingItemName}" near you. Check "Is This Yours?" section!',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'similar_found_item_match', // New type for this notification
            'relatedItemId': foundReportDoc.id, // This is the ID of the FOUND item
            'relatedMissingReportId': newMissingReportId, // ID of the missing report that was just created
          });
        }
      }
      // --- END: Check for similar FOUND items immediately ---


      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing item reported successfully! We checked for similar found items.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reporting missing item or checking for matches: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4140),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF5DEB3), size: 28),
            const SizedBox(width: 8),
            const Text('Report Missing Item',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF5DEB3),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: itemNameController,
              decoration: const InputDecoration(labelText: 'Item Name (e.g., Wallet, Phone)'),
            ),
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category (optional, e.g., Electronics)'),
            ),
            TextField(
              controller: colorController,
              decoration: const InputDecoration(labelText: 'Color'),
            ),
            TextField(
              controller: locationDetailController,
              decoration: const InputDecoration(labelText: 'Where did you lose it? (Area)'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(labelText: 'Your Contact Number'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _pickImage, style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFFF8E7)),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Add Image (optional)'),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              Image.file(_imageFile!, height: 200),
            ],
            const SizedBox(height: 20),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A4140)))
                : ElevatedButton(
              onPressed: _uploadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1A4140),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Submit', style: TextStyle(color: Color(0xFFF5DEB3)),),
            ),
          ],
        ),
      ),
    );
  }
}