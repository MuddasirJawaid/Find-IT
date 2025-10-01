import 'dart:typed_data';
import 'package:flutter/material.dart';

class MissingItemDetailsScreen extends StatelessWidget {
  final String itemName;
  final String reportedBy;
  final String contactNumber;
  final Uint8List? imageBytes;

  const MissingItemDetailsScreen({
    super.key,
    required this.itemName,
    required this.reportedBy,
    required this.contactNumber,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // === YAHAN PAR COLOR CHANGE KIYA GAYA HAI ===
      backgroundColor: const Color(0xFFF5DEB3),
      appBar: AppBar(
        title: const Text('Missing Item Details'),
        backgroundColor: const Color(0xFF1A4140),
        foregroundColor: const Color(0xFFF5DEB3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageBytes != null)
              // Aap is image ko card mein wrap kar sakte hain jaise homescreen par hai
                Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(imageBytes!),
                  ),
                ),
              const SizedBox(height: 16),
              // === YAHAN PAR COLOR CHANGE KIYA GAYA HAI ===
              Text(
                itemName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4140), // Homescreen jaisa primary color
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reported by:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4140), // Homescreen jaisa primary color
                ),
              ),
              // === YAHAN PAR COLOR CHANGE KIYA GAYA HAI ===
              Text(
                reportedBy,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87, // `black87` accha lag raha hai, isko rakh sakte hain
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Contact Number:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A4140), // Homescreen jaisa primary color
                ),
              ),
              // === YAHAN PAR COLOR CHANGE KIYA GAYA HAI ===
              Text(
                contactNumber,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87, // `black87` accha lag raha hai
                ),
              ),
              // Yahan aap aur bhi details add kar sakte hain
            ],
          ),
        ),
      ),
    );
  }
}