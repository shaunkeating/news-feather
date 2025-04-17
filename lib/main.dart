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
        return SlidePageRoute(page: const SavedStoriesScreen());
      case '/profile':
        return SlidePageRoute(page: const ProfileSettingsScreen());
      case '/ultimate':
        return SlidePageRoute(page: const NewsFeatherUltimateScreen());
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

class SlidePageRoute extends PageRouteBuilder {
  final Widget page;

  SlidePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(-1.0, 0.0); // Slide from left
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionDuration: const Duration(milliseconds: 300),
        );
}