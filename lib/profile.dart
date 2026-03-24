import 'dart:math';

import 'package:blue_light/friends.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/map.dart';
import 'package:blue_light/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blue_light/ui/emergency_alerts.dart';
import 'package:blue_light/ui/shell_chrome.dart';

class _ProfileFriendOption {
  const _ProfileFriendOption({
    required this.uid,
    required this.username,
    required this.email,
    required this.photoUrl,
  });

  final String uid;
  final String username;
  final String email;
  final String photoUrl;
}

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key, required this.title});

  final String title;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String _photoUrl = '';
  bool _locationTrackingEnabled = true;
  double _nearbyAlertRadiusMiles = 5.0;
  Set<String> _trustedContactIds = <String>{};

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String _generateRandomUsername() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random.secure();
    final String suffix = List<String>.generate(
      6,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'user_$suffix';
  }

  Future<void> _loadProfile() async {
    final User? user = _currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final DocumentReference<Map<String, dynamic>> ref =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();

    if (!snapshot.exists) {
      final String username = _generateRandomUsername();
      await ref.set(<String, Object?>{
        'email': user.email ?? '',
        'username': username,
        'photoUrl': '',
        'trustedContactEmails': <String>[],
        'trustedContactIds': <String>[],
        'nearbyAlertRadiusMiles': 5.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _usernameController.text = username;
      _trustedContactIds = <String>{};
      _photoUrl = '';
      _locationTrackingEnabled = true;
      _nearbyAlertRadiusMiles = 5.0;
    } else {
      final Map<String, dynamic> data = snapshot.data()!;
      final String username = (data['username'] as String?)?.trim() ?? '';
      _usernameController.text =
          username.isEmpty ? _generateRandomUsername() : username;
      _trustedContactIds = ((data['trustedContactIds'] as List?) ?? <dynamic>[])
          .whereType<String>()
          .toSet();
      _photoUrl = (data['photoUrl'] as String?) ?? '';
      _locationTrackingEnabled =
          (data['locationTrackingEnabled'] as bool?) ?? true;
      _nearbyAlertRadiusMiles =
          (data['nearbyAlertRadiusMiles'] as num?)?.toDouble() ?? 5.0;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUsername() async {
    final User? user = _currentUser;
    if (user == null) {
      return;
    }

    final String username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final List<_ProfileFriendOption> friends = await _fetchFriendOptions();
    final Map<String, _ProfileFriendOption> friendById = <String, _ProfileFriendOption>{
      for (final _ProfileFriendOption f in friends) f.uid: f,
    };
    final List<String> trustedEmails = _trustedContactIds
        .map((String id) => friendById[id]?.email ?? '')
        .where((String email) => email.isNotEmpty)
        .toSet()
        .toList();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      <String, Object?>{
        'username': username,
        'trustedContactIds': _trustedContactIds.toList(),
        'trustedContactEmails': trustedEmails,
        'nearbyAlertRadiusMiles': _nearbyAlertRadiusMiles,
      },
      SetOptions(merge: true),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated.')),
    );
  }

  Future<void> _setLocationTrackingEnabled(bool enabled) async {
    final User? user = _currentUser;
    if (user == null) {
      return;
    }

    setState(() {
      _locationTrackingEnabled = enabled;
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      <String, Object?>{
        'locationTrackingEnabled': enabled,
      },
      SetOptions(merge: true),
    );
  }

  Future<List<_ProfileFriendOption>> _fetchFriendOptions() async {
    final User? user = _currentUser;
    if (user == null) {
      return <_ProfileFriendOption>[];
    }
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final DocumentSnapshot<Map<String, dynamic>> me =
        await firestore.collection('users').doc(user.uid).get();
    final List<String> friendIds = ((me.data()?['friendIds'] as List?) ?? <dynamic>[])
        .whereType<String>()
        .where((String id) => id != user.uid)
        .toList();

    final List<_ProfileFriendOption> out = <_ProfileFriendOption>[];
    if (friendIds.isNotEmpty) {
      for (int i = 0; i < friendIds.length; i += 10) {
        final List<String> chunk = friendIds.sublist(
          i,
          i + 10 > friendIds.length ? friendIds.length : i + 10,
        );
        final QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
          final Map<String, dynamic> data = doc.data();
          out.add(
            _ProfileFriendOption(
              uid: doc.id,
              username: (data['username'] as String?)?.trim().isNotEmpty == true
                  ? (data['username'] as String).trim()
                  : 'User',
              email: (data['email'] as String?) ?? '',
              photoUrl: (data['photoUrl'] as String?) ?? '',
            ),
          );
        }
      }
    } else {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await firestore.collection('users').limit(100).get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        if (doc.id == user.uid) {
          continue;
        }
        final Map<String, dynamic> data = doc.data();
        out.add(
          _ProfileFriendOption(
            uid: doc.id,
            username: (data['username'] as String?)?.trim().isNotEmpty == true
                ? (data['username'] as String).trim()
                : 'User',
            email: (data['email'] as String?) ?? '',
            photoUrl: (data['photoUrl'] as String?) ?? '',
          ),
        );
      }
    }
    out.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    return out;
  }

  Future<void> _openTrustedContactsPicker() async {
    final User? user = _currentUser;
    if (user == null) {
      return;
    }
    final List<_ProfileFriendOption> friends = await _fetchFriendOptions();
    final Set<String> selected = <String>{..._trustedContactIds};
    String? errorText;
    bool isSavingContacts = false;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            final List<_ProfileFriendOption> selectedFriends = friends
                .where((f) => selected.contains(f.uid))
                .toList();
            final List<_ProfileFriendOption> otherFriends = friends
                .where((f) => !selected.contains(f.uid))
                .toList();
            final List<_ProfileFriendOption> ordered =
                <_ProfileFriendOption>[...selectedFriends, ...otherFriends];

            Future<void> saveContacts() async {
              setStateDialog(() {
                isSavingContacts = true;
                errorText = null;
              });
              try {
                final List<String> selectedEmails = ordered
                    .where((f) => selected.contains(f.uid))
                    .map((f) => f.email)
                    .where((e) => e.isNotEmpty)
                    .toSet()
                    .toList();
                await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
                  <String, Object?>{
                    'trustedContactIds': selected.toList(),
                    'trustedContactEmails': selectedEmails,
                  },
                  SetOptions(merge: true),
                );
                if (!mounted) {
                  return;
                }
                setState(() {
                  _trustedContactIds = <String>{...selected};
                });
                Navigator.of(dialogContext).pop();
              } catch (_) {
                setStateDialog(() {
                  errorText = 'Could not save personal contacts right now.';
                });
              } finally {
                setStateDialog(() {
                  isSavingContacts = false;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text(
                'Personal Contacts',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${selected.length} selected',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (friends.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No friends available yet.'),
                      )
                    else
                      SizedBox(
                        height: 320,
                        child: ListView.builder(
                          itemCount: ordered.length,
                          itemBuilder: (BuildContext context, int index) {
                            final _ProfileFriendOption friend = ordered[index];
                            final bool isSelected = selected.contains(friend.uid);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              onTap: () {
                                setStateDialog(() {
                                  if (isSelected) {
                                    selected.remove(friend.uid);
                                  } else {
                                    selected.add(friend.uid);
                                  }
                                });
                              },
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.lightBlue.shade100,
                                backgroundImage: friend.photoUrl.isNotEmpty
                                    ? NetworkImage(friend.photoUrl)
                                    : null,
                                child: friend.photoUrl.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        size: 18,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              title: Text(
                                friend.username,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: friend.email.isEmpty
                                  ? null
                                  : Text(friend.email),
                              trailing: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? Colors.lightBlue
                                    : Colors.grey.shade500,
                              ),
                            );
                          },
                        ),
                      ),
                    if (errorText != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSavingContacts
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSavingContacts ? null : saveContacts,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(132, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: isSavingContacts
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final User? user = _currentUser;
    if (user == null) {
      return;
    }

    final XFile? file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (file == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final Reference ref =
        FirebaseStorage.instance.ref('profile_photos/${user.uid}.jpg');
    await ref.putData(await file.readAsBytes());
    final String downloadUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      <String, Object?>{
        'photoUrl': downloadUrl,
      },
      SetOptions(merge: true),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _photoUrl = downloadUrl;
      _isSaving = false;
    });
  }

  Future<void> _showPhotoOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BlueLightTopBar(
        title: widget.title,
        onProfileTap: () {},
        onEmergencyTap: () {
          showEmergencyAlertDialog(context);
        },
      ),
      floatingActionButton: buildBlueLightFab(() {}),
      floatingActionButtonLocation: blueLightFabLocation,
      bottomNavigationBar: BlueLightBottomNav(
        currentIndex: -1,
        onTap: (int index) {
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
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<MyMapPage>(
                builder: (BuildContext context) =>
                    const MyMapPage(title: "Map"),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFFE6F5FF),
                    Color(0xFFFDFEFF),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: <Widget>[
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: <Widget>[
                              Stack(
                                children: <Widget>[
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor: Colors.lightBlue.shade100,
                                    backgroundImage: _photoUrl.isNotEmpty
                                        ? NetworkImage(_photoUrl)
                                        : null,
                                    child: _photoUrl.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 46,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: InkWell(
                                      onTap: _showPhotoOptions,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.lightBlue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Profile Settings',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentUser?.email ?? '',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: const Icon(Icons.alternate_email),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text(
                                      'Personal Contacts',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_trustedContactIds.length} selected for emergency alerts.',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _openTrustedContactsPicker,
                                        icon: const Icon(Icons.group_add_rounded),
                                        label: const Text('Manage Personal Contacts'),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.lightBlue),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text(
                                      'Nearby Alert Distance',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Notify users within ${_nearbyAlertRadiusMiles.toStringAsFixed(0)} miles.',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Slider(
                                      value: _nearbyAlertRadiusMiles,
                                      min: 1,
                                      max: 25,
                                      divisions: 24,
                                      label: '${_nearbyAlertRadiusMiles.toStringAsFixed(0)} mi',
                                      onChanged: (double value) {
                                        setState(() {
                                          _nearbyAlertRadiusMiles = value;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.blue.shade100),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.lightBlue.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.my_location_rounded,
                                        color: Colors.lightBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            'Location Tracking',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Show your live position on the map.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _locationTrackingEnabled,
                                      onChanged: (bool value) {
                                        _setLocationTrackingEnabled(value);
                                      },
                                      activeColor: Colors.lightBlue,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveUsername,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.lightBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: _logout,
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
