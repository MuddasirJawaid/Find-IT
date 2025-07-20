import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Geolocator package
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import '../provider/auth_provider.dart' as myAuth;
import '../widgets/found_widget.dart'; // Make sure this path is correct
import '../widgets/missing_widget.dart'; // Make sure this path is correct
import 'help.dart';
import 'my_reports_screan.dart'; // Make sure this path is correct
import 'notifications.dart'; // Make sure this path is correct
import 'profile.dart'; // Make sure this path is correct
import 'report_found_item_screen.dart'; // Make sure this path is correct
import 'report_missing_item_screen.dart'; // Make sure this path is correct
import 'resetpassword.dart'; // Make sure this path is correct

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int _selectedChipIndex = 0; // For Found/Missing items
  String _searchQuery = '';
  bool _nearbyFilter = false;
  Position? _currentPosition;

  // Track if location permission dialog has been shown during this app launch
  // This helps to prevent repetitive requests if a dialog is dismissed (though now barrierDismissible is false).
  bool _hasRequestedPermissionThisSession = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is available and widget tree is built
    // before performing an async operation that might show dialogs.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceLocationPermissionOnLoad();
    });
  }

  // New function: Forcefully request location permission on app load
  // User cannot proceed without granting permission or explicitly exiting.
  Future<void> _forceLocationPermissionOnLoad() async {
    // Check if location services are enabled.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // If location services are disabled, we still attempt to request permission.
      // The OS might prompt the user to enable services first.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location services are disabled. Please enable them for full functionality.")),
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied && !_hasRequestedPermissionThisSession) {
      // If permission is denied and we haven't requested it yet in this session, request it.
      permission = await Geolocator.requestPermission();
      _hasRequestedPermissionThisSession = true; // Mark as requested

      if (permission == LocationPermission.denied) {
        // If permission is still denied after the request, show the force dialog.
        _showPermissionDeniedDialogAndForceAction();
        return; // Stop further execution until user acts.
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // If permissions are denied forever, force user to settings.
      _showPermissionDeniedForeverDialogAndForceAction();
      return; // Stop further execution until user acts.
    }

    // If permission is granted (or was already granted) and services are handled,
    // the app can proceed. We don't fetch location automatically here,
    // it will be fetched when the user taps 'Nearby'.
  }

  // Dialog for when permission is denied (not forever) - forces user to act.
  void _showPermissionDeniedDialogAndForceAction() {
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Permission Required"),
          content: const Text("This app requires location permission to function. Please grant permission to continue."),
          actions: <Widget>[
            TextButton(
              child: const Text("Grant Permission"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                // Re-attempt to request permission. This will often bring up the OS dialog again.
                _forceLocationPermissionOnLoad();
              },
            ),
            TextButton(
              child: const Text("Exit App"),
              onPressed: () {
                // Exit the app if user doesn't grant permission
                SystemNavigator.pop(); // A more robust way to exit the app
              },
            ),
          ],
        );
      },
    );
  }

  // Dialog for when permission is permanently denied - forces user to settings or exit.
  void _showPermissionDeniedForeverDialogAndForceAction() {
    showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Permission Permanently Denied"),
          content: const Text("Location permission is permanently denied. Please go to app settings and enable it manually to use this app."),
          actions: <Widget>[
            TextButton(
              child: const Text("Open Settings"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Geolocator.openAppSettings().then((_) {
                  // After returning from app settings, re-check permission
                  _forceLocationPermissionOnLoad();
                });
              },
            ),
            TextButton(
              child: const Text("Exit App"),
              onPressed: () {
                SystemNavigator.pop(); // A more robust way to exit the app
              },
            ),
          ],
        );
      },
    );
  }

  // Function to get current location when 'Nearby' button is pressed
  // This remains mostly the same, as it's a specific user action for location.
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location services are disabled. Please enable them to use Nearby.")),
      );
      // Optional: Geolocator.openLocationSettings(); // Can add this to directly open settings
      return;
    }

    // Even though _forceLocationPermissionOnLoad runs on start,
    // a quick re-check here is good practice before fetching location.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // If by some chance it got denied between load and button press, request again.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are denied. Cannot use nearby filter.")),
        );
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location permissions are permanently denied. Enable from app settings.")),
      );
      Geolocator.openAppSettings(); // Open settings for the user
      return;
    }

    // If permissions are granted and services are enabled, get the current position
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _nearbyFilter = true; // Activate nearby filter
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nearby filter applied!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error getting location: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 600 ? 3 : (width > 400 ? 2 : 1);
    double aspectRatio = width > 600 ? 0.9 : 0.8;
    final userEmail =
        Provider.of<myAuth.AuthProvider>(context).user?.email ?? "No Email";

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
            const Text('Find-IT',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.person, color: Color(0xFFFFF8E7)),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileTab()));
              },
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1A4140),
        child: ListView(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF1A4140)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_circle,
                      color: Color(0xFFF5DEB3), size: 50),
                  const SizedBox(height: 10),
                  Text(userEmail,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.assignment, color: Color(0xFFF5DEB3)),
              title:
              const Text('My Reports', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyReportsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: Color(0xFFF5DEB3)),
              title: const Text('Notifications', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
            ),
            const Divider(color: Colors.white70),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Color(0xFFF5DEB3)),
              title: const Text('Reset Password',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ResetPasswordScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFFF5DEB3)),
              title: const Text('Help', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const HelpScreen())),
            ),
            const Divider(color: Colors.white70),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await Provider.of<myAuth.AuthProvider>(context, listen: false).logout(); // Assuming logout no longer needs context
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ),

          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.7,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by item name or description',
                      hintStyle: const TextStyle(color: Colors.black),
                      prefixIcon: const Icon(Icons.search, color: Colors.black),
                      border: InputBorder.none,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim();
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.location_on, color: Color(0xFF1A4140)),
                  tooltip: 'Nearby your location',
                  onPressed: _getCurrentLocation, // Now calls the updated function
                ),
                if (_nearbyFilter)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Clear nearby filter',
                    onPressed: () {
                      setState(() {
                        _nearbyFilter = false;
                        _currentPosition = null;
                      });
                    },
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(
                    'Found Items',
                    style: TextStyle(
                      color: _selectedChipIndex == 0
                          ? const Color(0xFFF5DEB3)
                          : const Color(0xFF1A4140),
                    ),
                  ),
                  selected: _selectedChipIndex == 0,
                  selectedColor: const Color(0xFF1A4140),
                  backgroundColor: const Color(0xFFFFF8E7),
                  onSelected: (_) => setState(() => _selectedChipIndex = 0),
                  checkmarkColor: const Color(0xFFF5DEB3),
                ),
                ChoiceChip(
                  label: Text(
                    'Missing Items',
                    style: TextStyle(
                      color: _selectedChipIndex == 1
                          ? const Color(0xFFF5DEB3)
                          : const Color(0xFF1A4140),
                    ),
                  ),
                  selected: _selectedChipIndex == 1,
                  selectedColor: const Color(0xFF1A4140),
                  backgroundColor: const Color(0xFFFFF8E7),
                  onSelected: (_) => setState(() => _selectedChipIndex = 1),
                  checkmarkColor: const Color(0xFFF5DEB3),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedChipIndex == 0
                ? FoundItemsTab(
              crossAxisCount: crossAxisCount,
              aspectRatio: aspectRatio,
              searchQuery: _searchQuery,
              nearbyPosition: _nearbyFilter ? _currentPosition : null,
            )
                : MissingItemsTab(
              crossAxisCount: crossAxisCount,
              aspectRatio: aspectRatio,
              searchQuery: _searchQuery,
              nearbyPosition: _nearbyFilter ? _currentPosition : null,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A4140),
        child: const Icon(Icons.add, color: Color(0xFFF5DEB3)),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFFF5DEB3),
            builder: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.report, color: Color(0xFF1A4140)),
                  title: const Text(
                    'Report Missing Item',
                    style: TextStyle(
                      color: Color(0xFF1A4140),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportMissingItemScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.publish, color: Color(0xFF1A4140)),
                  title: const Text(
                    'Publish Found Item',
                    style: TextStyle(
                      color: Color(0xFF1A4140),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportFoundItemScreen()));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}