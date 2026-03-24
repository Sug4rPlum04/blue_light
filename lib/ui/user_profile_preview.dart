import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> showUserProfilePreviewDialog({
  required BuildContext context,
  required String targetUserId,
  String fallbackUsername = 'User',
  String fallbackPhotoUrl = '',
}) async {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    return;
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final DocumentSnapshot<Map<String, dynamic>> targetSnapshot =
      await firestore.collection('users').doc(targetUserId).get();
  final DocumentSnapshot<Map<String, dynamic>> meSnapshot =
      await firestore.collection('users').doc(currentUser.uid).get();

  final Map<String, dynamic> targetData =
      targetSnapshot.data() ?? <String, dynamic>{};
  final Map<String, dynamic> meData = meSnapshot.data() ?? <String, dynamic>{};

  final String username =
      (targetData['username'] as String?)?.trim().isNotEmpty == true
          ? (targetData['username'] as String).trim()
          : fallbackUsername;
  final String photoUrl = (targetData['photoUrl'] as String?)?.trim().isNotEmpty ==
          true
      ? (targetData['photoUrl'] as String).trim()
      : fallbackPhotoUrl;

  final Set<String> targetFriendIds =
      ((targetData['friendIds'] as List?) ?? <dynamic>[])
          .whereType<String>()
          .toSet();
  final Set<String> myFriendIds = ((meData['friendIds'] as List?) ?? <dynamic>[])
      .whereType<String>()
      .toSet();
  final List<String> mutualIds = targetFriendIds.intersection(myFriendIds).toList();
  final List<_MutualFriendPreview> mutualFriends =
      await _loadMutualFriendPreviews(mutualIds);

  if (!context.mounted) {
    return;
  }

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
              colors: <Color>[Color(0xFFF7FBFF), Color(0xFFEAF4FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFD8EAFB)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFF249FEC), Color(0xFF136ECF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x402E77BE),
                            blurRadius: 14,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          CircleAvatar(
                            radius: 29,
                            backgroundColor: Colors.white.withOpacity(0.93),
                            backgroundImage:
                                photoUrl.trim().isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.trim().isNotEmpty
                                ? null
                                : const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF0C8AE8),
                                    size: 30,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              username,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mutual Friends',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF243447),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 190),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD9EAFB)),
                      ),
                      child: mutualFriends.isEmpty
                          ? const Text(
                              'No mutual friends yet.',
                              style: TextStyle(fontSize: 13),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: mutualFriends.length,
                              itemBuilder: (BuildContext context, int index) {
                                final _MutualFriendPreview mutualFriend =
                                    mutualFriends[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: <Widget>[
                                      CircleAvatar(
                                        radius: 14,
                                        backgroundColor: const Color(0xFFE3EDF8),
                                        backgroundImage:
                                            mutualFriend.photoUrl.isNotEmpty
                                                ? NetworkImage(mutualFriend.photoUrl)
                                                : null,
                                        child: mutualFriend.photoUrl.isNotEmpty
                                            ? null
                                            : const Icon(
                                                Icons.person_rounded,
                                                size: 14,
                                                color: Color(0xFF0C8AE8),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          mutualFriend.username,
                                          style: const TextStyle(fontSize: 13.2),
                                        ),
                                      ),
                                    ],
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
}

Future<List<_MutualFriendPreview>> _loadMutualFriendPreviews(
  List<String> userIds,
) async {
  if (userIds.isEmpty) {
    return <_MutualFriendPreview>[];
  }

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final List<_MutualFriendPreview> previews = <_MutualFriendPreview>[];

  for (int i = 0; i < userIds.length; i += 10) {
    final List<String> chunk = userIds.sublist(
      i,
      i + 10 > userIds.length ? userIds.length : i + 10,
    );
    final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: chunk)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String username =
          (data['username'] as String?)?.trim().isNotEmpty == true
              ? (data['username'] as String).trim()
              : ((data['email'] as String?)?.split('@').first ?? 'User');
      final String photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';
      previews.add(
        _MutualFriendPreview(
          username: username,
          photoUrl: photoUrl,
        ),
      );
    }
  }

  previews.sort(
    (_MutualFriendPreview a, _MutualFriendPreview b) =>
        a.username.toLowerCase().compareTo(b.username.toLowerCase()),
  );
  return previews;
}

class _MutualFriendPreview {
  const _MutualFriendPreview({
    required this.username,
    required this.photoUrl,
  });

  final String username;
  final String photoUrl;
}
