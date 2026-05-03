import 'package:blue_light/profile.dart';
import 'package:blue_light/services/friend_service.dart';
import 'package:blue_light/ui/emergency_alerts.dart';
import 'package:blue_light/ui/shell_chrome.dart';
import 'package:blue_light/ui/user_profile_preview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:blue_light/utils/user_display.dart';

class MyAddFriendsPage extends StatefulWidget {
  const MyAddFriendsPage({super.key, required this.title});

  final String title;

  @override
  State<MyAddFriendsPage> createState() => _MyAddFriendsPageState();
}

class _MyAddFriendsPageState extends State<MyAddFriendsPage> {
  final FriendService _friendService = FriendService();
  bool _showAllRequests = false;
  String _discoverQuery = '';
  final Set<String> _busyUserIds = <String>{};

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlueLightTopBar(
        title: 'Discover',
        onProfileTap: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) =>
                  const MyProfilePage(title: 'Profile'),
            ),
          );
        },
        onEmergencyTap: () {
          showEmergencyAlertDialog(context);
        },
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            children: <Widget>[
              _friendRequestsCard(),
              const SizedBox(height: 22),
              _discoverPeopleCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _friendRequestsCard() {
    final User? user = _currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final Stream<QuerySnapshot<Map<String, dynamic>>> requestsStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('incoming_friend_requests')
            .orderBy('createdAt', descending: true)
            .snapshots();

    return Stack(
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 20),
          padding: const EdgeInsets.fromLTRB(12, 28, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: requestsStream,
            builder:
                (
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
                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  requests =
                      snapshot.data?.docs ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  if (requests.isEmpty) {
                    return const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text('No friend requests right now.'),
                      ),
                    );
                  }

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  visible = _showAllRequests
                      ? requests
                      : requests.take(3).toList();

                  return ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 120),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visible.length,
                            itemBuilder: (BuildContext context, int index) {
                              final QueryDocumentSnapshot<Map<String, dynamic>>
                              request = visible[index];
                              return _friendRequestRow(request);
                            },
                          ),
                        ),
                        if (requests.length > 3)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showAllRequests = !_showAllRequests;
                                });
                              },
                              child: Text(
                                _showAllRequests ? 'Show less' : 'See all',
                                style: const TextStyle(
                                  color: Colors.lightBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                'Friend Requests',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _friendRequestRow(
    QueryDocumentSnapshot<Map<String, dynamic>> requestDoc,
  ) {
    final Map<String, dynamic> data = requestDoc.data();
    final String fromUserId = requestDoc.id;
    final String fallbackName =
        (data['fromUsername'] as String?)?.trim().isNotEmpty == true
        ? (data['fromUsername'] as String).trim()
        : 'User';
    final String fallbackPhoto =
        (data['fromPhotoUrl'] as String?)?.trim() ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> userSnapshot,
          ) {
            final Map<String, dynamic> userData =
                userSnapshot.data?.data() ?? <String, dynamic>{};
            final String name =
                (userData['username'] as String?)?.trim().isNotEmpty == true
                ? (userData['username'] as String).trim()
                : fallbackName.trim().isNotEmpty
                ? fallbackName
                : resolveDisplayName(userData, userId: fromUserId);
            final String photo =
                (userData['photoUrl'] as String?)?.trim().isNotEmpty == true
                ? (userData['photoUrl'] as String).trim()
                : fallbackPhoto;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  GestureDetector(
                    onTap: () async {
                      try {
                        await showUserProfilePreviewDialog(
                          context: context,
                          targetUserId: fromUserId,
                          fallbackUsername: name,
                          fallbackPhotoUrl: photo,
                        );
                      } catch (_) {}
                    },
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: photo.isNotEmpty
                          ? NetworkImage(photo)
                          : null,
                      backgroundColor: Colors.grey.shade200,
                      child: photo.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<int>(
                      future: _mutualCountWith(fromUserId),
                      builder:
                          (BuildContext context, AsyncSnapshot<int> snapshot) {
                            final int mutualCount = snapshot.data ?? 0;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  name,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$mutualCount mutuals',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 90,
                        height: 34,
                        child: ElevatedButton(
                          onPressed: _isUserBusy(fromUserId)
                              ? null
                              : () async {
                                  await _runFriendActionForUser(fromUserId, () {
                                    return _friendService.acceptFriendRequest(
                                      fromUserId: fromUserId,
                                    );
                                  });
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.add, size: 14),
                              SizedBox(width: 3),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 94,
                        height: 34,
                        child: OutlinedButton(
                          onPressed: _isUserBusy(fromUserId)
                              ? null
                              : () async {
                                  await _runFriendActionForUser(fromUserId, () {
                                    return _friendService.declineFriendRequest(
                                      fromUserId: fromUserId,
                                    );
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Delete',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
    );
  }

  Widget _discoverPeopleCard() {
    final User? user = _currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final Stream<DocumentSnapshot<Map<String, dynamic>>> meStream =
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots();
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
          padding: const EdgeInsets.fromLTRB(14, 30, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: <Widget>[
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD9EAFB)),
                ),
                child: TextField(
                  onChanged: (String value) {
                    setState(() {
                      _discoverQuery = value;
                    });
                  },
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search_rounded),
                    hintText: 'Search people by username',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: meStream,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                      meSnap,
                    ) {
                      if (meSnap.hasError) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'Could not load your profile data right now.',
                          ),
                        );
                      }
                      final Set<String> myFriendIds =
                          ((meSnap.data?.data()?['friendIds'] as List?) ??
                                  <dynamic>[])
                              .whereType<String>()
                              .toSet();

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: incomingStream,
                        builder:
                            (
                              BuildContext context,
                              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                              incomingSnap,
                            ) {
                              if (incomingSnap.hasError) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Text(
                                    'Could not load incoming requests right now.',
                                  ),
                                );
                              }
                              final Set<String> incomingIds =
                                  (incomingSnap.data?.docs ??
                                          <
                                            QueryDocumentSnapshot<
                                              Map<String, dynamic>
                                            >
                                          >[])
                                      .map(
                                        (
                                          QueryDocumentSnapshot<
                                            Map<String, dynamic>
                                          >
                                          d,
                                        ) => d.id,
                                      )
                                      .toSet();

                              return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: outgoingStream,
                                builder:
                                    (
                                      BuildContext context,
                                      AsyncSnapshot<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >
                                      outgoingSnap,
                                    ) {
                                      if (outgoingSnap.hasError) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          child: Text(
                                            'Could not load outgoing requests right now.',
                                          ),
                                        );
                                      }
                                      final Set<String> outgoingIds =
                                          (outgoingSnap.data?.docs ??
                                                  <
                                                    QueryDocumentSnapshot<
                                                      Map<String, dynamic>
                                                    >
                                                  >[])
                                              .map((
                                                QueryDocumentSnapshot<
                                                  Map<String, dynamic>
                                                >
                                                d,
                                              ) {
                                                final Map<String, dynamic>
                                                data = d.data();
                                                return (data['toUserId']
                                                            as String?)
                                                        ?.trim() ??
                                                    d.id;
                                              })
                                              .where(
                                                (String id) => id.isNotEmpty,
                                              )
                                              .toSet();

                                      return StreamBuilder<
                                        QuerySnapshot<Map<String, dynamic>>
                                      >(
                                        stream: usersStream,
                                        builder:
                                            (
                                              BuildContext context,
                                              AsyncSnapshot<
                                                QuerySnapshot<
                                                  Map<String, dynamic>
                                                >
                                              >
                                              usersSnap,
                                            ) {
                                              if (usersSnap.hasError) {
                                                return const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 18,
                                                  ),
                                                  child: Text(
                                                    'Could not load users right now. Check Firestore rules and connection.',
                                                  ),
                                                );
                                              }
                                              if (usersSnap.connectionState ==
                                                      ConnectionState.waiting &&
                                                  !usersSnap.hasData) {
                                                return const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 24,
                                                  ),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                );
                                              }

                                              final List<_DiscoverUser>
                                              discoverUsers =
                                                  _buildDiscoverUsers(
                                                    users:
                                                        usersSnap.data?.docs ??
                                                        <
                                                          QueryDocumentSnapshot<
                                                            Map<String, dynamic>
                                                          >
                                                        >[],
                                                    currentUserId: user.uid,
                                                    myFriendIds: myFriendIds,
                                                    incomingIds: incomingIds,
                                                    outgoingIds: outgoingIds,
                                                  );

                                              if (discoverUsers.isEmpty) {
                                                return const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 18,
                                                  ),
                                                  child: Text(
                                                    'No matching users found.',
                                                  ),
                                                );
                                              }

                                              return ListView.builder(
                                                shrinkWrap: true,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                itemCount:
                                                    discoverUsers.length > 12
                                                    ? 12
                                                    : discoverUsers.length,
                                                itemBuilder:
                                                    (
                                                      BuildContext context,
                                                      int index,
                                                    ) {
                                                      final _DiscoverUser
                                                      person =
                                                          discoverUsers[index];
                                                      return _discoverUserRow(
                                                        person,
                                                      );
                                                    },
                                              );
                                            },
                                      );
                                    },
                              );
                            },
                      );
                    },
              ),
            ],
          ),
        ),
        const Positioned(
          left: 20,
          child: ColoredBox(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Find New Friends',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _discoverUserRow(_DiscoverUser person) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3EEF9)),
      ),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: () async {
              try {
                await showUserProfilePreviewDialog(
                  context: context,
                  targetUserId: person.uid,
                  fallbackUsername: person.username,
                  fallbackPhotoUrl: person.photoUrl,
                );
              } catch (_) {}
            },
            child: CircleAvatar(
              radius: 22,
              backgroundImage: person.photoUrl.isNotEmpty
                  ? NetworkImage(person.photoUrl)
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: person.photoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  person.username,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${person.mutualCount} mutuals',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 104,
            height: 34,
            child: person.buttonState == _DiscoverButtonState.add
                ? ElevatedButton(
                    onPressed: _isUserBusy(person.uid)
                        ? null
                        : () async {
                            await _runFriendActionForUser(person.uid, () {
                              return _friendService.sendFriendRequest(
                                toUserId: person.uid,
                              );
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.add, size: 14),
                        SizedBox(width: 3),
                        Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                : person.buttonState == _DiscoverButtonState.received
                ? ElevatedButton(
                    onPressed: _isUserBusy(person.uid)
                        ? null
                        : () async {
                            await _runFriendActionForUser(person.uid, () {
                              return _friendService.acceptFriendRequest(
                                fromUserId: person.uid,
                              );
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Accept',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed:
                        person.buttonState == _DiscoverButtonState.sent &&
                            !_isUserBusy(person.uid)
                        ? () async {
                            await _runFriendActionForUser(person.uid, () {
                              return _friendService.cancelFriendRequest(
                                toUserId: person.uid,
                              );
                            });
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color:
                            person.buttonState == _DiscoverButtonState.friends
                            ? Colors.green.shade400
                            : Colors.grey.shade400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      person.buttonState == _DiscoverButtonState.friends
                          ? 'Friends'
                          : 'Requested',
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: TextStyle(
                        color:
                            person.buttonState == _DiscoverButtonState.friends
                            ? Colors.green.shade700
                            : person.buttonState == _DiscoverButtonState.sent
                            ? const Color(0xFF1E9CEB)
                            : Colors.grey.shade700,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<_DiscoverUser> _buildDiscoverUsers({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required String currentUserId,
    required Set<String> myFriendIds,
    required Set<String> incomingIds,
    required Set<String> outgoingIds,
  }) {
    final String query = _discoverQuery.trim().toLowerCase();
    final List<_DiscoverUser> people = <_DiscoverUser>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in users) {
      final String uid = doc.id;
      if (uid == currentUserId) {
        continue;
      }
      if (myFriendIds.contains(uid)) {
        continue;
      }
      final Map<String, dynamic> data = doc.data();
      final String username = resolveDisplayName(data, userId: uid);
      if (query.isNotEmpty && !username.toLowerCase().contains(query)) {
        continue;
      }
      final Set<String> candidateFriends =
          ((data['friendIds'] as List?) ?? <dynamic>[])
              .whereType<String>()
              .toSet();
      final int mutualCount = candidateFriends.intersection(myFriendIds).length;
      final String photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';

      final _DiscoverButtonState state;
      if (incomingIds.contains(uid)) {
        state = _DiscoverButtonState.received;
      } else if (outgoingIds.contains(uid)) {
        state = _DiscoverButtonState.sent;
      } else {
        state = _DiscoverButtonState.add;
      }

      people.add(
        _DiscoverUser(
          uid: uid,
          username: username,
          photoUrl: photoUrl,
          mutualCount: mutualCount,
          buttonState: state,
        ),
      );
    }

    people.sort((_DiscoverUser a, _DiscoverUser b) {
      final int byMutual = b.mutualCount.compareTo(a.mutualCount);
      if (byMutual != 0) {
        return byMutual;
      }
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });

    return people;
  }

  Future<int> _mutualCountWith(String otherUserId) async {
    final User? user = _currentUser;
    if (user == null) {
      return 0;
    }
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentSnapshot<Map<String, dynamic>> meSnap = await firestore
        .collection('users')
        .doc(user.uid)
        .get();
    final DocumentSnapshot<Map<String, dynamic>> otherSnap = await firestore
        .collection('users')
        .doc(otherUserId)
        .get();
    final Set<String> myFriendIds =
        ((meSnap.data()?['friendIds'] as List?) ?? <dynamic>[])
            .whereType<String>()
            .toSet();
    final Set<String> otherFriendIds =
        ((otherSnap.data()?['friendIds'] as List?) ?? <dynamic>[])
            .whereType<String>()
            .toSet();
    return myFriendIds.intersection(otherFriendIds).length;
  }

  bool _isUserBusy(String userId) {
    return _busyUserIds.contains(userId);
  }

  Future<void> _runFriendActionForUser(
    String userId,
    Future<void> Function() action,
  ) async {
    if (_isUserBusy(userId)) {
      return;
    }
    setState(() {
      _busyUserIds.add(userId);
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
          _busyUserIds.remove(userId);
        });
      }
    }
  }
}

enum _DiscoverButtonState { add, sent, received, friends }

class _DiscoverUser {
  const _DiscoverUser({
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
  final _DiscoverButtonState buttonState;
}
