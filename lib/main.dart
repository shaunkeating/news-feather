import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:html/parser.dart' show parse;
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute, kDebugMode;
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:ui';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug);
  runApp(NewsFeatherApp());
}

class NewsFeatherApp extends StatelessWidget {
  final ThemeData appTheme = ThemeData(
    scaffoldBackgroundColor: Color(0xFF000000),
    primaryColor: Color(0xFFC5BE92),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Color(0xFFF2F2F4)),
      titleLarge: TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
    ),
    dividerColor: Color(0xFF2F2F2F),
    appBarTheme: AppBarTheme(
      backgroundColor: Color(0xFF000000),
      foregroundColor: Color(0xFFF2F2F4),
      elevation: 0,
    ),
  );

  Future<void> _updateUserData(User user) async {
    String? displayName = user.displayName;
    String firstName = '';
    String lastName = '';
    if (displayName != null && displayName.isNotEmpty) {
      List<String> nameParts = displayName.trim().split(' ');
      firstName = nameParts.first;
      lastName = nameParts.length > 1 ? nameParts.last : '';
    }
    await compute(_updateUserDoc, {
      'uid': user.uid,
      'data': {
        'email': user.email,
        'email_verified': user.emailVerified,
        'firstName': firstName,
        'lastName': lastName,
      },
      'rootIsolateToken': RootIsolateToken.instance!,
    }).then((_) {
      print('Firestore update complete for ${user.uid}');
    }).catchError((error) {
      print('Firestore update failed: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'News Feather',
      theme: appTheme,
      onGenerateRoute: _generateRoute,
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.userChanges(),
        builder: (context, snapshot) {
          print('StreamBuilder: connection=${snapshot.connectionState}, hasData=${snapshot.hasData}, data=${snapshot.data}');
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return SignupScreen();
          }
          User user = snapshot.data!;
          _updateUserData(user); // Async call, doesn’t block
          return user.emailVerified ? HomeScreen() : SignupScreen();
        },
      ),
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case '/signup':
        return MaterialPageRoute(builder: (_) => SignupScreen());
      case '/verify-email':
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => VerifyEmailScreen(email: email));
      case '/home':
        return MaterialPageRoute(builder: (_) => HomeScreen());
      case '/saved':
        return MaterialPageRoute(builder: (_) => SavedStoriesScreen());
      case '/profile':
        return MaterialPageRoute(builder: (_) => ProfileSettingsScreen());
      case '/ultimate':
        return MaterialPageRoute(builder: (_) => NewsFeatherUltimateScreen());
      case '/story':
        final post = settings.arguments as Map<String, dynamic>? ?? {};
        return MaterialPageRoute(builder: (_) => StoryDetailsScreen(post: post));
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}

