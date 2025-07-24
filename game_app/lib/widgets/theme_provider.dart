import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThemeProvider with ChangeNotifier {
  String _themeMode = 'light'; // Default theme
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ThemeProvider() {
    _loadTheme();
  }

  String get themeMode => _themeMode;

  ThemeData get themeData {
    switch (_themeMode) {
      case 'dark':
        return ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.grey[900]!,
          scaffoldBackgroundColor: Colors.grey[850]!,
          cardColor: Colors.grey[800]!,
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
            bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
            headlineSmall: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
        );
      case 'custom':
        return ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF1A237E),
          scaffoldBackgroundColor: Colors.transparent,
          cardColor: Colors.white.withOpacity(0.1),
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
            bodyMedium: TextStyle(color: Colors.white70, fontSize: 16),
            headlineSmall: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
        );
      case 'light':
      default:
        return ThemeData(
          brightness: Brightness.light,
          primaryColor: Colors.blue[700]!,
          scaffoldBackgroundColor: Colors.white,
          cardColor: Colors.grey[200]!,
          textTheme: const TextTheme(
            bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
            bodyMedium: TextStyle(color: Colors.black54, fontSize: 16),
            headlineSmall: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        );
    }
  }

  Future<void> _loadTheme() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!['themeMode'] != null) {
        _themeMode = doc.data()!['themeMode'];
      }
    }
    notifyListeners();
  }

  Future<void> setTheme(String mode) async {
    _themeMode = mode;
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'themeMode': mode,
      });
    }
    notifyListeners();
  }
}