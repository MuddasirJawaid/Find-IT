import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

// <<< Naya import: MyItemClaimsScreen ko import karein
import 'package:findit/screans/my_item_claims_screen.dart'; // Adjust path if different

class FoundItemDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final Uint8List? imageBytes;
  final String? heroTag;
  final String reportId; // The ID of the found item report

  const FoundItemDetailsScreen({
    super.key,
    required this.data,
    this.imageBytes,
    this.heroTag,
    required this.reportId,
  });

  @override
  State<FoundItemDetailsScreen> createState() => _FoundItemDetailsScreenState();
}

class _FoundItemDetailsScreenState extends State<FoundItemDetailsScreen> {
  String _geocodedAddress = "Loading address...";
  bool _hasClaimed = false; // <<< Naya state variable
  bool _isLoadingClaimStatus = true; // For loading indicator

  @override
  void initState() {
    super.initState();
    _resolveGeocodedAddress();
    _checkIfUserHasClaimed(); // <<< Naya function call kiya yahan
  }

  Future<void> _resolveGeocodedAddress() async {
    final lat = widget.data['latitude'];
    final lng = widget.data['longitude'];

    if (lat != null && lng != null) {
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          setState(() {
            _geocodedAddress =
            "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}";
            _geocodedAddress = _geocodedAddress.replaceAll(RegExp(r',?\s*null'), '').trim();
            if (_geocodedAddress.isEmpty) {
              _geocodedAddress = "Address not found for these coordinates";
            }
          });
        } else {
          setState(() {
            _geocodedAddress = "Address not found for these coordinates";
          });
        }
      } catch (e) {
        setState(() {
          _geocodedAddress = "Could not resolve address";
        });
      }
    } else {
      setState(() {
        _geocodedAddress = "Location not available";
      });
    }
  }

  // <<< Naya function: Check karta hai ki current user ne pehle claim kiya hai ya nahi
  Future<void> _checkIfUserHasClaimed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoadingClaimStatus = false;
      });
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('claims')
          .where('itemId', isEqualTo: widget.reportId)
          .where('claimerUid', isEqualTo: user.uid)
          .limit(1) // Ek bhi claim mil gaya toh kaafi hai
          .get();

      if (mounted) {
        setState(() {
          _hasClaimed = querySnapshot.docs.isNotEmpty;
          _isLoadingClaimStatus = false;
        });
      }
    } catch (e) {
      print("Error checking claim status: $e"); // Debugging
      if (mounted) {
        setState(() {
          _isLoadingClaimStatus = false;
        });
      }
    }
  }

  String formatLabel(String key) {
    return key.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) {
      return '${match.group(1)} ${match.group(2)}';
    }).replaceFirst(key[0], key[0].toUpperCase());
  }

  Future<void> _showClaimDialog(BuildContext context) async {
    final TextEditingController answerController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login kr ke dobara try kren")),
      );
      return;
    }

    final claimQuestion = widget.data['claimQuestion'] ?? 'No claim question set.';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A4140),
          title: const Text("Claim Item", style: TextStyle(color: Color(0xFFF5DEB3))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Claim Question:\n$claimQuestion",
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(
                  hintText: "Yahan jawab likhein",
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white70)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFF5DEB3))),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Color(0xFFF5DEB3))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (answerController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Jawab likhein claim k liye")),
                  );
                  return;
                }
                try {
                  await FirebaseFirestore.instance.collection('claims').add({
                    'itemId': widget.reportId,
                    'claimerUid': user.uid,
                    'claimerEmail': user.email ?? '',
                    'claimerAnswer': answerController.text.trim(),
                    'status': 'pending',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                  if (mounted) { // Check if the widget is still in the tree
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Claim request bhej di gayi hy"),
                        backgroundColor: Colors.green,
                      ),
                    );
                    // Update the state to reflect that the user has now claimed this item
                    setState(() {
                      _hasClaimed = true;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: ${e.toString()}")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF5DEB3)),
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> displayData = {};

    if (widget.data.containsKey('itemName')) displayData['Item Name'] = widget.data['itemName'];
    if (widget.data.containsKey('description')) displayData['Description'] = widget.data['description'];
    if (widget.data.containsKey('reportedBy')) displayData['Reported By'] = widget.data['reportedBy'];
    if (widget.data.containsKey('contact')) displayData['Contact'] = widget.data['contact'];
    if (widget.data.containsKey('color')) displayData['Color'] = widget.data['color'];
    if (widget.data.containsKey('reportType')) displayData['Report Type'] = widget.data['reportType'];
    if (widget.data.containsKey('status')) displayData['Status'] = widget.data['status'];

    // LOCATION DETAILS (MANUAL INPUT)
    if (widget.data.containsKey('locationDetails') && widget.data['locationDetails'] != null && widget.data['locationDetails'].isNotEmpty) {
      displayData['Location Details '] = widget.data['locationDetails'];
    } else if (widget.data.containsKey('address') && widget.data['address'] != null && widget.data['address'].isNotEmpty) {
      displayData['Location Details '] = widget.data['address'];
    }

    // ADDRESS FROM LAT/LNG (Label changed)
    displayData['Address'] = _geocodedAddress;

    // TIMESTAMP FIELD ADDED
    if (widget.data.containsKey('timestamp') && widget.data['timestamp'] is Timestamp) {
      Timestamp t = widget.data['timestamp'] as Timestamp;
      DateTime dateTime = t.toDate();
      displayData['Time stamp'] = DateFormat('MMM d, yyyy - hh:mm a').format(dateTime);
    }

    final status = widget.data['status'] ?? 'with founder';
    final user = FirebaseAuth.instance.currentUser;
    final String? founderUid = widget.data['uid'] as String?;
    final isFounder = user != null && founderUid != null && user.uid == founderUid;

    final canClaimStatuses = [
      'with founder',
      'at police station',
      'mark as collected', // Assuming these can still be claimed if not officially 'collected' by owner
      'collected at police station', // Assuming these can still be claimed if not officially 'collected' by owner
    ];

    // Combine conditions for showing the claim button/message
    // 1. Not the founder of the report
    // 2. Item is in a claimable status
    // 3. User has NOT already claimed it (checked by _hasClaimed)
    final showClaimButton = !isFounder && canClaimStatuses.contains(status) && !_hasClaimed;
    final showClaimedMessage = !isFounder && canClaimStatuses.contains(status) && _hasClaimed;


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
            Text('Item Details',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.imageBytes != null)
                    Hero(
                      tag: widget.heroTag ?? 'defaultHeroTag',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          widget.imageBytes!,
                          height: 250,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  ...displayData.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "${entry.key}: ${entry.value}",
                        style: const TextStyle(
                          color: Color(0xFF1A4140),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          // Conditional rendering for the claim section
          if (_isLoadingClaimStatus)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A4140)),
              ),
            )
          else if (isFounder) // If the current user is the founder
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to MyItemClaimsScreen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyItemClaimsScreen(
                        foundItemId: widget.reportId,
                        founderItemName: widget.data['itemName'] ?? 'Your Item',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.view_list, color: Color(0xFFF5DEB3)),
                label: const Text(
                  'View Claims on This Item',
                  style: TextStyle(fontSize: 18, color: Color(0xFFF5DEB3), fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A4140),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            )
          else if (showClaimButton) // Show button if not claimed yet
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () => _showClaimDialog(context),
                  icon: const Icon(Icons.assignment_turned_in, color: Color(0xFFF5DEB3)),
                  label: const Text(
                    'Claim This Item',
                    style: TextStyle(fontSize: 18, color: Color(0xFFF5DEB3), fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A4140),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              )
            else if (showClaimedMessage) // Show message if already claimed
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A4140), // A green background for "claimed" status
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFFF5DEB3)),
                        SizedBox(width: 8),
                        Text(
                          'You have already claimed this item',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Color(0xFFF5DEB3), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}