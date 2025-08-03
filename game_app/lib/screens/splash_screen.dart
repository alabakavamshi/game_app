import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    print('Rendering SplashScreen');
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Background elements
          
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animation
                  Hero(
                    tag: 'app-logo',
                    child: Lottie.asset(
                      'assets/lottie/splash_animation.json',
                      height: 200,
                      width: 200,
                      fit: BoxFit.contain,
                      repeat: false,
                      onLoaded: (composition) {
                        print('Splash Lottie loaded');
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Splash Lottie error: $error');
                        return const Icon(
                          Icons.sports_tennis,
                          color: Colors.white,
                          size: 100,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                  // App title
                  Text(
                    'SmashLive',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tagline
                  Text(
                    'Smash. Connect. Win.',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Loading indicator
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
            // Version info
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'v2.0.0',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}