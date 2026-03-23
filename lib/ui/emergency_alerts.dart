import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

enum EmergencyAudience {
  personalFriends,
  nearbyFriends,
  both,
}

enum EmergencySituation {
  feelingUnsafe,
  beingTracked,
  custom,
}

Future<void> showEmergencyAlertDialog(BuildContext context) async {
  EmergencyAudience? selectedAudience;
  EmergencySituation? selectedSituation;
  final TextEditingController customSituationController =
      TextEditingController();
  bool includeEmergencyLevel = false;
  double emergencyLevel = 3;
  bool isSubmitting = false;
  String? dialogError;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          Future<void> submitAlert() async {
            if (selectedAudience == null) {
              setState(() {
                dialogError = 'Please choose who to notify.';
              });
              return;
            }

            setState(() {
              isSubmitting = true;
              dialogError = null;
            });

            try {
              final int recipientCount = await _dispatchEmergencyAlert(
                selectedAudience: selectedAudience!,
                selectedSituation: selectedSituation,
                customSituation: customSituationController.text.trim(),
                emergencyLevel: includeEmergencyLevel
                    ? emergencyLevel.round()
                    : null,
              );

              if (!context.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Emergency alert sent to $recipientCount people.',
                  ),
                ),
              );
            } catch (e) {
              setState(() {
                dialogError = e.toString().replaceFirst('Exception: ', '');
              });
            } finally {
              if (context.mounted) {
                setState(() {
                  isSubmitting = false;
                });
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Emergency Alert',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Who should we notify? *',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _audienceTile(
                    title: 'Personal friends',
                    subtitle: 'Notify emergency contacts from Profile settings.',
                    value: EmergencyAudience.personalFriends,
                    groupValue: selectedAudience,
                    onChanged: (EmergencyAudience? value) {
                      setState(() {
                        selectedAudience = value;
                      });
                    },
                  ),
                  _audienceTile(
                    title: 'Friends within distance',
                    subtitle: 'Notify users near your current location.',
                    value: EmergencyAudience.nearbyFriends,
                    groupValue: selectedAudience,
                    onChanged: (EmergencyAudience? value) {
                      setState(() {
                        selectedAudience = value;
                      });
                    },
                  ),
                  _audienceTile(
                    title: 'Both',
                    subtitle: 'Notify personal contacts and nearby users.',
                    value: EmergencyAudience.both,
                    groupValue: selectedAudience,
                    onChanged: (EmergencyAudience? value) {
                      setState(() {
                        selectedAudience = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'What is the situation? (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _situationTile(
                    title: 'Feeling unsafe',
                    value: EmergencySituation.feelingUnsafe,
                    groupValue: selectedSituation,
                    onChanged: (EmergencySituation? value) {
                      setState(() {
                        selectedSituation = value;
                      });
                    },
                  ),
                  _situationTile(
                    title: 'Being tracked',
                    value: EmergencySituation.beingTracked,
                    groupValue: selectedSituation,
                    onChanged: (EmergencySituation? value) {
                      setState(() {
                        selectedSituation = value;
                      });
                    },
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedSituation = EmergencySituation.custom;
                      });
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Radio<EmergencySituation>(
                          value: EmergencySituation.custom,
                          groupValue: selectedSituation,
                          onChanged: (EmergencySituation? value) {
                            setState(() {
                              selectedSituation = value;
                            });
                          },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TextField(
                              controller: customSituationController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'Type your own situation (optional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onTap: () {
                                setState(() {
                                  selectedSituation = EmergencySituation.custom;
                                });
                              },
                              onChanged: (String value) {
                                if (value.trim().isNotEmpty) {
                                  setState(() {
                                    selectedSituation = EmergencySituation.custom;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Checkbox(
                        value: includeEmergencyLevel,
                        onChanged: (bool? value) {
                          setState(() {
                            includeEmergencyLevel = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Include level of emergency (Optional)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    includeEmergencyLevel
                        ? '${emergencyLevel.round()} / 5'
                        : 'Not included',
                    style: const TextStyle(fontSize: 12),
                  ),
                  IgnorePointer(
                    ignoring: !includeEmergencyLevel,
                    child: Opacity(
                      opacity: includeEmergencyLevel ? 1 : 0.45,
                      child: Slider(
                        value: emergencyLevel,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: emergencyLevel.round().toString(),
                        onChanged: (double value) {
                          setState(() {
                            emergencyLevel = value;
                          });
                        },
                      ),
                    ),
                  ),
                  if (dialogError != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                      },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : submitAlert,
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Notify'),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _audienceTile({
  required String title,
  required String subtitle,
  required EmergencyAudience value,
  required EmergencyAudience? groupValue,
  required ValueChanged<EmergencyAudience?> onChanged,
}) {
  return RadioListTile<EmergencyAudience>(
    dense: true,
    contentPadding: EdgeInsets.zero,
    value: value,
    groupValue: groupValue,
    onChanged: onChanged,
    title: Text(title),
    subtitle: Text(subtitle),
  );
}

Widget _situationTile({
  required String title,
  required EmergencySituation value,
  required EmergencySituation? groupValue,
  required ValueChanged<EmergencySituation?> onChanged,
}) {
  return RadioListTile<EmergencySituation>(
    dense: true,
    contentPadding: EdgeInsets.zero,
    value: value,
    groupValue: groupValue,
    onChanged: onChanged,
    title: Text(title),
  );
}

Future<int> _dispatchEmergencyAlert({
  required EmergencyAudience selectedAudience,
  EmergencySituation? selectedSituation,
  required String customSituation,
  required int? emergencyLevel,
}) async {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    throw Exception('You need to be logged in to send alerts.');
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DocumentSnapshot<Map<String, dynamic>> senderSnapshot = await firestore
      .collection('users')
      .doc(currentUser.uid)
      .get();
  final Map<String, dynamic> senderData = senderSnapshot.data() ?? <String, dynamic>{};

  final Set<String> recipientIds = <String>{};
  final double nearbyMiles =
      (senderData['nearbyAlertRadiusMiles'] as num?)?.toDouble() ?? 5.0;

  if (selectedAudience == EmergencyAudience.personalFriends ||
      selectedAudience == EmergencyAudience.both) {
    final Set<String> trustedIds = _extractTrustedIds(senderData);
    if (trustedIds.isNotEmpty) {
      recipientIds.addAll(trustedIds);
    } else {
      final List<String> trustedEmails = _extractTrustedEmails(senderData);
      final Set<String> fallbackIds = await _fetchUserIdsForEmails(trustedEmails);
      recipientIds.addAll(fallbackIds);
    }
  }

  if (selectedAudience == EmergencyAudience.nearbyFriends ||
      selectedAudience == EmergencyAudience.both) {
    final Position currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
    final Set<String> nearbyIds = await _fetchNearbyUserIds(
      originLat: currentPosition.latitude,
      originLng: currentPosition.longitude,
      radiusMiles: nearbyMiles,
    );
    recipientIds.addAll(nearbyIds);
  }

  recipientIds.remove(currentUser.uid);

  if (recipientIds.isEmpty) {
    throw Exception('No recipients found for the selected notification option.');
  }

  final String senderName =
      (senderData['username'] as String?)?.trim().isNotEmpty == true
          ? (senderData['username'] as String).trim()
          : 'A user';
  final String senderEmail = currentUser.email ?? '';
  final String? situationLabel = _buildSituationLabel(
    selectedSituation: selectedSituation,
    customSituation: customSituation,
  );
  final String audienceLabel = _audienceLabel(selectedAudience);

  final WriteBatch batch = firestore.batch();
  for (final String recipientId in recipientIds) {
    final DocumentReference<Map<String, dynamic>> activityRef = firestore
        .collection('users')
        .doc(recipientId)
        .collection('activity')
        .doc();
    batch.set(activityRef, <String, dynamic>{
      'type': 'emergency_alert',
      'title': 'Emergency alert from $senderName',
      'message': situationLabel == null
          ? '$senderName sent an emergency alert.'
          : '$senderName reported: $situationLabel',
      'audience': audienceLabel,
      'fromUserId': currentUser.uid,
      'fromEmail': senderEmail,
      'createdAt': FieldValue.serverTimestamp(),
      if (emergencyLevel != null) 'emergencyLevel': emergencyLevel,
    });
  }
  await batch.commit();
  return recipientIds.length;
}

List<String> _extractTrustedEmails(Map<String, dynamic> data) {
  final dynamic raw = data['trustedContactEmails'];
  if (raw is List) {
    return raw
        .whereType<String>()
        .map((String e) => e.trim().toLowerCase())
        .where((String e) => e.contains('@'))
        .toSet()
        .toList();
  }
  return <String>[];
}

Set<String> _extractTrustedIds(Map<String, dynamic> data) {
  final dynamic raw = data['trustedContactIds'];
  if (raw is List) {
    return raw.whereType<String>().toSet();
  }
  return <String>{};
}

Future<Set<String>> _fetchUserIdsForEmails(List<String> emails) async {
  if (emails.isEmpty) {
    return <String>{};
  }
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final Set<String> userIds = <String>{};

  for (int i = 0; i < emails.length; i += 10) {
    final List<String> chunk = emails.sublist(
      i,
      i + 10 > emails.length ? emails.length : i + 10,
    );
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection('users')
        .where('email', whereIn: chunk)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      userIds.add(doc.id);
    }
  }
  return userIds;
}

Future<Set<String>> _fetchNearbyUserIds({
  required double originLat,
  required double originLng,
  required double radiusMiles,
}) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
      .collection('users')
      .where('locationTrackingEnabled', isEqualTo: true)
      .get();

  final Set<String> ids = <String>{};
  for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
    final Map<String, dynamic> data = doc.data();
    final num? lat = data['locationLat'] as num?;
    final num? lng = data['locationLng'] as num?;
    if (lat == null || lng == null) {
      continue;
    }
    final double meters = Geolocator.distanceBetween(
      originLat,
      originLng,
      lat.toDouble(),
      lng.toDouble(),
    );
    final double miles = meters / 1609.344;
    if (miles <= radiusMiles) {
      ids.add(doc.id);
    }
  }
  return ids;
}

String? _buildSituationLabel({
  required EmergencySituation? selectedSituation,
  required String customSituation,
}) {
  if (selectedSituation == null) {
    return null;
  }
  if (selectedSituation == EmergencySituation.feelingUnsafe) {
    return 'Feeling unsafe';
  }
  if (selectedSituation == EmergencySituation.beingTracked) {
    return 'Being tracked';
  }
  if (customSituation.trim().isNotEmpty) {
    return customSituation.trim();
  }
  return null;
}

String _audienceLabel(EmergencyAudience audience) {
  switch (audience) {
    case EmergencyAudience.personalFriends:
      return 'personal_friends';
    case EmergencyAudience.nearbyFriends:
      return 'nearby_friends';
    case EmergencyAudience.both:
      return 'both';
  }
}
