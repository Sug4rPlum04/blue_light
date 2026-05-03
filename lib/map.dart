import 'dart:async';

import 'package:blue_light/friends.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/message.dart';
import 'package:blue_light/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:blue_light/ui/emergency_alerts.dart';
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
  bool _trackingEnabled = false;
  bool _isLocating = false;
  String? _statusMessage;
  LatLng? _currentLatLng;
  StreamSubscription<Position>? _positionSub;
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _syncLocationToProfile(Position position) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      <String, Object?>{
        'locationLat': position.latitude,
        'locationLng': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

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
      _trackingEnabled = false;
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

      late final bool trackingEnabled;
      try {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get()
                .timeout(const Duration(seconds: 8));
        trackingEnabled =
            (snapshot.data()?['locationTrackingEnabled'] as bool?) ?? false;
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _trackingEnabled = true;
          _isLoading = false;
          _isLocating = false;
          _statusMessage =
              'Could not load your tracking setting. Check connection and try again.';
        });
        return;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _trackingEnabled = trackingEnabled;
      });

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
      await _syncLocationToProfile(current);
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
        unawaited(_syncLocationToProfile(position));
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

    final String? userId = _currentUserId;
    if (userId == null) {
      return _buildLocationErrorView();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> meSnapshot,
      ) {
        final Set<String> friendIds =
            ((meSnapshot.data?.data()?['friendIds'] as List?) ?? <dynamic>[])
                .whereType<String>()
                .toSet();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> usersSnapshot,
          ) {
            final List<Marker> clusterMarkers = <Marker>[
              _selfMarker(_currentLatLng!),
            ];

            final Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs =
                usersSnapshot.data?.docs ??
                    <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in userDocs) {
              if (!friendIds.contains(doc.id)) {
                continue;
              }
              final Map<String, dynamic> data = doc.data();
              final bool trackingOn =
                  (data['locationTrackingEnabled'] as bool?) ?? false;
              if (!trackingOn) {
                continue;
              }
              final num? lat = data['locationLat'] as num?;
              final num? lng = data['locationLng'] as num?;
              if (lat == null || lng == null) {
                continue;
              }

              final String username =
                  (data['username'] as String?)?.trim().isNotEmpty == true
                      ? (data['username'] as String).trim()
                      : ((data['email'] as String?)?.split('@').first ?? 'Friend');
              final String photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';

              clusterMarkers.add(
                _friendMarker(
                  point: LatLng(lat.toDouble(), lng.toDouble()),
                  username: username,
                  photoUrl: photoUrl,
                ),
              );
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
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerOptions(
                    markers: clusterMarkers,
                    maxClusterRadius: 55,
                    size: const Size(54, 54),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(44),
                    maxZoom: 17,
                    spiderfyCircleRadius: 42,
                    spiderfySpiralDistanceMultiplier: 2,
                    builder: (
                      BuildContext context,
                      List<Marker> clusterMarkers,
                    ) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF31B2FF),
                              Color(0xFF1578D0),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5,
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x402177C2),
                              blurRadius: 12,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${clusterMarkers.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Marker _selfMarker(LatLng point) {
    return Marker(
      point: point,
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
    );
  }

  Marker _friendMarker({
    required LatLng point,
    required String username,
    required String photoUrl,
  }) {
    return Marker(
      point: point,
      width: 96,
      height: 92,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isNotEmpty
                ? null
                : const Icon(Icons.person_rounded, color: Color(0xFF0F7DCF)),
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 90),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xEE1A76C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
        onEmergencyTap: () {
          showEmergencyAlertDialog(context);
        },
      ),
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
