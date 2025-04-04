import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_screens.dart';
import 'home_screen.dart';
import 'saved_stories_screen.dart';
import 'profile_settings_screen.dart';
import 'ultimate_screen.dart';
import 'story_details_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.debug);
  runApp(NewsFeatherApp());
}

class NewsFeatherApp extends StatelessWidget {
  final ThemeData appTheme = ThemeData(
    scaffoldBackgroundColor: const Color(0xFF000000),
    primaryColor: const Color(0xFFC5BE92),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Color(0xFFF2F2F4)),
      titleLarge: TextStyle(color: Color(0xFFF2F2F4), fontSize: 18),
    ),
    dividerColor: const Color(0xFF2F2F2F),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF000000),
      foregroundColor: Color(0xFFF2F2F4),
      elevation: 0,
    ),
  );

  NewsFeatherApp({super.key});

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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return SignupScreen();
          }
          User user = snapshot.data!;
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