import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart' as myAuth;

class ReportFoundItemScreen extends StatefulWidget {
  const ReportFoundItemScreen({super.key});

  @override
  State<ReportFoundItemScreen> createState() => _ReportFoundItemScreenState();
}

class _ReportFoundItemScreenState extends State<ReportFoundItemScreen> {
  File? _imageFile;
  final itemNameController = TextEditingController();
  final colorController = TextEditingController();
  final locationDetailController = TextEditingController();
  final descriptionController = TextEditingController();
  final contactController = TextEditingController();
  final claimQuestionController = TextEditingController();
  final claimAnswerController = TextEditingController();

  final picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _uploadData() async {
    if (_imageFile == null ||
        itemNameController.text.isEmpty ||
        colorController.text.isEmpty ||
        locationDetailController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        contactController.text.isEmpty ||
        claimQuestionController.text.isEmpty ||
        claimAnswerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields, add claim question & answer, and capture an image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String address = placemarks.isNotEmpty
          ? "${placemarks[0].street}, ${placemarks[0].locality}, ${placemarks[0].country}"
          : "Unknown Location";

      final bytes = await _imageFile!.readAsBytes();
      String base64Image = base64Encode(bytes);

      final userProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
      final user = userProvider.user;
      final userEmail = user?.email ?? "Unknown";
      final userUid = user?.uid ?? "Unknown";

      // 1. Save the new "found item" report
      final newReportRef = await FirebaseFirestore.instance.collection('reports').add({
        'reportType': 'found',
        'itemName': itemNameController.text.trim(),
        'color': colorController.text.trim(),
        'locationDetails': locationDetailController.text.trim(),
        'description': descriptionController.text.trim(),
        'contact': contactController.text.trim(),
        'claimQuestion': claimQuestionController.text.trim(),
        'claimAnswer': claimAnswerController.text.trim(),
        'status': 'with founder',
        'reportedBy': userEmail,
        'uid': userUid,
        'imageBase64': base64Image,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final String newFoundReportId = newReportRef.id;
      final String newFoundItemName = itemNameController.text.trim();
      final String newFoundItemColor = colorController.text.trim();
      final double newFoundLat = position.latitude;
      final double newFoundLng = position.longitude;

      // 2. Check for similar missing items
      final missingReportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('reportType', isEqualTo: 'missing')
          .get();

      for (final missingReportDoc in missingReportsSnapshot.docs) {
        final missingReportData = missingReportDoc.data();
        final String missingItemName = missingReportData['itemName'] ?? '';
        final String missingItemColor = missingReportData['color'] ?? '';
        final double missingLat = missingReportData['latitude'] ?? 0.0;
        final double missingLng = missingReportData['longitude'] ?? 0.0;
        final String missingReporterUid = missingReportData['uid'] ?? '';

        // Convert to lowercase for case-insensitive comparison
        final String lowerMissingName = missingItemName.toLowerCase();
        final String lowerFoundName = newFoundItemName.toLowerCase(); // Use the newly found item's name
        final String lowerMissingColor = missingItemColor.toLowerCase();
        final String lowerFoundColor = newFoundItemColor.toLowerCase(); // Use the newly found item's color

        bool isSimilar = false;
        const double proximityThresholdMeters = 5000; // 5 kilometers
        const double closerProximityMeters = 2000; // 2 kilometers for average matches

        double distanceInMeters = Geolocator.distanceBetween(
          newFoundLat,
          newFoundLng,
          missingLat,
          missingLng,
        );

        // --- YAHAN TABDEELI HAI: Enhanced Similarity Logic for ReportFoundItemScreen ---

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

        // --- END Enhanced Similarity Logic ---

        if (isSimilar && missingReporterUid.isNotEmpty && missingReporterUid != userUid) {
          // Send notification to the user who reported the missing item
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': missingReporterUid,
            'message': 'A similar item to your missing report "${missingItemName}" has been found: "${newFoundItemName}" near you. You can claim it!',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'type': 'similar_item_found',
            'relatedItemId': newFoundReportId, // This is the ID of the FOUND item
            'relatedMissingReportId': missingReportDoc.id, // ID of the missing report it matched
          });
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Found item reported successfully and similar missing items checked!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reporting found item or checking for matches: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        backgroundColor: const Color(0xFF1A4140),
        title: Row(
          children: const [
            Icon(Icons.travel_explore_rounded, color: Color(0xFFF5DEB3), size: 28),
            SizedBox(width: 8),
            Text('Report Found Item',
                style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 22, fontWeight: FontWeight.bold)),
            Spacer(), // Added Spacer to match the style of ReportMissingItemScreen
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
              decoration: const InputDecoration(labelText: 'Item Name (e.g., Wallet, Keys, Phone)'),
            ),
            TextField(
              controller: colorController,
              decoration: const InputDecoration(labelText: 'Color (e.g., Black, Blue)'),
            ),
            TextField(
              controller: locationDetailController,
              decoration: const InputDecoration(labelText: 'Where did you find it? (Area/Details)'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description (e.g., scratches, bag brand)'),
              maxLines: 3,
            ),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(labelText: 'Your Contact Number'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: claimQuestionController,
              decoration: const InputDecoration(labelText: 'Claim Verification Question'),
            ),
            TextField(
              controller: claimAnswerController,
              decoration: const InputDecoration(labelText: 'Correct Answer (will not be shown to claimer)'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _pickImage,style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFFF8E7)),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture Photo'),
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