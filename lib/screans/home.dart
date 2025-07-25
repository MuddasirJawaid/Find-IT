import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../provider/auth_provider.dart' as myAuth;
import '../widgets/found_widget.dart'; // Make sure this is the path to your FoundItemsTab
import '../widgets/missing_widget.dart'; // Make sure this is the path to your MissingItemsTab
import 'help.dart';
import 'history.dart';
import 'is_this_yours_screan.dart';
import 'my_reports_screan.dart';
import 'notifications.dart';
import 'profile.dart';
import 'report_found_item_screen.dart';
import 'report_missing_item_screen.dart';
import 'resetpassword.dart';

// (Your _HomeContentBody widget remains unchanged as it's not the source of this error)
class _HomeContentBody extends StatefulWidget {
  const _HomeContentBody({super.key});

  @override
  State<_HomeContentBody> createState() => _HomeContentBodyState();
}

class _HomeContentBodyState extends State<_HomeContentBody> {
  int _selectedChipIndex = 0;
  String _searchQuery = '';
  bool _nearbyFilter = false;
  Position? _currentPosition;
  bool _hasRequestedPermissionThisSession = false;

  // Define the desired filter radius here (1 km)
  final double _nearbyRadiusKm = 1.0; // 1 kilometer radius

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forceLocationPermissionOnLoad();
    });
  }

  Future<void> _forceLocationPermissionOnLoad() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location services are disabled. Please enable them for full functionality.")),
        );
      }
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && !_hasRequestedPermissionThisSession) {
      permission = await Geolocator.requestPermission();
      _hasRequestedPermissionThisSession = true;
      if (permission == LocationPermission.denied) {
        if (mounted) _showPermissionDeniedDialogAndForceAction();
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showPermissionDeniedForeverDialogAndForceAction();
      return;
    }
  }

  void _showPermissionDeniedDialogAndForceAction() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Permission Required"),
          content: const Text("This app requires location permission to function. Please grant permission to continue."),
          actions: <Widget>[
            TextButton(
              child: const Text("Grant Permission"),
              onPressed: () {
                Navigator.of(context).pop();
                _forceLocationPermissionOnLoad();
              },
            ),
            TextButton(
              child: const Text("Exit App"),
              onPressed: () {
                SystemNavigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedForeverDialogAndForceAction() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Location Permission Permanently Denied"),
          content: const Text("Location permission is permanently denied. Please go to app settings and enable it manually to use this app."),
          actions: <Widget>[
            TextButton(
              child: const Text("Open Settings"),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings().then((_) {
                  _forceLocationPermissionOnLoad();
                });
              },
            ),
            TextButton(
              child: const Text("Exit App"),
              onPressed: () {
                SystemNavigator.pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location services are disabled. Please enable them to use Nearby.")),
        );
      }
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are denied. Cannot use nearby filter.")),
          );
        }
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permissions are permanently denied. Enable from app settings.")),
        );
        Geolocator.openAppSettings();
      }
      return;
    }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _nearbyFilter = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Nearby filter applied within ${_nearbyRadiusKm}km!")), // Updated message
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    int crossAxisCount = width > 600 ? 3 : (width > 400 ? 2 : 1);
    double aspectRatio = width > 600 ? 0.9 : 0.8;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
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
              ),
              IconButton(
                icon: const Icon(Icons.location_on, color: Color(0xFF1A4140)),
                tooltip: 'Nearby your location',
                onPressed: _getCurrentLocation,
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Nearby filter cleared.")),
                      );
                    }
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
            distanceFilterKm: _nearbyRadiusKm, // Pass the 1km radius here
          )
              : MissingItemsTab( // Assuming you have a MissingItemsTab similar to FoundItemsTab
            crossAxisCount: crossAxisCount,
            aspectRatio: aspectRatio,
            searchQuery: _searchQuery,
            nearbyPosition: _nearbyFilter ? _currentPosition : null,
            distanceFilterKm: _nearbyRadiusKm, // Pass the 1km radius here
          ),
        ),
      ],
    );
  }
}

