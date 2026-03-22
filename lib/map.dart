import 'dart:async';

import 'package:blue_light/friends.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/message.dart';
import 'package:blue_light/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:blue_light/ui/shell_chrome.dart';

class MyMapPage extends StatefulWidget {
  const MyMapPage({super.key, required this.title});

  final String title;

  @override
  State<MyMapPage> createState() => _MyMapPageState();
}

class _MyMapPageState extends State<MyMapPage> {
  final MapController _mapController = MapController();

  bool _isLoading = true;
  bool _trackingEnabled = true;
  bool _isLocating = false;
  String? _statusMessage;
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionSub;

  @override
  void initState() {
    super.initState();
    _initializeMapTracking();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _initializeMapTracking() async {
    _positionSub?.cancel();

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _isLocating = true;
      _statusMessage = null;
      _currentLatLng = null;
      _trackingEnabled = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _isLocating = false;
          _statusMessage = 'Please log in first.';
        });
        return;
      }

      bool trackingEnabled = true;
      try {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get()
                .timeout(const Duration(seconds: 5));
        trackingEnabled =
            (snapshot.data()?['locationTrackingEnabled'] as bool?) ?? true;
      } catch (_) {
        trackingEnabled = true;
      }

      if (!trackingEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _trackingEnabled = false;
          _isLoading = false;
          _isLocating = false;
        });
        return;
      }

      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _isLocating = false;
          _statusMessage = 'Location services are off on this device.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isLoading = false;
          _isLocating = false;
          _statusMessage = 'Location permission denied.';
        });
        return;
      }

      final Position current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      if (!mounted) {
        return;
      }

      final LatLng firstFix = LatLng(current.latitude, current.longitude);
      setState(() {
        _currentLatLng = firstFix;
        _isLoading = false;
        _isLocating = false;
      });

      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 8,
        ),
      ).listen((Position position) {
        if (!mounted) {
          return;
        }
        final LatLng next = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLatLng = next;
        });
        _mapController.move(next, _mapController.camera.zoom);
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLocating = false;
        _statusMessage =
            'Timed out waiting for GPS fix. Try again or check emulator location.';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLocating = false;
        _statusMessage = 'Unable to get your location right now.';
      });
    }
  }

  Widget _buildTrackingOffView() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.location_off, size: 38, color: Colors.redAccent),
              SizedBox(height: 12),
              Text(
                'Location tracking is off',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Go to Profile Settings to turn location tracking on.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.gps_off_rounded, size: 38, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _statusMessage ?? 'Location unavailable.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _initializeMapTracking,
              child: const Text('Try Again'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Geolocator.openAppSettings();
              },
              child: const Text('Open App Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBody() {
    if (_isLoading || _isLocating) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_trackingEnabled) {
      return _buildTrackingOffView();
    }

    if (_currentLatLng == null) {
      return _buildLocationErrorView();
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLatLng!,
        initialZoom: 16,
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.blue_light',
        ),
        MarkerLayer(
          markers: <Marker>[
            Marker(
              point: _currentLatLng!,
              width: 70,
              height: 82,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.lightBlue,
                    child: const Icon(Icons.person_pin_circle, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'You',
                      style: TextStyle(color: Colors.white, fontSize: 10.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: BlueLightTopBar(
        title: widget.title,
        onProfileTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<MyProfilePage>(
              builder: (BuildContext context) =>
                  const MyProfilePage(title: "Profile"),
            ),
          );
        },
      ),
      floatingActionButton: buildBlueLightFab(() {}),
      floatingActionButtonLocation: blueLightFabLocation,
      bottomNavigationBar: BlueLightBottomNav(
        currentIndex: 1,
        onTap: (int index) {
          if (index == 1) {
            return;
          }
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<MyHomePage>(
                builder: (BuildContext context) =>
                    const MyHomePage(title: "Home"),
              ),
            );
            return;
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<MyMessagePage>(
                builder: (BuildContext context) =>
                    const MyMessagePage(title: "Messages"),
              ),
            );
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<MyFriendsPage>(
              builder: (BuildContext context) =>
                  const MyFriendsPage(title: "Friends"),
            ),
          );
        },
      ),
      body: _buildMapBody(),
    );
  }
}

Widget _navItem({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    ),
  );
}
