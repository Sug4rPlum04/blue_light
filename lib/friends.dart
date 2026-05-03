import 'package:blue_light/add_friend.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/message.dart';
import 'package:blue_light/profile.dart';
import 'package:blue_light/services/friend_service.dart';
import 'package:blue_light/ui/emergency_alerts.dart';
import 'package:blue_light/ui/user_profile_preview.dart';
import 'package:blue_light/ui/shell_chrome.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:blue_light/utils/user_display.dart';

class MyFriendsPage extends StatefulWidget {
  const MyFriendsPage({super.key, required this.title});

  final String title;

  @override
  State<MyFriendsPage> createState() => _MyFriendsPageState();
}

class _MyFriendsPageState extends State<MyFriendsPage> {
  final FriendService _friendService = FriendService();
  String _searchText = '';
  bool _busy = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final User? user = _currentUser;
    return Scaffold(
      appBar: BlueLightTopBar(
        title: widget.title,
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
      bottomNavigationBar: BlueLightBottomNav(
        currentIndex: 3,
        onTap: (int index) {
          if (index == 3) {
            return;
          }
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) =>
                    const MyHomePage(title: 'Home'),
              ),
            );
            return;
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) =>
                    const MyMapPage(title: 'Map'),
              ),
            );
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) =>
                  const MyMessagePage(title: 'Messages'),
            ),
          );
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    height: 45,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (String value) {
                        setState(() {
                          _searchText = value;
                        });
                      },
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search),
                        hintText: 'Search',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (BuildContext context) =>
                              const MyAddFriendsPage(title: 'Discover'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadiusGeometry.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.person_add),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: user == null
                  ? const Center(child: Text('Please sign in to view friends.'))
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<
                              DocumentSnapshot<Map<String, dynamic>>
                            >
                            snapshot,
                          ) {
                            if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'Could not load friends right now. Please try again.',
                                ),
                              );
                            }
                            final Set<String> friendIds =
                                ((snapshot.data?.data()?['friendIds']
                                            as List?) ??
                                        <dynamic>[])
                                    .whereType<String>()
                                    .toSet();
                            if (friendIds.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No friends yet. Add people to get started.',
                                ),
                              );
                            }
                            return FutureBuilder<List<_FriendItem>>(
                              future: _loadFriends(friendIds),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<List<_FriendItem>>
                                    listSnapshot,
                                  ) {
                                    if (listSnapshot.hasError) {
                                      return const Center(
                                        child: Text(
                                          'Could not load friend profiles right now.',
                                        ),
                                      );
                                    }
                                    if (listSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        !listSnapshot.hasData) {
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    final List<_FriendItem> allFriends =
                                        listSnapshot.data ?? <_FriendItem>[];
                                    final String query = _searchText
                                        .trim()
                                        .toLowerCase();
                                    final List<_FriendItem> filteredFriends =
                                        allFriends.where((_FriendItem item) {
                                          return query.isEmpty ||
                                              item.name.toLowerCase().contains(
                                                query,
                                              );
                                        }).toList();
                                    if (filteredFriends.isEmpty) {
                                      return const Center(
                                        child: Text('No matching friends.'),
                                      );
                                    }
                                    return ListView.builder(
                                      itemCount: filteredFriends.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final _FriendItem friend =
                                                filteredFriends[index];
                                            return _friendRow(friend);
                                          },
                                    );
                                  },
                            );
                          },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendRow(_FriendItem friend) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Container(
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
          children: <Widget>[
            GestureDetector(
              onTap: () async {
                try {
                  await showUserProfilePreviewDialog(
                    context: context,
                    targetUserId: friend.uid,
                    fallbackUsername: friend.name,
                    fallbackPhotoUrl: friend.photoUrl,
                  );
                } catch (_) {}
              },
              child: CircleAvatar(
                radius: 26,
                backgroundImage: friend.photoUrl.isNotEmpty
                    ? NetworkImage(friend.photoUrl)
                    : null,
                backgroundColor: Colors.grey.shade200,
                child: friend.photoUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                friend.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      _confirmRemove(friend);
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.lightBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.lightBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_FriendItem>> _loadFriends(Set<String> friendIds) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final List<_FriendItem> items = <_FriendItem>[];
    final List<String> ids = friendIds.toList();

    for (int i = 0; i < ids.length; i += 10) {
      final List<String> chunk = ids.sublist(
        i,
        i + 10 > ids.length ? ids.length : i + 10,
      );
      final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String name = resolveDisplayName(data, userId: doc.id);
        items.add(
          _FriendItem(
            uid: doc.id,
            name: name,
            photoUrl: (data['photoUrl'] as String?)?.trim() ?? '',
          ),
        );
      }
    }

    items.sort(
      (_FriendItem a, _FriendItem b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return items;
  }

  Future<void> _confirmRemove(_FriendItem friend) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFF6F6), Color(0xFFFFEBEB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFFFD4D4)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF1E9CEB), Color(0xFF176EC2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(
                          Icons.person_remove_alt_1_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Remove Friend',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Color(0xFF2D3A45),
                        fontSize: 14,
                        height: 1.35,
                      ),
                      children: <InlineSpan>[
                        const TextSpan(
                          text: 'Are you sure you want to remove ',
                        ),
                        TextSpan(
                          text: friend.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: '?'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      SizedBox(
                        width: 92,
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFBFC8D4)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Color(0xFF344150),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 92,
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await _runRemove(friend.uid);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _runRemove(String friendUid) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });
    try {
      await _friendService.removeFriend(friendUserId: friendUid);
    } catch (e) {
      if (!mounted) {
        return;
      }
      showBlueLightToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }
}

class _FriendItem {
  const _FriendItem({
    required this.uid,
    required this.name,
    required this.photoUrl,
  });

  final String uid;
  final String name;
  final String photoUrl;
}
