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

  @override
  void initState() {
    super.initState();
    _fetchCurrentStatus();
    _checkForApprovedClaim();
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
    }
  }

  Future<void> _checkForApprovedClaim() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('claims')
        .where('itemId', isEqualTo: widget.reportId)
        .where('status', isEqualTo: 'approved')
        .get();

    setState(() {
      _hasApprovedClaim = snapshot.docs.isNotEmpty;
    });
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    await FirebaseFirestore.instance.collection('reports').doc(widget.reportId).update({
      'status': newStatus,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
      'statusUpdatedBy': 'Admin',
    });
    await _fetchCurrentStatus();
    await _checkForApprovedClaim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Status updated to '$newStatus'")),
    );
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
        onStepContinue: () async {
          if (_currentStep == 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Founder must mark as 'At Police Station' first.")),
            );
          } else if (_currentStep == 1) {
            await _updateStatus('collected at police station');
          } else if (_currentStep == 2) {
            if (_hasApprovedClaim) {
              await _updateStatus('claimed by real owner');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No approved claim found for this item yet.")),
              );
            }
          }
        },
        controlsBuilder: (context, details) {
          final canProceed =
              (_currentStep == 1 && _status == 'at police station') ||
                  (_currentStep == 2 && _status == 'collected at police station' && _hasApprovedClaim);

          return canProceed
              ? Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text("Mark Next Step"),
            ),
          )
              : const SizedBox.shrink();
        },
        steps: [
          Step(
            title: const Text("With Founder", style: TextStyle(color: Colors.orange)),
            content: const Text("The item is currently with the founder.",
                style: TextStyle(color: Colors.white70)),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("At Police Station", style: TextStyle(color: Colors.orange)),
            content: const Text(
              "Founder must mark as 'At Police Station' before admin can proceed.",
              style: TextStyle(color: Colors.white70),
            ),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Collected at Police Station", style: TextStyle(color: Colors.orange)),
            content: const Text(
              "Admin can mark as 'Collected at Police Station' once the item has been handed over.",
              style: TextStyle(color: Colors.white70),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text("Claimed by Real Owner", style: TextStyle(color: Colors.orange)),
            content: Text(
              _hasApprovedClaim
                  ? "An approved claim exists. You can mark as 'Claimed by Real Owner'."
                  : "Waiting for a claimer to submit a claim that gets approved before proceeding.",
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
