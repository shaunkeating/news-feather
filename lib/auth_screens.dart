import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({required this.email, super.key});

  @override
  _VerifyEmailScreenState createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isLoading = false;
  String? _message;

  Future<void> _checkVerification() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
        if (user!.emailVerified) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          setState(() {
            _message = 'Email not verified yet. Please check your inbox.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _message = 'Error checking verification: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        setState(() {
          _message = 'Verification email resent. Please check your inbox.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error resending email: $e';
        _isLoading = false;
      });
    }
  }

  void _signUpDifferentEmail() {
    FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/signup');
  }

  @override
  Widget build(BuildContext context) {
    const double buttonWidth = 200.0;
    const Color creamColor = Color(0xFFFFF5E1);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Verification email sent. Please check your inbox and click the link to continue.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: creamColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'I’ve Verified My Email',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: buttonWidth,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _resendVerification,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: creamColor, width: 2),
                    backgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Resend Verification Link',
                    style: TextStyle(color: creamColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _signUpDifferentEmail,
                child: Text(
                  'Sign up with a different email address',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    _message!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  Future<void> _signInWithEmail(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        setState(() {
          _errorMessage = 'Sign-in failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) Navigator.pop(context); // Close loading dialog
        return; // User canceled sign-in
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        setState(() {
          _errorMessage = 'Google sign-in failed: ${e.toString()}';
        });
      }
    }
  }

  void _showLoadingDialog(BuildContext context, Future<void> Function(BuildContext) signInMethod) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing dialog manually
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    signInMethod(context);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 64),
              const Text(
                'News Feather',
                style: TextStyle(
                  color: Color(0xFFF2F2F4),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Color(0xFFF2F2F4)),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                  filled: true,
                  fillColor: const Color(0xFF2F2F2F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Color(0xFFF2F2F4)),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                  filled: true,
                  fillColor: const Color(0xFF2F2F2F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showLoadingDialog(context, _signInWithEmail),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5BE92),
                  foregroundColor: const Color(0xFF000000),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(200, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Sign In with Email'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showLoadingDialog(context, _signInWithGoogle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(200, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.network(
                      'https://www.google.com/favicon.ico',
                      height: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text('Sign In with Google'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
                child: const Text(
                  'Don’t have an account? Sign up',
                  style: TextStyle(color: Color(0xFFC5BE92)),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signUpWithEmail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      if (_passwordController.text != _confirmPasswordController.text) {
        throw 'Passwords do not match';
      }
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      User? user = userCredential.user;
      if (user != null) {
        String fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        await user.updateDisplayName(fullName);
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
          'email': user.email,
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'display_name': fullName,
          'created_at': FieldValue.serverTimestamp(),
          'email_verified': false,
          'uid': user.uid,
        }, SetOptions(merge: true));

        await user.sendEmailVerification();
        Navigator.pushReplacementNamed(context, '/verify-email', arguments: user.email!);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.code == 'email-already-in-use'
            ? 'This email is already registered.'
            : e.code == 'weak-password'
                ? 'Password is too weak.'
                : 'Sign-up failed: ${e.message}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;
      if (user != null && userCredential.additionalUserInfo!.isNewUser) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'photo_url': user.photoURL,
          'created_at': FieldValue.serverTimestamp(),
          'phone_number': null,
          'firstName': user.displayName?.split(' ').first ?? '',
          'lastName': user.displayName?.split(' ').last ?? '',
          'display_name': user.displayName ?? '',
          'uid': user.uid,
          'email_verified': true,
        });
      }
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign-up failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 64),
            const Text('Join News Feather', style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TextField(
              controller: _firstNameController,
              style: const TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'First Name',
                labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: const Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              style: const TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'Last Name',
                labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: const Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: const Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              style: const TextStyle(color: Color(0xFFF2F2F4)),
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: const Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              style: const TextStyle(color: Color(0xFFF2F2F4)),
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: const TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: const Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signUpWithEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC5BE92),
                foregroundColor: const Color(0xFF000000),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(200, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Sign Up'),
            ),
            const SizedBox(height: 16),
            const Text('-OR-', style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signUpWithGoogle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(200, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network('https://www.google.com/favicon.ico', height: 16),
                  const SizedBox(width: 8),
                  const Text('Sign Up with Google'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('Already have an account? Sign in', style: TextStyle(color: Color(0xFFC5BE92))),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}