Future<void> _updateUserDoc(Map<String, dynamic> params) async {
  // Initialize the isolate for platform channels
  BackgroundIsolateBinaryMessenger.ensureInitialized(params['rootIsolateToken'] as RootIsolateToken);
  await Firebase.initializeApp();
  await FirebaseFirestore.instance.collection('users').doc(params['uid']).set(
    params['data'],
    SetOptions(merge: true),
  );
}

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  VerifyEmailScreen({required this.email});

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
        padding: EdgeInsets.all(16.0),
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
              SizedBox(height: 20),
              SizedBox(
                width: buttonWidth,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: creamColor,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'I’ve Verified My Email',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: buttonWidth,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _resendVerification,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: creamColor, width: 2),
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'Resend Verification Link',
                    style: TextStyle(color: creamColor),
                  ),
                ),
              ),
              SizedBox(height: 20),
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
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: CircularProgressIndicator(),
                ),
              if (_message != null)
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    _message!,
                    style: TextStyle(color: Colors.red),
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
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sign-in failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
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
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Google sign-in failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 64),
              Text(
                'News Feather',
                style: TextStyle(
                  color: Color(0xFFF2F2F4),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 32),
              TextField(
                controller: _emailController,
                style: TextStyle(color: Color(0xFFF2F2F4)),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                  filled: true,
                  fillColor: Color(0xFF2F2F2F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: TextStyle(color: Color(0xFFF2F2F4)),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                  filled: true,
                  fillColor: Color(0xFF2F2F2F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signInWithEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFC5BE92),
                  foregroundColor: Color(0xFF000000),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  minimumSize: Size(200, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Sign In with Email'),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signInWithGoogle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  minimumSize: Size(200, 0),
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
                    SizedBox(width: 8),
                    Text('Sign In with Google'),
                  ],
                ),
              ),
              SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
                child: Text(
                  'Don’t have an account? Sign up',
                  style: TextStyle(color: Color(0xFFC5BE92)),
                ),
              ),
              if (_errorMessage != null) ...[
                SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
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
        // Update Firebase Auth displayName
        String fullName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
        await user.updateDisplayName(fullName);
        await user.reload(); // Refresh user data
        user = FirebaseAuth.instance.currentUser; // Get updated user

        // Send email verification
        await user!.sendEmailVerification();
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
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 64),
            Text('Join News Feather', style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 32, fontWeight: FontWeight.bold)),
            SizedBox(height: 32),
            TextField(
              controller: _firstNameController,
              style: TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'First Name',
                labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _lastNameController,
              style: TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'Last Name',
                labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _emailController,
              style: TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              style: TextStyle(color: Color(0xFFF2F2F4)),
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              style: TextStyle(color: Color(0xFFF2F2F4)),
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: Color(0xFF2F2F2F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signUpWithEmail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFC5BE92),
                foregroundColor: Color(0xFF000000),
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(200, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Sign Up'),
            ),
            SizedBox(height: 16),
            Text('-OR-', style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 16)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signUpWithGoogle,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(200, 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network('https://www.google.com/favicon.ico', height: 16),
                  SizedBox(width: 8),
                  Text('Sign Up with Google'),
                ],
              ),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/login'),
              child: Text('Already have an account? Sign in', style: TextStyle(color: Color(0xFFC5BE92))),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: 16),
              Text(_errorMessage!, style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
            ],
            SizedBox(height: 64),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String filter = 'Week';
  StreamSubscription<QuerySnapshot>? _postsSubscription;

  DateTime _getFilterDate() {
    final now = DateTime.now();
    if (filter == 'Week') return now.subtract(Duration(days: 7));
    if (filter == 'Month') return now.subtract(Duration(days: 30));
    return now.subtract(Duration(days: 365));
  }

  @override
  void initState() {
    super.initState();
    _postsSubscription = FirebaseFirestore.instance
        .collection('wordpress_posts')
        .where('date', isGreaterThan: _getFilterDate().toIso8601String())
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snapshot) {
      // StreamBuilder handles this, so no need to setState here
    });
  }

  @override
  void dispose() {
    _postsSubscription?.cancel(); // Clean up the subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Today's Stories"),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Color(0xFFF2F2F4)),
              onPressed: () {
                print('Hamburger menu tapped');
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: Container(
          color: Color(0xFF2F2F2F),
          child: ListView(
            children: [
              ListTile(
                title: Text('Saved Stories', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () => Navigator.pushNamed(context, '/saved'),
              ),
              ListTile(
                title: Text('Profile & Settings', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
              ListTile(
                title: Text('News Feather Ultimate', style: TextStyle(color: Color(0xFFF2F2F4))),
                onTap: () => Navigator.pushNamed(context, '/ultimate'),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterButton(label: 'Week', currentFilter: filter, onTap: () => setState(() => filter = 'Week')),
                FilterButton(label: 'Month', currentFilter: filter, onTap: () => setState(() => filter = 'Month')),
                FilterButton(label: 'Year', currentFilter: filter, onTap: () => setState(() => filter = 'Year')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('wordpress_posts')
                  .where('date', isGreaterThan: _getFilterDate().toIso8601String())
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                final posts = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    return NewsModule(post: post);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FilterButton extends StatelessWidget {
  final String label;
  final String currentFilter;
  final VoidCallback onTap;

  FilterButton({required this.label, required this.currentFilter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: label == currentFilter ? Color(0xFFC5BE92) : Color(0xFF2F2F2F),
          foregroundColor: label == currentFilter ? Color(0xFF000000) : Color(0xFFF2F2F4),
        ),
        child: Text(label),
      ),
    );
  }
}

class NewsModule extends StatelessWidget {
  final Map<String, dynamic> post;

  NewsModule({required this.post});

  Future<void> _toggleSavePost(BuildContext context, bool isSaved) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;
        final ref = FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('saved_stories')
            .doc(post['id'].toString());
        
        print('Attempting to ${isSaved ? 'unsave' : 'save'} story ${post['id']} for user ${user.uid}');
        if (isSaved) {
          await ref.delete();
          print('Story ${post['id']} unsaved');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed from saved stories')),
          );
        } else {
          await ref.set(post);
          print('Story ${post['id']} saved');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Saved!')),
          );
        }
      } catch (e) {
        print('Error toggling save for story ${post['id']}: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } else {
      print('No user signed in');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to save stories')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = post['title'] ?? 'Untitled';
    String summary = post['excerpt'] != null
        ? parse(post['excerpt']).body?.text ?? 'No summary available'
        : 'No summary available';

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/story', arguments: post);
      },
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        padding: EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Color(0xFF2F2F2F),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF2F2F4),
                    ),
                  ),
                ),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('saved_stories')
                          .doc(post['id'].toString())
                          .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return IconButton(
                        icon: Icon(
                          Icons.save,
                          color: Color(0xFFC5BE92).withOpacity(0.3),
                        ),
                        onPressed: null,
                      );
                    }
                    bool isSaved = snapshot.hasData && snapshot.data!.exists;
                    return IconButton(
                      icon: Icon(
                        Icons.save,
                        color: isSaved
                            ? Color(0xFFC5BE92)
                            : Color(0xFFC5BE92).withOpacity(0.3),
                      ),
                      onPressed: () => _toggleSavePost(context, isSaved),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              summary,
              maxLines: 10,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                height: 1.5,
                color: Color(0xFFF2F2F4),
              ),
            ),
            SizedBox(height: 8),
            if (post['link'] != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'Source',
                      style: TextStyle(color: Color(0xFFC5BE92)),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class SavedStoriesScreen extends StatefulWidget {
  @override
  _SavedStoriesScreenState createState() => _SavedStoriesScreenState();
}

class _SavedStoriesScreenState extends State<SavedStoriesScreen> {
  String filter = 'Week';
  StreamSubscription<QuerySnapshot>? _storiesSubscription;

  DateTime _getFilterDate() {
    final now = DateTime.now();
    if (filter == 'Week') return now.subtract(Duration(days: 7));
    if (filter == 'Month') return now.subtract(Duration(days: 30));
    return now.subtract(Duration(days: 365));
  }

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _storiesSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_stories')
          .where('date', isGreaterThan: _getFilterDate().toIso8601String())
          .orderBy('date', descending: true)
          .snapshots()
          .listen((_) {}); // Empty listener; StreamBuilder handles updates
    }
  }

  @override
  void didUpdateWidget(SavedStoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _storiesSubscription?.cancel(); // Cancel old stream
    _setupStream(); // Rebuild stream with new filter
  }

  @override
  void dispose() {
    _storiesSubscription?.cancel(); // Clean up on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: Text('Saved Stories'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilterButton(label: 'Week', currentFilter: filter, onTap: () => setState(() => filter = 'Week')),
                FilterButton(label: 'Month', currentFilter: filter, onTap: () => setState(() => filter = 'Month')),
                FilterButton(label: 'Year', currentFilter: filter, onTap: () => setState(() => filter = 'Year')),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('saved_stories')
                      .where('date', isGreaterThan: _getFilterDate().toIso8601String())
                      .orderBy('date', descending: true)
                      .snapshots()
                  : Stream.empty(), // Empty stream if no user
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No saved stories yet',
                      style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
                    ),
                  );
                }
                final posts = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index].data() as Map<String, dynamic>;
                    return NewsModule(post: post);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsScreen extends StatefulWidget {
  @override
  _ProfileSettingsScreenState createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final String currentPlan = 'Free';
  File? _image;
  String _photoUrl = ''; // Default empty
  String _displayName = 'Loading...'; // Default
  final picker = ImagePicker();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // Bail if not logged in
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return; // Check before setState
      if (doc.exists) {
        setState(() {
          _photoUrl = doc.data()?.toString().contains('photo_url') == true ? doc['photo_url'] ?? '' : '';
          _displayName = user.displayName ??
              '${doc['firstName'] ?? ''} ${doc['lastName'] ?? ''}'.trim() ??
              user.email ??
              'Unknown';
        });
      } else {
        setState(() {
          _displayName = user.displayName ?? user.email ?? 'Unknown';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (_image == null || user == null) return;

    setState(() => _isLoading = true);
    try {
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/avatar.jpg');
      await storageRef.putFile(_image!);
      String downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'photo_url': downloadUrl}, SetOptions(merge: true));

      setState(() {
        _photoUrl = downloadUrl;
        _image = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Avatar updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update avatar: $e')),
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateEmail() async {
    TextEditingController emailController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    TextEditingController passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2F2F2F),
        title: Text('Update Email', style: TextStyle(color: Color(0xFFF2F2F4))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              style: TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'New Email',
                labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: Color(0xFF3F3F3F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Color(0xFFF2F2F4)),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Color(0xFFC5BE92)),
                filled: true,
                fillColor: Color(0xFF3F3F3F),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFFC5BE92))),
          ),
          TextButton(
            onPressed: () async {
              User? user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                setState(() => _isLoading = true);
                try {
                  AuthCredential credential = EmailAuthProvider.credential(
                    email: user.email!,
                    password: passwordController.text,
                  );
                  await user.reauthenticateWithCredential(credential);
                  await user.updateEmail(emailController.text.trim());
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set(
                    {
                      'email': emailController.text.trim(),
                      'email_verified': user.emailVerified,
                    },
                    SetOptions(merge: true),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Email updated!')),
                  );
                  await _loadUserData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update email: $e')),
                  );
                }
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text('Save', style: TextStyle(color: Color(0xFFC5BE92))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: SizedBox.shrink(),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                'Profile & Settings',
                style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Color(0xFF2F2F2F),
                                backgroundImage: _photoUrl.isNotEmpty ? NetworkImage(_photoUrl) : null,
                                child: _photoUrl.isEmpty
                                    ? Icon(Icons.person, size: 40, color: Color(0xFFF2F2F4))
                                    : null,
                              ),
                              Positioned(
                                child: Container(
                                  padding: EdgeInsets.all(4.0),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFC5BE92),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.edit, size: 16, color: Color(0xFF000000)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          _displayName,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF2F2F4)),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
                  child: Container(
                    height: 170,
                    decoration: BoxDecoration(
                      color: Color(0xFFC5BE92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Current Plan: $currentPlan',
                                  style: TextStyle(
                                    color: Color(0xFF000000),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8),
                                if (currentPlan == 'Free') ...[
                                  Text(
                                    'Upgrade to News Feather Ultimate and go ad-free',
                                    style: TextStyle(color: Color(0xFF000000)),
                                  ),
                                  SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pushNamed(context, '/ultimate'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF2F2F2F),
                                      foregroundColor: Color(0xFFF2F2F4),
                                    ),
                                    child: Text('Upgrade Now'),
                                  ),
                                ] else ...[
                                  ElevatedButton(
                                    onPressed: () => Navigator.pushNamed(context, '/ultimate'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Color(0xFF2F2F2F),
                                      foregroundColor: Color(0xFFF2F2F4),
                                    ),
                                    child: Text('Change Plan'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(right: 16.0),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: Color(0xFF2F2F2F),
                            child: Icon(Icons.image, size: 50, color: Color(0xFFF2F2F4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Padding(
                    padding: EdgeInsets.only(top: 15.0),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text('Email', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: Icon(Icons.edit, size: 16, color: Color(0xFFF2F2F4)),
                            subtitle: Text(
                              FirebaseAuth.instance.currentUser?.email ?? 'Loading...',
                              style: TextStyle(color: Color(0xFFF2F2F4)),
                            ),
                            onTap: _updateEmail,
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text('Privacy Settings', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFF2F2F4)),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Privacy settings coming soon!')),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text('Notifications Settings', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFF2F2F4)),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Notifications settings coming soon!')),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text('Dark Mode', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: Switch(
                              value: true,
                              onChanged: (value) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Theme toggle coming soon!')),
                                );
                              },
                              activeColor: Color(0xFFC5BE92),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Color(0xFF2F2F2F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text('Sign Out', style: TextStyle(color: Color(0xFFF2F2F4))),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFF2F2F4)),
                            onTap: () async {
                              await GoogleSignIn().signOut();
                              await FirebaseAuth.instance.signOut();
                              await Future.delayed(Duration(milliseconds: 100)); // Debounce
                              if (mounted) {
                                Navigator.pushReplacementNamed(context, '/login');
                              }
                            },
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

class NewsFeatherUltimateScreen extends StatelessWidget {
  final String currentPlan = 'Free';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('News Feather Ultimate'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Color(0xFFC5BE92),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    currentPlan == 'Free' ? 'Upgrade to News Feather Ultimate' : 'Your Ultimate Plan',
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ultimate subscribers are our backbone.\nGo Ultimate and see your support in action.',
                    style: TextStyle(
                      color: Color(0xFF2F2F2F),
                      fontSize: 18,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  if (currentPlan == 'Free') ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '• Unlimited ad-free news',
                          style: TextStyle(
                            color: Color(0xFF2F2F2F),
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '• Exclusive, bonus content',
                          style: TextStyle(
                            color: Color(0xFF2F2F2F),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      '\$2.99/month',
                      style: TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upgrade coming soon!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2F2F2F),
                        foregroundColor: Color(0xFFF2F2F4),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Upgrade Now',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ] else ...[
                    SizedBox(height: 16),
                    Text(
                      '\$2.99/month',
                      style: TextStyle(
                        color: Color(0xFF2F2F2F),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Change plan coming soon!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2F2F2F),
                        foregroundColor: Color(0xFFF2F2F4),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Change Plan',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Color(0xFF2F2F2F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Current Plan: $currentPlan',
                    style: TextStyle(
                      color: Color(0xFFF2F2F4),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (currentPlan == 'Free') ...[
                    SizedBox(height: 16),
                    Text(
                      '• Unlimited ad-supported news',
                      style: TextStyle(
                        color: Color(0xFFF2F2F4),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoryDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> post;

  StoryDetailsScreen({required this.post});

  @override
  Widget build(BuildContext context) {
    String title = post['title'] is String
        ? post['title']
        : post['title'] is Map
            ? post['title']['rendered'] ?? 'Untitled'
            : 'Untitled';

    String summary = post['content'] is String
        ? parse(post['content']).body?.text ?? 'No summary available'
        : post['content'] is Map
            ? parse(post['content']['rendered']).body?.text ?? 'No summary available'
            : 'No summary available';
    List<String> sentences = summary.split('. ').take(5).map((s) => '$s.').toList();
    summary = sentences.join(' ');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFF2F2F4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        children: [
          FlutterCarousel(
            options: CarouselOptions(
              height: 200.0,
              autoPlay: false,
              enlargeCenterPage: true,
              viewportFraction: 0.9,
              showIndicator: false,
            ),
            items: [1, 2, 3].map((i) => Container(
              margin: EdgeInsets.symmetric(horizontal: 8.0),
              color: Color(0xFF2F2F2F),
              child: Center(
                child: Text(
                  'Image $i',
                  style: TextStyle(color: Color(0xFFF2F2F4), fontSize: 20),
                ),
              ),
            )).toList(),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              padding: EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Color(0xFF2F2F2F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFF2F2F4),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.save, color: Color(0xFFC5BE92)),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved!')),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Color(0xFFF2F2F4),
                        fontSize: 16,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: summary.split(' ').take(5).join(' ')),
                        TextSpan(
                          text: ' Source',
                          style: TextStyle(color: Color(0xFFC5BE92)),
                          recognizer: null,
                        ),
                        TextSpan(text: ' ${summary.split(' ').skip(5).join(' ')}'),
                      ],
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