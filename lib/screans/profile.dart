import 'dart:convert';
import 'dart:typed_data';
import 'dart:io'; // File ke liye
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  Map<String, dynamic> userData = {};
  bool isEditing = false;

  /// Pick + compress + save image
  Future<void> _pickImage(User user) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile =
      await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);

        // ✅ Compress image (safe handling)
        final compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          minWidth: 300,
          minHeight: 300,
          quality: 70,
        );

        if (compressedBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image compression failed")),
          );
          return;
        }

        // ✅ Convert to Base64
        String base64Image = base64Encode(compressedBytes);

        // ✅ Save to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({"profilePic": base64Image});

        setState(() {
          userData["profilePic"] = base64Image;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated")),
        );
      }
    } catch (e) {
      debugPrint("Image Pick Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text("No user logged in"));
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.orange));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("Profile data not found"));
        }

        userData = snapshot.data!.data() as Map<String, dynamic>;

        // ✅ Decode profile pic if exists
        Uint8List? profileImageBytes;
        if (userData["profilePic"] != null &&
            userData["profilePic"].toString().isNotEmpty) {
          try {
            profileImageBytes = base64Decode(userData["profilePic"]);
          } catch (e) {
            debugPrint("Base64 decode error: $e");
          }
        }

        return Container(
          color: const Color(0xFFF5DEB3), // Same background as Home
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              color: const Color(0xFFFFF8E7), // Light cream card
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFF1A4140),
                              backgroundImage: profileImageBytes != null
                                  ? MemoryImage(profileImageBytes)
                                  : null,
                              child: profileImageBytes == null
                                  ? const Icon(Icons.person,
                                  size: 50, color: Colors.white)
                                  : null,
                            ),
                            if (isEditing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () => _pickImage(user),
                                  child: const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.camera_alt,
                                        color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildInfoField("First Name", "firstName"),
                      _buildInfoField("Last Name", "lastName"),
                      _buildInfoField("Email", "email", readOnly: true),
                      _buildInfoField("Phone", "phone"),
                      _buildInfoField("City", "city"),

                      const SizedBox(height: 20),

                      if (isEditing)
                        Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A4140)),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                _formKey.currentState!.save();
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(user.uid)
                                    .update(userData);

                                setState(() {
                                  isEditing = false;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Profile Updated")),
                                );
                              }
                            },
                            icon: const Icon(Icons.save, color: Colors.white),
                            label: const Text("Save Changes",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Center(
                      //   child: ElevatedButton.icon(
                      //     style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.red),
                      //     onPressed: () async {
                      //       await FirebaseAuth.instance.signOut();
                      //       if (mounted) {
                      //         Navigator.pushNamedAndRemoveUntil(
                      //             context, '/login', (route) => false);
                      //       }
                      //     },
                      //     icon: const Icon(Icons.logout, color: Colors.white),
                      //     label: const Text("Logout",
                      //         style: TextStyle(color: Colors.white)),
                      //   ),
                      // ),

                      const SizedBox(height: 20),

                      Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1A4140)),
                          ),
                          onPressed: () {
                            setState(() {
                              isEditing = !isEditing;
                            });
                          },
                          icon: Icon(
                              isEditing ? Icons.close : Icons.edit,
                              color: const Color(0xFF1A4140)),
                          label: Text(isEditing ? "Cancel" : "Edit Profile",
                              style: const TextStyle(
                                  color: Color(0xFF1A4140))),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Info Field Builder
  Widget _buildInfoField(String label, String key, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: isEditing && !readOnly
          ? TextFormField(
        initialValue: userData[key] ?? "",
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onSaved: (value) {
          userData[key] = value ?? "";
        },
      )
          : Row(
        children: [
          Text("$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
                userData[key] != null &&
                    userData[key].toString().isNotEmpty
                    ? userData[key].toString()
                    : "N/A"),
          ),
        ],
      ),
    );
  }
}