// --- START: Main Homescreen (Now with Bottom Navigation) ---
class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  int _currentIndex = 0; // Controls the selected tab in BottomNavigationBar

  // Updated List of screens for the BottomNavigationBar
  final List<Widget> _screens = [
    const _HomeContentBody(),     // Index 0: Home/Main Content
    const IsThisYoursScreen(),    // Index 1: "Is This Yours?"
    const NotificationsScreen(),  // Index 2: Notifications
    const ProfileTab(),           // Index 3: Profile
  ];

  void _onFabPressed(BuildContext context) {
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
  }

  @override
  Widget build(BuildContext context) {
    // Ensure you handle the case where user might be null, e.g., if not logged in
    final userEmail = Provider.of<myAuth.AuthProvider>(context).user?.email ?? "Guest";

    return Scaffold(
      backgroundColor: const Color(0xFFF5DEB3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A4140),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFFFF8E7)),
        title: Row(
          mainAxisSize: MainAxisSize.min, // Use min to center the Row content
          children: [
            const Icon(Icons.travel_explore_rounded,
                color: Color(0xFFF5DEB3), size: 28),
            const SizedBox(width: 8),
            const Text('Find-IT',
                style: TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            // Removed Spacer and IconButton from here to simplify AppBar title
            // as profile is now in bottom nav and drawer
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
                Navigator.pop(context); // Close drawer
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyReportsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications, color: Color(0xFFF5DEB3)),
              title: const Text('Notifications', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to notifications screen, or switch bottom nav tab
                setState(() { _currentIndex = 2; }); // Switch to notifications tab
              },
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFFF5DEB3)),
              title: const Text('Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile screen, or switch bottom nav tab
                setState(() { _currentIndex = 3; }); // Switch to profile tab
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFFF5DEB3)),
              title: const Text('History', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              },
            ),
            const Divider(color: Colors.white70),
            ListTile(
              leading: const Icon(Icons.lock_reset, color: Color(0xFFF5DEB3)),
              title: const Text('Reset Password',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: Color(0xFFF5DEB3)),
              title: const Text('Help', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context); // Close drawer
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const HelpScreen()));
              },
            ),
            const Divider(color: Colors.white70),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                await Provider.of<myAuth.AuthProvider>(context, listen: false).logout();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A4140),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Color(0xFFF5DEB3)),
        onPressed: () => _onFabPressed(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF1A4140),
        shape: const CircularNotchedRectangle(),
        notchMargin: 6.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // Left items
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 0; // Home
                  });
                },
                child: SizedBox(
                  height: 38.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home,
                        size: 20.0,
                        color: _currentIndex == 0 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                      ),
                      FittedBox(
                        child: Text(
                          'Home',
                          style: TextStyle(
                            color: _currentIndex == 0 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 1; // Is This Yours?
                  });
                },
                child: SizedBox(
                  height: 38.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.question_mark_rounded,
                        size: 20.0,
                        color: _currentIndex == 1 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                      ),
                      FittedBox(
                        child: Text(
                          'Is This Yours?',
                          style: TextStyle(
                            color: _currentIndex == 1 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Spacer for FAB
            const SizedBox(width: 48),

            // Right items
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 2; // Notifications
                  });
                },
                child: SizedBox(
                  height: 38.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications,
                        size: 20.0,
                        color: _currentIndex == 2 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                      ),
                      FittedBox(
                        child: Text(
                          'Notify',
                          style: TextStyle(
                            color: _currentIndex == 2 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _currentIndex = 3; // Profile
                  });
                },
                child: SizedBox(
                  height: 38.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person,
                        size: 20.0,
                        color: _currentIndex == 3 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                      ),
                      FittedBox(
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            color: _currentIndex == 3 ? const Color(0xFFF5DEB3) : const Color(0xFFFFF8E7),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}