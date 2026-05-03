import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:blue_light/utils/user_display.dart';

class FriendService {
  FriendService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  User? get _currentUser => _auth.currentUser;

  Future<void> sendFriendRequest({required String toUserId}) async {
    final User? user = _currentUser;
    if (user == null) {
      throw Exception('You need to be logged in to send a friend request.');
    }
    if (toUserId == user.uid) {
      throw Exception('You cannot send a friend request to yourself.');
    }

    final DocumentReference<Map<String, dynamic>> meRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> targetRef = _firestore
        .collection('users')
        .doc(toUserId);

    final DocumentSnapshot<Map<String, dynamic>> meSnap = await meRef.get();
    final DocumentSnapshot<Map<String, dynamic>> targetSnap = await targetRef
        .get();
    final Map<String, dynamic> meData = meSnap.data() ?? <String, dynamic>{};
    final Map<String, dynamic> targetData =
        targetSnap.data() ?? <String, dynamic>{};

    final Set<String> myFriendIds =
        ((meData['friendIds'] as List?) ?? <dynamic>[])
            .whereType<String>()
            .toSet();
    if (myFriendIds.contains(toUserId)) {
      throw Exception('You are already friends.');
    }
    if (!targetSnap.exists || targetData.isEmpty) {
      throw Exception('This user could not be found.');
    }

    final DocumentReference<Map<String, dynamic>> incomingRef = targetRef
        .collection('incoming_friend_requests')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> outgoingRef = meRef
        .collection('outgoing_friend_requests')
        .doc(toUserId);

    final String senderName = resolveDisplayName(
      <String, dynamic>{
        ...meData,
        if ((user.email ?? '').trim().isNotEmpty) 'email': user.email,
      },
      userId: user.uid,
      fallback: 'User',
    );
    final String senderPhoto = (meData['photoUrl'] as String?)?.trim() ?? '';
    final String senderEmail = user.email ?? '';

    final WriteBatch batch = _firestore.batch();
    batch.set(incomingRef, <String, dynamic>{
      'fromUserId': user.uid,
      'fromUsername': senderName,
      'fromPhotoUrl': senderPhoto,
      'fromEmail': senderEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(outgoingRef, <String, dynamic>{
      'toUserId': toUserId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(targetRef.collection('activity').doc(), <String, dynamic>{
      'type': 'friend_request',
      'title': '$senderName sent you a friend request',
      'message': '$senderName has sent you a friend request.',
      'fromUserId': user.uid,
      'fromUsername': senderName,
      'fromPhotoUrl': senderPhoto,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> acceptFriendRequest({
    required String fromUserId,
    String? activityDocIdToDelete,
  }) async {
    final User? user = _currentUser;
    if (user == null) {
      throw Exception('You need to be logged in to accept requests.');
    }
    if (fromUserId == user.uid) {
      throw Exception('Invalid friend request.');
    }

    final DocumentReference<Map<String, dynamic>> meRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> fromRef = _firestore
        .collection('users')
        .doc(fromUserId);

    final DocumentSnapshot<Map<String, dynamic>> meSnap = await meRef.get();
    final DocumentSnapshot<Map<String, dynamic>> fromSnap = await fromRef.get();
    final Map<String, dynamic> meData = meSnap.data() ?? <String, dynamic>{};
    if (!fromSnap.exists) {
      throw Exception('This friend request is no longer available.');
    }

    final String meName = resolveDisplayName(
      <String, dynamic>{
        ...meData,
        if ((user.email ?? '').trim().isNotEmpty) 'email': user.email,
      },
      userId: user.uid,
      fallback: 'User',
    );
    final String mePhoto = (meData['photoUrl'] as String?)?.trim() ?? '';

    final WriteBatch batch = _firestore.batch();
    batch.set(meRef, <String, dynamic>{
      'friendIds': FieldValue.arrayUnion(<String>[fromUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(fromRef, <String, dynamic>{
      'friendIds': FieldValue.arrayUnion(<String>[user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.delete(meRef.collection('incoming_friend_requests').doc(fromUserId));
    batch.delete(fromRef.collection('outgoing_friend_requests').doc(user.uid));

    final QuerySnapshot<Map<String, dynamic>> requestActivities = await meRef
        .collection('activity')
        .where('type', isEqualTo: 'friend_request')
        .where('fromUserId', isEqualTo: fromUserId)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in requestActivities.docs) {
      batch.delete(doc.reference);
    }

    if (activityDocIdToDelete != null &&
        activityDocIdToDelete.trim().isNotEmpty) {
      batch.delete(
        meRef.collection('activity').doc(activityDocIdToDelete.trim()),
      );
    }

    batch.set(fromRef.collection('activity').doc(), <String, dynamic>{
      'type': 'friend_request_accepted',
      'title': '$meName accepted your friend request',
      'message': '$meName has accepted your friend request.',
      'fromUserId': user.uid,
      'fromUsername': meName,
      'fromPhotoUrl': mePhoto,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> declineFriendRequest({
    required String fromUserId,
    String? activityDocIdToDelete,
  }) async {
    final User? user = _currentUser;
    if (user == null) {
      throw Exception('You need to be logged in to decline requests.');
    }
    if (fromUserId == user.uid) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> meRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> fromRef = _firestore
        .collection('users')
        .doc(fromUserId);

    final WriteBatch batch = _firestore.batch();
    batch.delete(meRef.collection('incoming_friend_requests').doc(fromUserId));
    batch.delete(fromRef.collection('outgoing_friend_requests').doc(user.uid));

    final QuerySnapshot<Map<String, dynamic>> requestActivities = await meRef
        .collection('activity')
        .where('type', isEqualTo: 'friend_request')
        .where('fromUserId', isEqualTo: fromUserId)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in requestActivities.docs) {
      batch.delete(doc.reference);
    }

    if (activityDocIdToDelete != null &&
        activityDocIdToDelete.trim().isNotEmpty) {
      batch.delete(
        meRef.collection('activity').doc(activityDocIdToDelete.trim()),
      );
    }

    await batch.commit();
  }

  Future<void> removeFriend({required String friendUserId}) async {
    final User? user = _currentUser;
    if (user == null) {
      throw Exception('You need to be logged in to remove friends.');
    }
    if (friendUserId == user.uid) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> meRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> friendRef = _firestore
        .collection('users')
        .doc(friendUserId);

    final WriteBatch batch = _firestore.batch();
    batch.set(meRef, <String, dynamic>{
      'friendIds': FieldValue.arrayRemove(<String>[friendUserId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(friendRef, <String, dynamic>{
      'friendIds': FieldValue.arrayRemove(<String>[user.uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.delete(
      meRef.collection('incoming_friend_requests').doc(friendUserId),
    );
    batch.delete(
      meRef.collection('outgoing_friend_requests').doc(friendUserId),
    );
    batch.delete(
      friendRef.collection('incoming_friend_requests').doc(user.uid),
    );
    batch.delete(
      friendRef.collection('outgoing_friend_requests').doc(user.uid),
    );
    await batch.commit();
  }

  Future<void> cancelFriendRequest({required String toUserId}) async {
    final User? user = _currentUser;
    if (user == null) {
      throw Exception('You need to be logged in to cancel requests.');
    }
    if (toUserId == user.uid) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> meRef = _firestore
        .collection('users')
        .doc(user.uid);
    final DocumentReference<Map<String, dynamic>> targetRef = _firestore
        .collection('users')
        .doc(toUserId);

    final WriteBatch batch = _firestore.batch();
    batch.delete(meRef.collection('outgoing_friend_requests').doc(toUserId));
    batch.delete(
      targetRef.collection('incoming_friend_requests').doc(user.uid),
    );

    final QuerySnapshot<Map<String, dynamic>> requestActivities =
        await targetRef
            .collection('activity')
            .where('type', isEqualTo: 'friend_request')
            .where('fromUserId', isEqualTo: user.uid)
            .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in requestActivities.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}
