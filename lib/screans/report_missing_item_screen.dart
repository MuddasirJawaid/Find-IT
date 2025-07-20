import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  // Declare _isLoading variable and initialize it to false
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

    // Set _isLoading to true when starting the upload
    setState(() {
      _isLoading = true;
    });

    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final userProvider = Provider.of<myAuth.AuthProvider>(context, listen: false);
      final userEmail = userProvider.user?.email ?? "Unknown";
      final userUid = userProvider.user?.uid ?? "Unknown";
      String? base64Image;

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      await FirebaseFirestore.instance.collection('reports').add({
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing item reported successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      // Set _isLoading back to false after upload completes or an error occurs
      if (mounted) { // Check if the widget is still mounted before calling setState
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
            _isLoading // Use the declared _isLoading variable here
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