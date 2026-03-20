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
        'createdAt': FieldValue.serverTimestamp(),
      });
      _usernameController.text = username;
      _photoUrl = '';
      _locationTrackingEnabled = true;
    } else {
      final Map<String, dynamic> data = snapshot.data()!;
      final String username = (data['username'] as String?)?.trim() ?? '';
      _usernameController.text =
          username.isEmpty ? _generateRandomUsername() : username;
      _photoUrl = (data['photoUrl'] as String?) ?? '';
      _locationTrackingEnabled =
          (data['locationTrackingEnabled'] as bool?) ?? true;
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

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      <String, Object?>{
        'username': username,
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
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        toolbarHeight: 100,
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: IconButton(
              icon: const Icon(Icons.person, color: Colors.white, size: 30),
              onPressed: () {},
            ),
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.lightBlueAccent,
          shape: const CircleBorder(),
          elevation: 6,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.lightBlue,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _navItem(
                icon: Icons.home_rounded,
                label: "Home",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<MyHomePage>(
                      builder: (BuildContext context) =>
                          const MyHomePage(title: "Home"),
                    ),
                  );
                },
              ),
              _navItem(
                icon: Icons.location_on,
                label: "Map",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<MyMapPage>(
                      builder: (BuildContext context) =>
                          const MyMapPage(title: "Map"),
                    ),
                  );
                },
              ),
              const SizedBox(width: 40),
              _navItem(
                icon: Icons.chat_rounded,
                label: "Messages",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<MyMessagePage>(
                      builder: (BuildContext context) =>
                          const MyMessagePage(title: "Messages"),
                    ),
                  );
                },
              ),
              _navItem(
                icon: Icons.people_alt_rounded,
                label: "Friends",
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<MyFriendsPage>(
                      builder: (BuildContext context) =>
                          const MyFriendsPage(title: "Friends"),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
