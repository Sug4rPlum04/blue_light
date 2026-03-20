import 'package:blue_light/forgot_password.dart';
import 'package:blue_light/home.dart';
import 'package:blue_light/sign_up.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blue Light',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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

class _AuthGate extends StatelessWidget {
  const _AuthGate();

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
          return const MyHomePage(title: 'Home');
        }

        return const MyLoginPage(title: 'Flutter Demo Home Page');
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
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

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
        } else if (e.code == 'invalid-credential' || e.code == 'user-not-found') {
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
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 30,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Image.network(
                    'https://static.vecteezy.com/system/resources/previews/021/334/113/non_2x/pastel-blue-wavy-line-bubble-and-circle-elements-on-white-background-minimal-simple-and-clean-concept-used-for-background-backdrop-banner-wallpaper-copy-space-or-landing-page-vector.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ),
                Center(
                  child: Image.network(
                    'https://cdn-icons-png.freepik.com/512/5400/5400308.png',
                    height: 150,
                    width: 150,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 70,
            child: Center(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const SizedBox(height: 40),
                  Container(
                    margin: const EdgeInsets.only(top: 20, bottom: 20),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(
                      left: 35,
                      right: 35,
                      bottom: 10,
                      top: 10,
                    ),
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Email',
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 35, right: 35, top: 10),
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Password',
                      ),
                    ),
                  ),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(left: 25),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<SignUpPage>(
                                builder: (BuildContext context) => const SignUpPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Create Account',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 25),
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<ForgotPasswordPage>(
                                builder: (BuildContext context) =>
                                    const ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: 250,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 16),
                            ),
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
}
