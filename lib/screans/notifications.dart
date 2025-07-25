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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark notification as read: ${e.toString()}')),
        );
      }
    }
  }

  // Function to handle tap on notification
  Future<void> _handleNotificationTap(
      BuildContext context,
      String notificationId,
      String notificationType,
      String relatedItemId,
      ) async {
    if (!mounted) return;
    await _markAsRead(notificationId); // Mark as read immediately on tap

    // Handle navigation for both 'similar_item_found' and 'similar_found_item_match'
    if (notificationType == 'similar_item_found' || notificationType == 'similar_found_item_match') {
      if (relatedItemId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item details are missing for this notification.')),
          );
        }
        return;
      }
      try {
        final foundItemDoc = await _firestore.collection('reports').doc(relatedItemId).get();
        if (!foundItemDoc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Found item details not available or has been deleted.')),
            );
          }
          return;
        }

        final foundItemData = foundItemDoc.data() as Map<String, dynamic>;
        final String itemStatus = foundItemData['status'] ?? 'unknown';

        if (itemStatus == 'claimed by real owner') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This item has already been claimed by its real owner.')),
            );
          }
          return; // Do not navigate if item is already claimed
        }

        final String imageBase64 = foundItemData['imageBase64'] ?? '';
        final Uint8List? imageBytes = imageBase64.isNotEmpty ? base64Decode(imageBase64) : null;

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FoundItemDetailsScreen(
                data: foundItemData,
                imageBytes: imageBytes,
                heroTag: 'foundItem_${relatedItemId}',
                reportId: relatedItemId,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading item details: ${e.toString()}')),
          );
        }
      }
    } else if (notificationType == 'claim_approved_claimer') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your claim has been approved. Please check the item\'s status.')),
        );
      }
    } else if (notificationType == 'claim_approved_founder') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A claim for your item has been approved. The item is pending handover.')),
        );
      }
    }
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
            style: TextStyle(color: Color(0xFF1A4140), fontSize: 16),
            textAlign: TextAlign.center,
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF5DEB3), size: 28),
            SizedBox(width: 8),
            Text('Notifications',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A4140)));
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
              final data = notificationDoc.data() as Map<String, dynamic>? ?? {};

              final message = data['message'] ?? 'No message';
              final timestamp = data['timestamp'] != null
                  ? DateFormat.yMMMd().add_jm().format(data['timestamp'].toDate())
                  : 'No Time';
              final bool readStatus = data['read'] ?? false;
              final String relatedItemId = data['relatedItemId'] ?? '';
              final String notificationType = data['type'] ?? '';

              return Card(
                color: readStatus ? const Color(0xFF1A4140) : const Color(0xFF2E6360), // Changed unread color
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: FutureBuilder<DocumentSnapshot>(
                  future: relatedItemId.isNotEmpty
                      ? _firestore.collection('reports').doc(relatedItemId).get()
                      : Future.value(null),
                  builder: (context, itemSnapshot) {
                    String displayItemName = ''; // Start with empty, only show if relevant
                    ImageProvider? itemImage;
                    String itemStatus = 'unknown'; // Default status for display

                    // Text styles based on read status
                    TextStyle messageTextStyle = TextStyle(
                      color: readStatus ? const Color(0xFFFFF8E7).withOpacity(0.8) : const Color(0xFFFFF8E7),
                      fontWeight: readStatus ? FontWeight.normal : FontWeight.bold,
                    );
                    TextStyle subtitleTextStyle = TextStyle(
                      color: readStatus ? const Color(0xFFFFF8E7).withOpacity(0.7) : const Color(0xFFFFF8E7).withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: readStatus ? FontWeight.normal : FontWeight.bold,
                    );
                    TextStyle timestampTextStyle = TextStyle(
                      color: readStatus ? const Color(0xFFFFF8E7).withOpacity(0.6) : const Color(0xFFFFF8E7).withOpacity(0.8),
                      fontSize: 12,
                    );

                    // Handle different FutureBuilder states for item details
                    if (itemSnapshot.connectionState == ConnectionState.waiting) {
                      displayItemName = 'Loading item details...';
                    } else if (itemSnapshot.hasData && itemSnapshot.data!.exists) {
                      final itemData = itemSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                      displayItemName = itemData['itemName'] ?? 'Unnamed Item';
                      itemStatus = itemData['status'] ?? 'unknown'; // Update itemStatus from fetched data
                      final String imageBase64 = itemData['imageBase64'] ?? '';
                      if (imageBase64.isNotEmpty) {
                        itemImage = MemoryImage(base64Decode(imageBase64));
                      }
                    } else if (relatedItemId.isNotEmpty) { // Only set "Not Found" if an ID was provided
                      displayItemName = 'Item Details Not Found';
                    }
                    // If relatedItemId is empty, displayItemName remains empty, which is handled below

                    // Dynamic status indicator text and color
                    String statusIndicator = '';
                    Color statusAccentColor = subtitleTextStyle.color!; // Default to subtitle color

                    if (notificationType == 'similar_item_found' || notificationType == 'similar_found_item_match') {
                      if (itemStatus == 'claimed by real owner') {
                        statusIndicator = ' (Claimed by Owner)';
                        statusAccentColor = Colors.grey.shade400; // Grey for claimed
                        // Also make message text italic and slightly faded
                        messageTextStyle = messageTextStyle.copyWith(
                            fontStyle: FontStyle.italic,
                            color: readStatus ? const Color(0xFFFFF8E7).withOpacity(0.6) : const Color(0xFFFFF8E7).withOpacity(0.8)
                        );
                      } else if (itemStatus == 'at police station') {
                        statusIndicator = ' (At Police Station)';
                        statusAccentColor = Colors.orange.shade300; // Orange for police station
                      } else if (itemStatus == 'collected at police station') {
                        statusIndicator = ' (Collected from Police Station)';
                        statusAccentColor = Colors.blue.shade300; // Blue for collected
                      } else if (itemStatus == 'with founder') {
                        statusIndicator = ' (With Founder)';
                        statusAccentColor = Colors.green.shade300; // Green for with founder
                      }
                    } else if (notificationType == 'claim_approved_claimer') {
                      statusIndicator = ' (Claim Approved)';
                      statusAccentColor = Colors.green.shade300;
                    } else if (notificationType == 'claim_approved_founder') {
                      statusIndicator = ' (Claim Approved for Your Item)';
                      statusAccentColor = Colors.green.shade300;
                    }


                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: itemImage,
                        backgroundColor: const Color(0xFFF5DEB3), // Use your theme color
                        child: itemImage == null
                            ? Icon(Icons.image, color: readStatus ? Colors.grey.shade400 : const Color(0xFF1A4140))
                            : null,
                      ),
                      title: Text(
                        message,
                        style: messageTextStyle,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayItemName.isNotEmpty) // Only show item name if it's not empty
                            Text(
                              '$displayItemName$statusIndicator',
                              style: subtitleTextStyle.copyWith(color: statusAccentColor),
                            ),
                          Text(
                            timestamp,
                            style: timestampTextStyle,
                          ),
                        ],
                      ),
                      trailing: readStatus
                          ? null // No trailing icon if read
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