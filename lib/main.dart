import 'dart:async';

import 'package:blue_light/forgot_password.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/services/background_location_service.dart';
import 'package:blue_light/sign_up.dart';
import 'package:blue_light/ui/shell_chrome.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blue Light',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2A8BE8)),
        scaffoldBackgroundColor: const Color(0xFFF4F8FD),
        fontFamily: 'sans-serif',
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FBFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD3E4F8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD3E4F8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2A8BE8), width: 1.4),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
      ),
      routes: <String, WidgetBuilder>{
        '/login': (BuildContext context) =>
            const MyLoginPage(title: 'Flutter Demo Home Page'),
        '/home': (BuildContext context) => const MyHomePage(title: 'Home'),
      },
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  bool _ranStartupFlow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(BackgroundLocationService.instance.syncForCurrentUser());
    }
  }

  Future<void> _runSignedInStartup() async {
    if (_ranStartupFlow) {
      return;
    }
    _ranStartupFlow = true;

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await userRef.get();
    final Map<String, dynamic> userData =
        snapshot.data() ?? <String, dynamic>{};
    final bool disclosureAccepted =
        userData['backgroundLocationDisclosureAcceptedAt'] != null;

    if (!disclosureAccepted && mounted) {
      final bool accepted = await _showBackgroundLocationDisclosure(context);
      if (accepted) {
        await userRef.set(<String, Object?>{
          'backgroundLocationDisclosureAcceptedAt':
              FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          await _requestLocationPermissionFlow(context);
        }
      }
    }

    await BackgroundLocationService.instance.syncForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          unawaited(_runSignedInStartup());
          return const MyHomePage(title: 'Home');
        }

        _ranStartupFlow = false;
        unawaited(BackgroundLocationService.instance.stop());
        return const MyLoginPage(title: 'Flutter Demo Home Page');
      },
    );
  }
}

Future<bool> _showBackgroundLocationDisclosure(BuildContext context) async {
  final bool? accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Allow Background Location',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Blue Light collects location data to enable live location sharing '
          'with trusted friends and nearby emergency alerts, even when the app '
          'is closed or not in use.\n\n'
          'This data is only used for safety features you enable in-app.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
  return accepted ?? false;
}

Future<void> _requestLocationPermissionFlow(BuildContext context) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    if (!context.mounted) {
      return;
    }
    showBlueLightToast(
      context,
      'Location permission was not granted. You can enable it later in settings.',
    );
    return;
  }

  if (permission != LocationPermission.always && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Enable "Allow all the time"',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'To keep live location sharing active in the background, open system '
            'settings and set:\nPermissions -> Location -> Allow all the time.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}

class MyLoginPage extends StatefulWidget {
  const MyLoginPage({super.key, required this.title});

  final String title;

  @override
  State<MyLoginPage> createState() => _MyLoginPageState();
}

class _MyLoginPageState extends State<MyLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  String _generateRandomUsername() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${chars[DateTime.now().millisecond % chars.length]}';
  }

  Future<void> _ensureUserProfileDocument(User user) async {
    final DocumentReference<Map<String, dynamic>> ref = FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid);
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();
    final Map<String, dynamic> existing =
        snapshot.data() ?? <String, dynamic>{};
    final Map<String, Object?> patch = <String, Object?>{};

    if (!snapshot.exists) {
      patch['createdAt'] = FieldValue.serverTimestamp();
    }

    final String email = (existing['email'] as String?)?.trim() ?? '';
    final String? authEmail = user.email?.trim();
    if (email.isEmpty && authEmail != null && authEmail.isNotEmpty) {
      patch['email'] = authEmail;
    }

    final String username = (existing['username'] as String?)?.trim() ?? '';
    if (username.isEmpty) {
      patch['username'] = _generateRandomUsername();
    }

    if (existing['photoUrl'] == null) {
      patch['photoUrl'] = '';
    }
    if (existing['locationTrackingEnabled'] == null) {
      patch['locationTrackingEnabled'] = false;
    }
    if (existing['friendIds'] == null) {
      patch['friendIds'] = <String>[];
    }
    if (existing['trustedContactIds'] == null) {
      patch['trustedContactIds'] = <String>[];
    }
    if (existing['trustedContactEmails'] == null) {
      patch['trustedContactEmails'] = <String>[];
    }

    if (patch.isNotEmpty) {
      await ref.set(patch, SetOptions(merge: true));
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Please enter both email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final User? user = credential.user;
      if (user == null) {
        setState(() {
          _errorText = 'Login failed. Please try again.';
        });
        return;
      }
      await _ensureUserProfileDocument(user);

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (BuildContext context) => const MyHomePage(title: 'Home'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'wrong-password') {
          _errorText = 'Password incorrect.';
        } else if (e.code == 'invalid-credential' ||
            e.code == 'user-not-found') {
          _errorText = 'Email or password is incorrect.';
        } else {
          _errorText = e.message ?? 'Unable to log in right now.';
        }
      });
    } catch (_) {
      setState(() {
        _errorText = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Color(0xFF0A4F96),
                  Color(0xFF2A8BE8),
                  Color(0xFFEAF4FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -35,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 14,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        blueLightBrandMark(size: 58, iconColor: colors.primary),
                        const SizedBox(height: 12),
                        const Text(
                          'Welcome!',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign In.',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        if (_errorText != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _errorText!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<SignUpPage>(
                                    builder: (BuildContext context) =>
                                        const SignUpPage(),
                                  ),
                                );
                              },
                              child: Text(
                                'Create Account',
                                style: TextStyle(color: colors.primary),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute<ForgotPasswordPage>(
                                    builder: (BuildContext context) =>
                                        const ForgotPasswordPage(),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(color: colors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _isLoading ? null : _login,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
