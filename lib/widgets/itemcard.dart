import 'dart:typed_data';
import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String itemName;
  final String username;
  final String description;
  final String reportType;
  final Uint8List? imageBytes;

  const ItemCard({
    super.key,
    required this.itemName,
    required this.username,
    required this.description,
    required this.reportType,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCF2F1), Color(0xFFEFF8F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE
            Container(
              width: screenWidth * 0.25,
              height: screenWidth * 0.25,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                image: imageBytes != null
                    ? DecorationImage(
                  image: MemoryImage(imageBytes!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: imageBytes == null
                  ? const Icon(Icons.image, size: 40, color: Colors.grey)
                  : null,
            ),

            // TEXT DETAILS
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF037187),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "By: $username",
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: reportType == "Missing Item"
                            ? Colors.red[100]
                            : Colors.green[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Type: $reportType",
                        style: TextStyle(
                          fontSize: 12,
                          color: reportType == "Missing Item" ? Colors.red : Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
