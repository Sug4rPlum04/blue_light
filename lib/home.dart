import 'package:flutter/material.dart';
import 'package:blue_light/friends.dart';
import 'package:blue_light/message.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blue_light/ui/emergency_alerts.dart';
import 'package:blue_light/services/friend_service.dart';
import 'package:blue_light/ui/shell_chrome.dart';
import 'package:blue_light/ui/user_profile_preview.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final List<String> _fallbackActivityLogs =
      List.generate(5, (int i) => "Activity log ${i + 1}");
  final FriendService _friendService = FriendService();
  final Set<String> _suggestionBusyUserIds = <String>{};

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: BlueLightTopBar(
        title: widget.title,
        onProfileTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
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
        currentIndex: 0,
        onTap: (int index) {
          if (index == 0) {
            return;
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => const MyMapPage(title: "Map"),
              ),
            );
            return;
          }
          if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) =>
                    const MyMessagePage(title: "Messages"),
              ),
            );
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) =>
                  const MyFriendsPage(title: "Friends"),
            ),
          );
        },
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _nearbyFriendsCard(),
              const SizedBox(height: 20),

              _activityCard(),
              const SizedBox(height: 20),
              _suggestedFriendsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityCard() {
    final User? user = FirebaseAuth.instance.currentUser;
    final Stream<QuerySnapshot<Map<String, dynamic>>>? activityStream =
        user == null
            ? null
            : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('activity')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots();

    return Stack(
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: activityStream == null
              ? _buildFallbackActivityList()
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: activityStream,
                  builder: (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                        snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                    if (docs.isEmpty) {
                      return _buildFallbackActivityList();
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemBuilder: (BuildContext context, int index) {
                        final QueryDocumentSnapshot<Map<String, dynamic>> doc =
                            docs[index];
                        final Map<String, dynamic> data = doc.data();
                        return Dismissible(
                          key: ValueKey<String>(doc.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            doc.reference.delete();
                          },
                          child: _buildActivityContent(doc, data),
                        );
                      },
                    );
                  },
                ),
        ),
        const Positioned(
          left: 20,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Activity",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackActivityList() {
    return ListView.builder(
      itemCount: _fallbackActivityLogs.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        return _activityTile(_fallbackActivityLogs[index]);
      },
    );
  }

  Widget _activityTile(
    String text, {
    IconData icon = Icons.notifications,
    Color iconColor = Colors.blue,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    bool isUrgent = false,
  }) {
    final Widget tileContent = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFFECEC) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(15),
        border: isUrgent
            ? Border.all(color: const Color(0xFFFFC9C9))
            : null,
      ),
      child: Row(
        children: <Widget>[
          leading ?? Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w400,
                color: isUrgent ? const Color(0xFF921B1B) : null,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing,
          ],
          if (isUrgent) ...<Widget>[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD32F2F),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return tileContent;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: tileContent,
    );
  }

  Widget _activityAvatar(String photoUrl) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: const Color(0xFFE3EDF8),
      backgroundImage: photoUrl.trim().isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.trim().isNotEmpty
          ? null
          : const Icon(
              Icons.person_rounded,
              size: 16,
              color: Color(0xFF0C8AE8),
            ),
    );
  }

  Widget _buildActivityContent(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic> data,
  ) {
    final String type = (data['type'] as String?) ?? '';
    final String fallbackText = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : (data['message'] as String?) ?? 'You have a new activity update.';
    final String? fromUserId = (data['fromUserId'] as String?)?.trim().isNotEmpty ==
            true
        ? (data['fromUserId'] as String).trim()
        : null;

    if (fromUserId == null ||
        !(type == 'friend_request' ||
            type == 'friend_request_accepted' ||
            type == 'emergency_alert')) {
      return _activityTile(
        fallbackText,
        icon: Icons.notifications,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .snapshots(),
      builder: (
        BuildContext context,
        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> userSnapshot,
      ) {
        final Map<String, dynamic> userData =
            userSnapshot.data?.data() ?? <String, dynamic>{};
        final String liveName =
            (userData['username'] as String?)?.trim().isNotEmpty == true
                ? (userData['username'] as String).trim()
                : ((data['fromUsername'] as String?)?.trim().isNotEmpty == true
                    ? (data['fromUsername'] as String).trim()
                    : 'User');
        final String livePhoto =
            (userData['photoUrl'] as String?)?.trim().isNotEmpty == true
                ? (userData['photoUrl'] as String).trim()
                : ((data['fromPhotoUrl'] as String?)?.trim() ?? '');

        final String text = type == 'friend_request'
            ? '$liveName has sent you a friend request.'
            : type == 'friend_request_accepted'
                ? '$liveName has accepted your friend request.'
                : (data['situation'] as String?)?.trim().isNotEmpty == true
                    ? '$liveName SOS: ${((data['situation'] as String).trim()).toUpperCase()}.'
                    : '$liveName sent an SOS alert.';

        return _activityTile(
          text,
          icon: type == 'friend_request'
              ? Icons.person_add_alt_1_rounded
              : type == 'emergency_alert'
                  ? Icons.warning_amber_rounded
                  : Icons.verified_rounded,
          iconColor: type == 'friend_request'
              ? const Color(0xFF0C8AE8)
              : type == 'emergency_alert'
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF2E7D32),
          leading: type == 'friend_request'
              ? GestureDetector(
                  onTap: () async {
                    try {
                      await showUserProfilePreviewDialog(
                        context: context,
                        targetUserId: fromUserId,
                        fallbackUsername: liveName,
                        fallbackPhotoUrl: livePhoto,
                      );
                    } catch (_) {}
                  },
                  child: _activityAvatar(livePhoto),
                )
              : null,
          trailing: type == 'friend_request'
              ? SizedBox(
                  width: 84,
                  height: 32,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await _friendService.acceptFriendRequest(
                          fromUserId: fromUserId,
                          activityDocIdToDelete: doc.id,
                        );
                      } catch (e) {
                        if (!mounted) {
                          return;
                        }
                        showBlueLightToast(
                          context,
                          e.toString().replaceFirst('Exception: ', ''),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E9CEB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 0),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : null,
          onTap: type == 'emergency_alert'
              ? () {
                  _showEmergencyAlertDetails(data);
                }
              : null,
          isUrgent: type == 'emergency_alert',
        );
      },
    );
  }

  Future<void> _showEmergencyAlertDetails(Map<String, dynamic> data) async {
    final String fromUserId = (data['fromUserId'] as String?)?.trim() ?? '';
    String fromUsername = (data['fromUsername'] as String?)?.trim() ?? '';
    String fromPhotoUrl = (data['fromPhotoUrl'] as String?)?.trim() ?? '';
    if (fromUsername.isEmpty) {
      if (fromUserId.isNotEmpty) {
        try {
          final DocumentSnapshot<Map<String, dynamic>> fromSnap =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(fromUserId)
                  .get();
          final Map<String, dynamic> fromData =
              fromSnap.data() ?? <String, dynamic>{};
          fromUsername = (fromData['username'] as String?)?.trim() ?? '';
          if (fromPhotoUrl.isEmpty) {
            fromPhotoUrl = (fromData['photoUrl'] as String?)?.trim() ?? '';
          }
        } catch (_) {}
      }
    }
    if (fromUsername.isEmpty) {
      fromUsername = 'Unknown user';
    }
    final String situation = (data['situation'] as String?)?.trim().isNotEmpty == true
        ? (data['situation'] as String).trim()
        : 'Not specified';
    final String audienceRaw = (data['audienceDisplay'] as String?)?.trim().isNotEmpty ==
            true
        ? (data['audienceDisplay'] as String).trim()
        : _humanAudience((data['audience'] as String?)?.trim() ?? '');
    final String audience = audienceRaw.replaceAll(' (trusted contacts)', '');
    final String location = _formatAlertLocation(data);
    final double? alertLat = (data['fromLocationLat'] as num?)?.toDouble();
    final double? alertLng = (data['fromLocationLng'] as num?)?.toDouble();
    final bool hasAlertLocation = alertLat != null && alertLng != null;
    final int? level = (data['emergencyLevel'] as num?)?.toInt();
    final String timeAndDate = _formatActivityTime(data['createdAt']);

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFE8E8), Color(0xFFFFF4E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFC9C9)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Stack(
                children: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[Color(0xFFE53935), Color(0xFFBF1D1D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'ALERT DETAILS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _detailRow('FROM', fromUsername),
                      _detailRow('SENT TO', audience),
                      _detailRow('TIME & DATE', timeAndDate),
                      _detailRow('SITUATION', situation),
                      _detailRow('LOCATION', location),
                      _detailRow(
                        'EMERGENCY LEVEL',
                        level == null ? 'Not provided' : '$level / 5',
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: fromUserId.isNotEmpty
                                    ? () {
                                        Navigator.of(dialogContext).pop();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<ChatThreadPage>(
                                            builder: (BuildContext context) =>
                                                ChatThreadPage(
                                              peerUserId: fromUserId,
                                              peerUsername: fromUsername,
                                              peerPhotoUrl: fromPhotoUrl,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E9CEB),
                                  disabledBackgroundColor:
                                      const Color(0xFF9FB7CC),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white70,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Icons.mark_unread_chat_alt_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Message',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: hasAlertLocation
                                    ? () async {
                                        Navigator.of(dialogContext).pop();
                                        await _openRouteToAlertLocation(
                                          latitude: alertLat,
                                          longitude: alertLng,
                                        );
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF176EC2),
                                  disabledBackgroundColor:
                                      const Color(0xFF9FB7CC),
                                  foregroundColor: Colors.white,
                                  disabledForegroundColor: Colors.white70,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Icons.route_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Get Location',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
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
                    ],
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.close, color: Color(0xFFB71C1C)),
                      splashRadius: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    String? secondaryLabel,
    String? secondaryValue,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFDADA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB71C1C),
              letterSpacing: 0.25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3A45),
            ),
          ),
          if (secondaryLabel != null &&
              secondaryLabel.trim().isNotEmpty &&
              secondaryValue != null &&
              secondaryValue.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              secondaryLabel,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFB71C1C),
                letterSpacing: 0.25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              secondaryValue,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3A45),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _humanAudience(String rawAudience) {
    switch (rawAudience) {
      case 'personal_friends':
        return 'Personal friends (trusted contacts)';
      case 'nearby_friends':
        return 'Friends within distance';
      case 'both':
        return 'Both trusted contacts and nearby friends';
      default:
        return 'Not specified';
    }
  }

  String _formatActivityTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final DateTime local = createdAt.toDate().toLocal();
      final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final String minute = local.minute.toString().padLeft(2, '0');
      final String meridiem = local.hour >= 12 ? 'PM' : 'AM';
      final String month = local.month.toString().padLeft(2, '0');
      final String day = local.day.toString().padLeft(2, '0');
      final String year = local.year.toString();
      return '$month/$day/$year at $hour12:$minute $meridiem';
    }
    return 'Not available';
  }

  String _formatAlertLocation(Map<String, dynamic> data) {
    final num? lat = data['fromLocationLat'] as num?;
    final num? lng = data['fromLocationLng'] as num?;
    if (lat == null || lng == null) {
      return 'Not available';
    }
    final double latValue = lat.toDouble();
    final double lngValue = lng.toDouble();
    final String latText =
        '${latValue.abs().toStringAsFixed(5)}${latValue >= 0 ? 'N' : 'S'}';
    final String lngText =
        '${lngValue.abs().toStringAsFixed(5)}${lngValue >= 0 ? 'E' : 'W'}';
    return '$latText, $lngText';
  }

  Future<void> _openRouteToAlertLocation({
    required double? latitude,
    required double? longitude,
  }) async {
    if (latitude == null || longitude == null) {
      if (!mounted) return;
      showBlueLightToast(context, 'Alert location is not available.');
      return;
    }
    final String latLng = '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
    final List<Uri> navigationUris = <Uri>[
      Uri.parse('google.navigation:q=$latLng&mode=d'),
      Uri.parse('geo:$latLng?q=$latLng'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latLng&travelmode=driving',
      ),
    ];

    try {
      for (final Uri uri in navigationUris) {
        final bool canLaunch = await canLaunchUrl(uri);
        if (!canLaunch) {
          continue;
        }
        final bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return;
        }
      }
      if (!mounted) return;
      showBlueLightToast(
        context,
        'No map app/browser available to open directions.',
      );
    } catch (_) {
      if (!mounted) return;
      showBlueLightToast(
        context,
        'Could not open navigation right now.',
      );
    }
  }

  // rounded rectangle nearby friends card
  Widget _nearbyFriendsCard() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final Stream<DocumentSnapshot<Map<String, dynamic>>> meStream =
        FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
    final Stream<QuerySnapshot<Map<String, dynamic>>> usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();

    return Stack(
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCEBFA)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),

          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: meStream,
            builder: (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> meSnap,
            ) {
              final Map<String, dynamic> myData =
                  meSnap.data?.data() ?? <String, dynamic>{};
              final Set<String> myFriendIds =
                  ((myData['friendIds'] as List?) ?? <dynamic>[])
                      .whereType<String>()
                      .toSet();
              final double radiusMiles =
                  (myData['nearbyAlertRadiusMiles'] as num?)?.toDouble() ?? 5.0;
              final num? myLat = myData['locationLat'] as num?;
              final num? myLng = myData['locationLng'] as num?;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: usersStream,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> usersSnap,
                ) {
                  if (usersSnap.connectionState == ConnectionState.waiting &&
                      !usersSnap.hasData) {
                    return const SizedBox(
                      height: 92,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final List<_NearbyFriendItem> nearby = _buildNearbyFriends(
                    users: usersSnap.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                    myFriendIds: myFriendIds,
                    myLat: myLat?.toDouble(),
                    myLng: myLng?.toDouble(),
                    radiusMiles: radiusMiles,
                  );

                  if (nearby.isEmpty) {
                    return SizedBox(
                      height: 82,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.location_searching_rounded,
                              size: 20,
                              color: Colors.blueGrey.shade300,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No friends nearby right now.',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: nearby.length > 7 ? 7 : nearby.length,
                      itemBuilder: (BuildContext context, int index) {
                        final _NearbyFriendItem friend = nearby[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _friendTile(
                            name: friend.name,
                            milesText: '${friend.distanceMiles.toStringAsFixed(1)} mi',
                            photoUrl: friend.photoUrl,
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Nearby friends title overlap
        const Positioned(
          left: 20,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Nearby Friends",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // friend tile (avatar, name, n miles)
  Widget _friendTile({
    required String name,
    required String milesText,
    required String photoUrl,
  }) {
    return Container(
      width: 112,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFF5FAFF), Color(0xFFEAF4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFD8EAFB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x142E77BE),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD6EAFE),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundImage: photoUrl.trim().isNotEmpty
                  ? NetworkImage(photoUrl)
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: photoUrl.trim().isNotEmpty
                  ? null
                  : const Icon(Icons.person_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            milesText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blueGrey.shade600,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // suggested friends card
  Widget _suggestedFriendsCard() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final Stream<DocumentSnapshot<Map<String, dynamic>>> meStream =
        FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();
    final Stream<QuerySnapshot<Map<String, dynamic>>> incomingStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('incoming_friend_requests')
            .snapshots();
    final Stream<QuerySnapshot<Map<String, dynamic>>> outgoingStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('outgoing_friend_requests')
            .snapshots();
    final Stream<QuerySnapshot<Map<String, dynamic>>> usersStream =
        FirebaseFirestore.instance.collection('users').snapshots();

    return Stack(
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: meStream,
            builder: (
              BuildContext context,
              AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> meSnap,
            ) {
              final Set<String> myFriendIds =
                  ((meSnap.data?.data()?['friendIds'] as List?) ?? <dynamic>[])
                      .whereType<String>()
                      .toSet();
              final Set<String> dismissedSuggestionIds =
                  ((meSnap.data?.data()?['dismissedSuggestionIds'] as List?) ??
                          <dynamic>[])
                      .whereType<String>()
                      .toSet();

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: incomingStream,
                builder: (
                  BuildContext context,
                  AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> incomingSnap,
                ) {
                  final Set<String> incomingIds = (incomingSnap.data?.docs ??
                          <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                      .map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.id)
                      .toSet();

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: outgoingStream,
                    builder: (
                      BuildContext context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                          outgoingSnap,
                    ) {
                      final Set<String> outgoingIds = (outgoingSnap.data?.docs ??
                              <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) {
                        final Map<String, dynamic> data = d.data();
                        return (data['toUserId'] as String?)?.trim() ?? d.id;
                      }).where((String id) => id.isNotEmpty).toSet();

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: usersStream,
                        builder: (
                          BuildContext context,
                          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                              usersSnap,
                        ) {
                          if (usersSnap.connectionState == ConnectionState.waiting &&
                              !usersSnap.hasData) {
                            return const SizedBox(
                              height: 92,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final List<_SuggestedUserItem> suggestions =
                              _buildSuggestedUsers(
                            users: usersSnap.data?.docs ??
                                <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                            currentUserId: user.uid,
                            myFriendIds: myFriendIds,
                            incomingIds: incomingIds,
                            outgoingIds: outgoingIds,
                            dismissedSuggestionIds: dismissedSuggestionIds,
                          );

                          if (suggestions.isEmpty) {
                            return const SizedBox(
                              height: 82,
                              child: Center(
                                child: Text('No suggested friends right now.'),
                              ),
                            );
                          }

                          return SizedBox(
                            height: 188,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: suggestions.length > 10
                                  ? 10
                                  : suggestions.length,
                              itemBuilder: (BuildContext context, int index) {
                                final _SuggestedUserItem suggestion =
                                    suggestions[index];
                                return Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: _suggestedFriendTile(
                                    currentUserId: user.uid,
                                    suggestion: suggestion,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        const Positioned(
          left: 20,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                "Suggested for you",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  // suggested tile (avatar, name, mutuals)
  Widget _suggestedFriendTile({
    required String currentUserId,
    required _SuggestedUserItem suggestion,
  }) {
    final bool isBusy = _suggestionBusyUserIds.contains(suggestion.uid);
    return Container(
      width: 156,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: <Widget>[
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              GestureDetector(
                onTap: () async {
                  try {
                    await showUserProfilePreviewDialog(
                      context: context,
                      targetUserId: suggestion.uid,
                      fallbackUsername: suggestion.username,
                      fallbackPhotoUrl: suggestion.photoUrl,
                    );
                  } catch (_) {}
                },
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: suggestion.photoUrl.isNotEmpty
                      ? NetworkImage(suggestion.photoUrl)
                      : null,
                  backgroundColor: Colors.grey.shade200,
                  child: suggestion.photoUrl.isNotEmpty
                      ? null
                      : const Icon(Icons.person, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  suggestion.username,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${suggestion.mutualCount} mutuals',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 108,
                height: 30,
                child: suggestion.buttonState == _SuggestedButtonState.add
                    ? ElevatedButton(
                        onPressed: isBusy
                            ? null
                            : () async {
                                await _runSuggestionAction(
                                  suggestion.uid,
                                  () => _friendService.sendFriendRequest(
                                    toUserId: suggestion.uid,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(Icons.add, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : suggestion.buttonState == _SuggestedButtonState.received
                        ? ElevatedButton(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    await _runSuggestionAction(
                                      suggestion.uid,
                                      () => _friendService.acceptFriendRequest(
                                        fromUserId: suggestion.uid,
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.lightBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    await _runSuggestionAction(
                                      suggestion.uid,
                                      () => _friendService.cancelFriendRequest(
                                        toUserId: suggestion.uid,
                                      ),
                                    );
                                  },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF1E9CEB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Requested',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 10.4,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E9CEB),
                              ),
                            ),
                          ),
              ),
            ],
          ),
          Positioned(
            top: 2,
            right: 4,
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                splashRadius: 14,
                onPressed: () async {
                  await _dismissSuggestedUser(currentUserId, suggestion.uid);
                },
                icon: const Icon(
                  Icons.close_rounded,
                  size: 15,
                  color: Color(0xFF4D5A67),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_NearbyFriendItem> _buildNearbyFriends({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required Set<String> myFriendIds,
    required double? myLat,
    required double? myLng,
    required double radiusMiles,
  }) {
    if (myFriendIds.isEmpty || myLat == null || myLng == null) {
      return <_NearbyFriendItem>[];
    }

    final List<_NearbyFriendItem> nearby = <_NearbyFriendItem>[];
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in users) {
      if (!myFriendIds.contains(doc.id)) {
        continue;
      }
      final Map<String, dynamic> data = doc.data();
      final bool trackingEnabled =
          (data['locationTrackingEnabled'] as bool?) ?? true;
      if (!trackingEnabled) {
        continue;
      }
      final num? lat = data['locationLat'] as num?;
      final num? lng = data['locationLng'] as num?;
      if (lat == null || lng == null) {
        continue;
      }

      final double meters = Geolocator.distanceBetween(
        myLat,
        myLng,
        lat.toDouble(),
        lng.toDouble(),
      );
      final double miles = meters / 1609.344;
      if (miles > radiusMiles) {
        continue;
      }

      final String name = (data['username'] as String?)?.trim().isNotEmpty == true
          ? (data['username'] as String).trim()
          : ((data['email'] as String?)?.split('@').first ?? 'User');
      final String photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';

      nearby.add(
        _NearbyFriendItem(
          uid: doc.id,
          name: name,
          photoUrl: photoUrl,
          distanceMiles: miles,
        ),
      );
    }

    nearby.sort(
      (_NearbyFriendItem a, _NearbyFriendItem b) =>
          a.distanceMiles.compareTo(b.distanceMiles),
    );
    return nearby;
  }

  List<_SuggestedUserItem> _buildSuggestedUsers({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required String currentUserId,
    required Set<String> myFriendIds,
    required Set<String> incomingIds,
    required Set<String> outgoingIds,
    required Set<String> dismissedSuggestionIds,
  }) {
    final List<_SuggestedUserItem> suggestions = <_SuggestedUserItem>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in users) {
      final String uid = doc.id;
      if (uid == currentUserId ||
          myFriendIds.contains(uid) ||
          dismissedSuggestionIds.contains(uid)) {
        continue;
      }

      final Map<String, dynamic> data = doc.data();
      final String username = (data['username'] as String?)?.trim().isNotEmpty == true
          ? (data['username'] as String).trim()
          : ((data['email'] as String?)?.split('@').first ?? 'User');
      final String photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
      final Set<String> otherFriendIds =
          ((data['friendIds'] as List?) ?? <dynamic>[])
              .whereType<String>()
              .toSet();
      final int mutualCount = otherFriendIds.intersection(myFriendIds).length;

      final _SuggestedButtonState buttonState;
      if (incomingIds.contains(uid)) {
        buttonState = _SuggestedButtonState.received;
      } else if (outgoingIds.contains(uid)) {
        buttonState = _SuggestedButtonState.requested;
      } else {
        buttonState = _SuggestedButtonState.add;
      }

      suggestions.add(
        _SuggestedUserItem(
          uid: uid,
          username: username,
          photoUrl: photoUrl,
          mutualCount: mutualCount,
          buttonState: buttonState,
        ),
      );
    }

    suggestions.sort((_SuggestedUserItem a, _SuggestedUserItem b) {
      final int byMutual = b.mutualCount.compareTo(a.mutualCount);
      if (byMutual != 0) {
        return byMutual;
      }
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });

    return suggestions;
  }

  Future<void> _dismissSuggestedUser(String currentUserId, String targetUserId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).set(
        <String, dynamic>{
          'dismissedSuggestionIds': FieldValue.arrayUnion(<String>[targetUserId]),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      showBlueLightToast(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _runSuggestionAction(
    String userId,
    Future<void> Function() action,
  ) async {
    if (_suggestionBusyUserIds.contains(userId)) {
      return;
    }
    setState(() {
      _suggestionBusyUserIds.add(userId);
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) {
        return;
      }
      showBlueLightToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _suggestionBusyUserIds.remove(userId);
        });
      }
    }
  }
}

enum _SuggestedButtonState {
  add,
  requested,
  received,
}

class _NearbyFriendItem {
  const _NearbyFriendItem({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.distanceMiles,
  });

  final String uid;
  final String name;
  final String photoUrl;
  final double distanceMiles;
}

class _SuggestedUserItem {
  const _SuggestedUserItem({
    required this.uid,
    required this.username,
    required this.photoUrl,
    required this.mutualCount,
    required this.buttonState,
  });

  final String uid;
  final String username;
  final String photoUrl;
  final int mutualCount;
  final _SuggestedButtonState buttonState;
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
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    ),
  );
}
