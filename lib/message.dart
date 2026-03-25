import 'package:blue_light/friends.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/profile.dart';
import 'package:blue_light/ui/emergency_alerts.dart';
import 'package:blue_light/ui/shell_chrome.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyMessagePage extends StatefulWidget {
  const MyMessagePage({super.key, required this.title});

  final String title;

  @override
  State<MyMessagePage> createState() => _MyMessagePageState();
}

class _MyMessagePageState extends State<MyMessagePage> {
  String _searchText = '';

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    final User? user = _user;
    final Stream<QuerySnapshot<Map<String, dynamic>>>? convoStream = user == null
        ? null
        : FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('conversations')
            .orderBy('updatedAt', descending: true)
            .snapshots();

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
        onEmergencyTap: () => showEmergencyAlertDialog(context),
      ),
      floatingActionButton: buildBlueLightFab(() {}),
      floatingActionButtonLocation: blueLightFabLocation,
      bottomNavigationBar: BlueLightBottomNav(
        currentIndex: 2,
        onTap: (int index) {
          if (index == 2) return;
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => const MyHomePage(title: 'Home'),
              ),
            );
            return;
          }
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (BuildContext context) => const MyMapPage(title: 'Map'),
              ),
            );
            return;
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) =>
                  const MyFriendsPage(title: 'Friends'),
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
                      onChanged: (String value) => setState(() => _searchText = value),
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search),
                        hintText: 'Search chats',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: user == null ? null : _showNewMessageDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(45, 45),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.edit_note_rounded, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: user == null || convoStream == null
                  ? const Center(child: Text('No messages right now.'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: convoStream,
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                      ) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final List<_ConversationListItem> conversations =
                            (snapshot.data?.docs ??
                                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                                .map(
                          (QueryDocumentSnapshot<Map<String, dynamic>> doc) {
                            final Map<String, dynamic> data = doc.data();
                            final String peerId =
                                (data['peerUserId'] as String?)?.trim().isNotEmpty ==
                                        true
                                    ? (data['peerUserId'] as String).trim()
                                    : doc.id;
                            final String fallbackName =
                                (data['peerUsername'] as String?)?.trim().isNotEmpty ==
                                        true
                                    ? (data['peerUsername'] as String).trim()
                                    : 'User';
                            final String fallbackPhoto =
                                (data['peerPhotoUrl'] as String?)?.trim() ?? '';
                            final String preview =
                                (data['lastMessage'] as String?)?.trim().isNotEmpty ==
                                        true
                                    ? (data['lastMessage'] as String).trim()
                                    : 'No messages yet';
                            return _ConversationListItem(
                              peerId: peerId,
                              fallbackName: fallbackName,
                              fallbackPhoto: fallbackPhoto,
                              preview: preview,
                            );
                          },
                        ).toList();

                        if (conversations.isEmpty) {
                          return const Center(child: Text('No messages right now.'));
                        }

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .snapshots(),
                          builder: (
                            BuildContext context,
                            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                                usersSnapshot,
                          ) {
                            final Map<String, Map<String, dynamic>> usersById =
                                <String, Map<String, dynamic>>{};
                            for (final QueryDocumentSnapshot<Map<String, dynamic>> userDoc
                                in (usersSnapshot.data?.docs ??
                                    <QueryDocumentSnapshot<Map<String, dynamic>>>[])) {
                              usersById[userDoc.id] = userDoc.data();
                            }

                            final String q = _searchText.trim().toLowerCase();
                            final List<_ConversationListItem> filtered =
                                conversations.where((_ConversationListItem item) {
                              final _UserDisplay display = _resolveUserDisplay(
                                userData: usersById[item.peerId],
                                fallbackName: item.fallbackName,
                                fallbackPhoto: item.fallbackPhoto,
                              );
                              return q.isEmpty ||
                                  display.username.toLowerCase().contains(q);
                            }).toList();

                            if (filtered.isEmpty) {
                              return const Center(child: Text('No messages right now.'));
                            }

                            return ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (BuildContext context, int index) {
                                final _ConversationListItem item = filtered[index];
                                final _UserDisplay display = _resolveUserDisplay(
                                  userData: usersById[item.peerId],
                                  fallbackName: item.fallbackName,
                                  fallbackPhoto: item.fallbackPhoto,
                                );

                                return Dismissible(
                                  key: ValueKey<String>('conv-${item.peerId}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    alignment: Alignment.centerRight,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child:
                                        const Icon(Icons.delete, color: Colors.white),
                                  ),
                                  confirmDismiss: (_) =>
                                      _confirmDelete(display.username),
                                  onDismissed: (_) =>
                                      _deleteConversation(item.peerId),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (BuildContext context) =>
                                              ChatThreadPage(
                                            peerUserId: item.peerId,
                                            peerUsername: display.username,
                                            peerPhotoUrl: display.photoUrl,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: const Color(0xFFDDEBFA)),
                                        boxShadow: const <BoxShadow>[
                                          BoxShadow(
                                            color: Color(0x122E77BE),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: <Widget>[
                                          CircleAvatar(
                                            radius: 26,
                                            backgroundImage: display
                                                    .photoUrl.isNotEmpty
                                                ? NetworkImage(display.photoUrl)
                                                : null,
                                            backgroundColor: Colors.grey.shade200,
                                            child: display.photoUrl.isNotEmpty
                                                ? null
                                                : const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Text(
                                                  display.username,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.preview,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
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

  Future<void> _showNewMessageDialog() async {
    final User? user = _user;
    if (user == null) return;
    final List<_FriendChoice> friends = await _loadFriends(user.uid);
    String query = '';
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            final List<_FriendChoice> filtered = friends.where((_FriendChoice f) {
              return query.isEmpty || f.username.toLowerCase().contains(query.toLowerCase());
            }).toList();
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFF6FBFF), Color(0xFFEAF4FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD8EAFB)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[Color(0xFF1E9CEB), Color(0xFF176EC2)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.edit_note_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'New Message',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD9EAFB)),
                        ),
                        child: TextField(
                          onChanged: (String value) => setStateDialog(() => query = value),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search_rounded),
                            hintText: 'Search friends',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 300,
                        child: filtered.isEmpty
                            ? const Center(child: Text('No matching friends.'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final _FriendChoice friend = filtered[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE1EEFA)),
                                    ),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        Navigator.pop(dialogContext);
                                        Navigator.push(
                                          this.context,
                                          MaterialPageRoute(
                                            builder: (BuildContext context) => ChatThreadPage(
                                              peerUserId: friend.uid,
                                              peerUsername: friend.username,
                                              peerPhotoUrl: friend.photoUrl,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        children: <Widget>[
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundImage: friend.photoUrl.isNotEmpty
                                                ? NetworkImage(friend.photoUrl)
                                                : null,
                                            backgroundColor: Colors.grey.shade200,
                                            child: friend.photoUrl.isNotEmpty
                                                ? null
                                                : const Icon(Icons.person, color: Colors.white),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              friend.username,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14.5,
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Color(0xFF7EA7CE),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_FriendChoice>> _loadFriends(String uid) async {
    final DocumentSnapshot<Map<String, dynamic>> me =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final List<String> friendIds = ((me.data()?['friendIds'] as List?) ?? <dynamic>[])
        .whereType<String>()
        .toList();
    final List<_FriendChoice> out = <_FriendChoice>[];
    for (int i = 0; i < friendIds.length; i += 10) {
      final List<String> chunk = friendIds.sublist(i, i + 10 > friendIds.length ? friendIds.length : i + 10);
      final QuerySnapshot<Map<String, dynamic>> docs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs.docs) {
        final Map<String, dynamic> data = doc.data();
        out.add(_FriendChoice(
          uid: doc.id,
          username: (data['username'] as String?)?.trim().isNotEmpty == true
              ? (data['username'] as String).trim()
              : ((data['email'] as String?)?.split('@').first ?? 'User'),
          photoUrl: (data['photoUrl'] as String?)?.trim() ?? '',
        ));
      }
    }
    out.sort((_FriendChoice a, _FriendChoice b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return out;
  }

  Future<bool?> _confirmDelete(String name) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFF1E9CEB), Color(0xFF176EC2)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.delete_forever_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Delete Chat',
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
                  Text('Delete your chat with $name?'),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      SizedBox(
                        width: 92,
                        height: 38,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 108,
                        height: 38,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Confirm',
                              maxLines: 1,
                              softWrap: false,
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

  Future<void> _deleteConversation(String peerId) async {
    final User? user = _user;
    if (user == null) return;
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('conversations')
        .doc(peerId);
    final QuerySnapshot<Map<String, dynamic>> msgs = await ref.collection('messages').get();
    final WriteBatch batch = FirebaseFirestore.instance.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> m in msgs.docs) {
      batch.delete(m.reference);
    }
    batch.delete(ref);
    await batch.commit();
  }

  _UserDisplay _resolveUserDisplay({
    required Map<String, dynamic>? userData,
    required String fallbackName,
    required String fallbackPhoto,
  }) {
    final String liveName =
        (userData?['username'] as String?)?.trim().isNotEmpty == true
            ? (userData!['username'] as String).trim()
            : fallbackName;
    final String livePhoto =
        (userData?['photoUrl'] as String?)?.trim().isNotEmpty == true
            ? (userData!['photoUrl'] as String).trim()
            : fallbackPhoto;
    return _UserDisplay(username: liveName, photoUrl: livePhoto);
  }
}

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({
    super.key,
    required this.peerUserId,
    required this.peerUsername,
    required this.peerPhotoUrl,
  });

  final String peerUserId;
  final String peerUsername;
  final String peerPhotoUrl;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _user;
    if (user == null) return const Scaffold(body: Center(child: Text('Please sign in.')));
    final Stream<QuerySnapshot<Map<String, dynamic>>> stream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('conversations')
        .doc(widget.peerUserId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F8FF),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.peerUserId)
              .snapshots(),
          builder: (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> peerSnapshot,
          ) {
            final Map<String, dynamic> peerData =
                peerSnapshot.data?.data() ?? <String, dynamic>{};
            final String liveName =
                (peerData['username'] as String?)?.trim().isNotEmpty == true
                    ? (peerData['username'] as String).trim()
                    : widget.peerUsername;
            final String livePhoto =
                (peerData['photoUrl'] as String?)?.trim().isNotEmpty == true
                    ? (peerData['photoUrl'] as String).trim()
                    : widget.peerPhotoUrl;

            return Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundImage:
                      livePhoto.isNotEmpty ? NetworkImage(livePhoto) : null,
                  backgroundColor: Colors.grey.shade200,
                  child: livePhoto.isNotEmpty
                      ? null
                      : const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    liveName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1F2D3D),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (BuildContext context, AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                    snapshot.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
                  itemCount: docs.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Map<String, dynamic> data = docs[index].data();
                    final bool mine = (data['senderId'] as String?) == user.uid;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: const BoxConstraints(maxWidth: 290),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: mine ? const Color(0xFF1E9CEB) : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x122E77BE),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          (data['text'] as String?) ?? '',
                          style: TextStyle(color: mine ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Color(0x112E77BE),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F7FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD9EAFB)),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type a message',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E9CEB),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final User? user = _user;
    if (user == null) return;
    final String text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final DocumentSnapshot<Map<String, dynamic>> me = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final DocumentSnapshot<Map<String, dynamic>> peer = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.peerUserId)
          .get();
      final String myName = (me.data()?['username'] as String?)?.trim().isNotEmpty == true
          ? (me.data()!['username'] as String).trim()
          : ((user.email ?? '').split('@').first);
      final String myPhoto = (me.data()?['photoUrl'] as String?)?.trim() ?? '';
      final String peerName = (peer.data()?['username'] as String?)?.trim().isNotEmpty == true
          ? (peer.data()!['username'] as String).trim()
          : widget.peerUsername;
      final String peerPhoto = (peer.data()?['photoUrl'] as String?)?.trim().isNotEmpty == true
          ? (peer.data()!['photoUrl'] as String).trim()
          : widget.peerPhotoUrl;

      final FirebaseFirestore db = FirebaseFirestore.instance;
      final DocumentReference<Map<String, dynamic>> myConv = db
          .collection('users')
          .doc(user.uid)
          .collection('conversations')
          .doc(widget.peerUserId);
      final DocumentReference<Map<String, dynamic>> peerConv = db
          .collection('users')
          .doc(widget.peerUserId)
          .collection('conversations')
          .doc(user.uid);
      final WriteBatch batch = db.batch();
      batch.set(myConv, <String, dynamic>{
        'peerUserId': widget.peerUserId,
        'peerUsername': peerName,
        'peerPhotoUrl': peerPhoto,
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(peerConv, <String, dynamic>{
        'peerUserId': user.uid,
        'peerUsername': myName,
        'peerPhotoUrl': myPhoto,
        'lastMessage': text,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(myConv.collection('messages').doc(), <String, dynamic>{
        'text': text,
        'senderId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(peerConv.collection('messages').doc(), <String, dynamic>{
        'text': text,
        'senderId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _FriendChoice {
  const _FriendChoice({
    required this.uid,
    required this.username,
    required this.photoUrl,
  });

  final String uid;
  final String username;
  final String photoUrl;
}

class _ConversationListItem {
  const _ConversationListItem({
    required this.peerId,
    required this.fallbackName,
    required this.fallbackPhoto,
    required this.preview,
  });

  final String peerId;
  final String fallbackName;
  final String fallbackPhoto;
  final String preview;
}

class _UserDisplay {
  const _UserDisplay({
    required this.username,
    required this.photoUrl,
  });

  final String username;
  final String photoUrl;
}
