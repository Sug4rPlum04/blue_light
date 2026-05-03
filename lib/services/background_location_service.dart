import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class BackgroundLocationService {
  BackgroundLocationService._();

  static final BackgroundLocationService instance = BackgroundLocationService._();

  StreamSubscription<Position>? _positionSubscription;
  String? _activeUserId;

  Future<void> syncForCurrentUser() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await stop();
      return;
    }

    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    final bool trackingEnabled =
        (data['locationTrackingEnabled'] as bool?) ?? false;
    final bool disclosureAccepted =
        data['backgroundLocationDisclosureAcceptedAt'] != null;

    if (!trackingEnabled || !disclosureAccepted) {
      await stop();
      return;
    }

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await stop();
      return;
    }

    final LocationPermission permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      await stop();
      return;
    }

    _activeUserId = user.uid;
    try {
      final Position firstFix = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      await _syncLocation(user.uid, firstFix);
    } catch (_) {}

    if (_positionSubscription != null) {
      return;
    }

    final LocationSettings settings = defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
            intervalDuration: const Duration(seconds: 20),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Blue Light location sharing active',
              notificationText:
                  'Updating your location for trusted safety features.',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((Position position) {
      final String? userId = _activeUserId;
      if (userId == null) {
        return;
      }
      unawaited(_syncLocation(userId, position));
    });
  }

  Future<void> stop() async {
    _activeUserId = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _syncLocation(String userId, Position position) {
    return FirebaseFirestore.instance.collection('users').doc(userId).set(
      <String, Object?>{
        'locationLat': position.latitude,
        'locationLng': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
