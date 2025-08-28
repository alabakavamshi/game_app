import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/auth_pages/login_page.dart';
import 'package:game_app/auth_pages/signup_page.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/firebase_options.dart';
import 'package:game_app/auth_pages/welcome_screen.dart';
import 'package:game_app/organiser_pages/organiserhomepage.dart';
import 'package:game_app/player_pages/playerhomepage.dart';
import 'package:game_app/screens/splash_screen.dart';
import 'package:game_app/umpire/umpirehomepage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  tz.initializeTimeZones();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF121212),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  await _checkAndRequestLocationPermissions();
await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: AppleProvider.appAttest
  );
  runApp(const BadmintonApp());
}

Future<void> _checkAndRequestLocationPermissions() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      debugPrint('Location permissions are denied');
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    debugPrint('Location permissions are permanently denied');
    return;
  }

  if (!await Geolocator.isLocationServiceEnabled()) {
    if (await Geolocator.openLocationSettings()) {
      debugPrint('Opened location settings');
    } else {
      debugPrint('Failed to open location settings');
    }
  }
}

class BadmintonApp extends StatelessWidget {
  const BadmintonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc()..add(AuthCheckEvent()),
      child: MaterialApp(
        title: 'Badminton Blitz',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: const Color(0xFF1A237E),
          scaffoldBackgroundColor: const Color(0xFF121212),
          textTheme: GoogleFonts.poppinsTextTheme().apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            hintStyle: const TextStyle(color: Colors.white70),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1A237E),
            elevation: 0,
          ),
        ),
        home: const InitialScreen(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginPage(),
           '/signup': (context) => const SignupPage(),
          '/player': (context) => const PlayerHomePage(),
          '/organizer': (context) => const OrganizerHomePage(),
          '/umpire': (context) => const UmpireHomePage(),
        },
      ),
    );
  }
}

class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          if (state.appUser == null) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => const ProfileCompletionScreen(),
              ),
              (route) => false,
            );
          } else {
            _navigateBasedOnRole(context, state.appUser!.role);
          }
        }
      },
      builder: (context, state) {
        if (state is AuthLoading) {
          return const SplashScreen();
        } else if (state is AuthAuthenticated) {
          if (state.appUser == null) {
            return const ProfileCompletionScreen();
          }
          return _buildHomeScreen(state.appUser!.role);
        }
        return const WelcomeScreen();
      },
    );
  }

  Widget _buildHomeScreen(String role) {
    switch (role) {
      case 'organizer':
        return const OrganizerHomePage();
      case 'umpire':
        return const UmpireHomePage();
      case 'player':
      default:
        return const PlayerHomePage();
    }
  }

  void _navigateBasedOnRole(BuildContext context, String role) {
    Widget homePage;
    switch (role) {
      case 'organizer':
        homePage = const OrganizerHomePage();
        break;
      case 'umpire':
        homePage = const UmpireHomePage();
        break;
      case 'player':
      default:
        homePage = const PlayerHomePage();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => homePage),
      (route) => false,
    );
  }
}

class ProfileCompletionScreen extends StatelessWidget {
  const ProfileCompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Please complete your profile to continue.'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const PlayerHomePage()),
                );
              },
              child: const Text('Complete Profile'),
            ),
          ],
        ),
      ),
    );
  }
}