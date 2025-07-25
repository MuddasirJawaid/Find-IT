import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminStepperScreen extends StatefulWidget {
  final String reportId;

  const AdminStepperScreen({super.key, required this.reportId});

  @override
  State<AdminStepperScreen> createState() => _AdminStepperScreenState();
}

class _AdminStepperScreenState extends State<AdminStepperScreen> {
  int _currentStep = 0;
  String _status = 'with founder';
  bool _loading = true;
  bool _hasApprovedClaim = false;

  // New fields to store claim details
  String? _approvedClaimAnswer;
  String? _approvedClaimQuestion;
  String? _approvedClaimerEmail; // To be used for handoverBy

  @override
  void initState() {
    super.initState();
    _fetchCurrentStatus();
    _checkForApprovedClaim(); // This will now also fetch claim details
  }

  Future<void> _fetchCurrentStatus() async {
    final doc = await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).get();
    if (doc.exists) {
      final status = (doc.data()?['status'] ?? 'with founder') as String;
      setState(() {
        _status = status;
        _currentStep = status == 'with founder'
            ? 0
            : status == 'at police station'
            ? 1
            : status == 'collected at police station'
            ? 2
            : status == 'claimed by real owner'
            ? 3
            : 0;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Report not found.")),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _checkForApprovedClaim() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('claims')
          .where('itemId', isEqualTo: widget.reportId)
          .where('status', isEqualTo: 'approved')
          .limit(1) // We only need one approved claim to get its details
          .get();

      setState(() {
        _hasApprovedClaim = snapshot.docs.isNotEmpty;
        if (_hasApprovedClaim) {
          final claimData = snapshot.docs.first.data() as Map<String, dynamic>;
          _approvedClaimAnswer = claimData['answer'] as String?;
          _approvedClaimQuestion = claimData['question'] as String?;
          _approvedClaimerEmail = claimData['claimerEmail'] as String?;
        } else {
          _approvedClaimAnswer = null;
          _approvedClaimQuestion = null;
          _approvedClaimerEmail = null;
        }
      });
    } catch (e) {
      print("Error checking for approved claim: $e");
      // Optionally show an error to the user
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    Map<String, dynamic> updateData = {
      'status': newStatus,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'statusUpdatedBy': 'Admin',
    };

    // Add handoverTimestamp and claim-related details only when the item is marked as claimed by real owner
    if (newStatus == 'claimed by real owner') {
      updateData['handoverTimestamp'] = FieldValue.serverTimestamp();

      if (_hasApprovedClaim && _approvedClaimAnswer != null && _approvedClaimQuestion != null && _approvedClaimerEmail != null) {
        updateData['claimAnswer'] = _approvedClaimAnswer!;
        updateData['claimQuestion'] = _approvedClaimQuestion!;
        updateData['handoverBy'] = _approvedClaimerEmail!;
      } else {
        updateData['claimAnswer'] = 'N/A (No Approved Claim Data)';
        updateData['claimQuestion'] = 'N/A (No Approved Claim Data)';
        updateData['handoverBy'] = 'Admin (No Claim Data)';
      }
    }

    try {
      await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update(updateData);
      await _fetchCurrentStatus();
      await _checkForApprovedClaim();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status updated to '$newStatus'")),
        );
      }
    } catch (e) {
      print("Error updating status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update status: $e")),
        );
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E2A38),
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E2A38),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2A38),
        title: const Text('Admin Item Status Stepper', style: TextStyle(color: Colors.orange)),
        iconTheme: const IconThemeData(color: Colors.orange),
      ),
      body: Stepper(
        currentStep: _currentStep,
        type: StepperType.vertical,
        // --- YAHAN 'onStepContinue' KI LOGIC BADAL DI GAYI HAI ---
        onStepContinue: () async {
          if (_currentStep == 0) {
            // Admin can NOT directly mark 'at police station'. Founder must do it.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Founder must mark as 'At Police Station' first.")),
              );
            }
          } else if (_currentStep == 1) {
            // Admin can mark 'collected at police station' if current status is 'at police station'
            if (_status == 'at police station') {
              await _updateStatus('collected at police station');
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Item is not yet 'At Police Station'.")),
                );
              }
            }
          } else if (_currentStep == 2) {
            // Admin can mark 'claimed by real owner' if current status is 'collected at police station' AND claim is approved
            if (_status == 'collected at police station' && _hasApprovedClaim) {
              await _updateStatus('claimed by real owner');
            } else if (!_hasApprovedClaim) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No approved claim found for this item yet.")),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Item is not yet 'Collected at Police Station'.")),
                );
              }
            }
          }
          // No action for _currentStep == 3 as it's the final state
        },
        controlsBuilder: (context, details) {
          // --- YAHAN 'controlsBuilder' KI LOGIC BADAL DI GAYI HAI ---
          bool showButton = false;
          if (_currentStep == 1 && _status == 'at police station') {
            // Button dikhega agar current step 'At Police Station' hai aur status bhi wahi hai
            showButton = true;
          } else if (_currentStep == 2 && _status == 'collected at police station' && _hasApprovedClaim) {
            // Button dikhega agar current step 'Collected at Police Station' hai, status wahi hai, aur claim approved hai
            showButton = true;
          }

          // Agar current step already final step (Claimed by Real Owner) hai, toh button na dikhayein
          if (_currentStep == 3) {
            showButton = false;
          }

          return showButton
              ? Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Mark Next Step"),
            ),
          )
              : const SizedBox.shrink(); // Hide button if no action is currently possible
        },
        steps: [
          Step(
            title: const Text("With Founder", style: TextStyle(color: Colors.orange)),
            content: const Text(
                "The item is currently with the founder. Founder must mark as 'At Police Station'.",
                style: TextStyle(color: Colors.white70)),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("At Police Station", style: TextStyle(color: Colors.orange)),
            content: const Text(
              "The item has been transferred to the police station. Admin can mark as 'Collected'.",
              style: TextStyle(color: Colors.white70),
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Collected at Police Station", style: TextStyle(color: Colors.orange)),
            content: const Text(
              "The item has been successfully collected by  the police station. Admin can mark as 'Claimed' if approved.",
              style: TextStyle(color: Colors.white70),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Claimed by Real Owner", style: TextStyle(color: Colors.orange)),
            content: Text(
              _hasApprovedClaim
                  ? "An approved claim exists. Item can now be marked as 'Claimed by Real Owner'."
                  : "Waiting for an approved claim before marking as 'Claimed by Real Owner'.",
              style: const TextStyle(color: Colors.white70),
            ),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
    );
  }
}