import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'dart:convert'; // For base64Decode
import 'dart:typed_data'; // Import Uint8List
import 'package:findit/screans/found_item_details_screen.dart'; // Import the FoundItemDetailsScreen

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to mark a notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      // Handle error, maybe show a SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark notification as read: ${e.toString()}')),
      );
    }
  }

  // Function to handle tap on notification
  Future<void> _handleNotificationTap(
      BuildContext context,
      String notificationId,
      String notificationType,
      String relatedItemId,
      ) async {
    // Mark notification as read first
    if (!mounted) return; // Ensure widget is still in tree before async operations
    await _markAsRead(notificationId);

    // Navigate based on notification type
    if (notificationType == 'similar_item_found' && relatedItemId.isNotEmpty) {
      try {
        final foundItemDoc = await _firestore.collection('reports').doc(relatedItemId).get();
        if (foundItemDoc.exists) {
          final foundItemData = foundItemDoc.data() as Map<String, dynamic>;
          final String imageBase64 = foundItemData['imageBase64'] ?? '';
          final Uint8List? imageBytes = imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FoundItemDetailsScreen(
                  data: foundItemData,
                  imageBytes: imageBytes,
                  heroTag: 'foundItem_${relatedItemId}', // Unique hero tag
                  reportId: relatedItemId, // Pass the ID of the found item
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Found item details not available.')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading item details: ${e.toString()}')),
          );
        }
      }
    }
    // Add more conditions for other notification types if needed in the future
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5DEB3),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A4140),
          title: const Text('Notifications', style: TextStyle(color: Color(0xFFFFFFFF))),
          iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        ),
        body: const Center(
          child: Text(
            "Please login to view notifications.",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3),
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
            const Text('Notifications',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid) // Filter by current user's UID
            .orderBy('timestamp', descending: true) // Show latest notifications first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final notifications = snapshot.data!.docs;

          if (notifications.isEmpty) {
            return const Center(
              child: Text("No notifications for you.", style: TextStyle(color: Color(0xFF1A4140), fontSize: 18)),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notificationDoc = notifications[index];
              final notificationId = notificationDoc.id;
              final data = notificationDoc.data() as Map<String, dynamic>;

              final message = data['message'] ?? 'No message';
              final timestamp = data['timestamp'] != null
                  ? DateFormat.yMMMd().add_jm().format(data['timestamp'].toDate())
                  : 'No Time';
              final bool readStatus = data['read'] ?? false;
              final String relatedItemId = data['relatedItemId'] ?? ''; // Get related item ID
              final String notificationType = data['type'] ?? ''; // Get notification type

              return Card(
                color: readStatus ? const Color(0xFF1A4140) : const Color(0xFF1A4140), // Different color for unread
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: FutureBuilder<DocumentSnapshot>(
                  future: relatedItemId.isNotEmpty
                      ? _firestore.collection('reports').doc(relatedItemId).get()
                      : Future.value(null), // If no related item, return null future
                  builder: (context, itemSnapshot) {
                    String itemName = 'Item Details Loading...';
                    String reportType = '';
                    ImageProvider? itemImage;

                    if (itemSnapshot.connectionState == ConnectionState.waiting) {
                      // Still loading item details, show basic info
                    } else if (itemSnapshot.hasData && itemSnapshot.data!.exists) {
                      final itemData = itemSnapshot.data!.data() as Map<String, dynamic>;
                      itemName = itemData['itemName'] ?? 'Unnamed Item';
                      reportType = itemData['reportType'] ?? '';
                      final String imageBase64 = itemData['imageBase64'] ?? '';
                      if (imageBase64.isNotEmpty) {
                        itemImage = MemoryImage(base64Decode(imageBase64));
                      }
                    } else {
                      itemName = 'Item Not Found';
                    }

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: itemImage,
                        backgroundColor: Colors.grey, // Placeholder background
                        child: itemImage == null ? const Icon(Icons.image, color: Colors.white) : null,
                      ),
                      title: Text(
                        message,
                        style: TextStyle(
                          color: readStatus ? Color(0xFFFFF8E7) : Color(0xFFFFF8E7),
                          fontWeight: readStatus ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            itemName,
                            style: TextStyle(
                              color: readStatus ? Color(0xFFFFF8E7) : Color(0xFFFFF8E7),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            timestamp,
                            style: TextStyle(color: readStatus ? Color(0xFFFFF8E7) : Color(0xFFFFF8E7), fontSize: 12),
                          ),
                        ],
                      ),
                      trailing: readStatus
                          ? null // No trailing icon if already read
                          : IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Color(0xFFF5DEB3)),
                        onPressed: () => _markAsRead(notificationId),
                        tooltip: 'Mark as read',
                      ),
                      onTap: () => _handleNotificationTap(
                        context,
                        notificationId,
                        notificationType,
                        relatedItemId,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
