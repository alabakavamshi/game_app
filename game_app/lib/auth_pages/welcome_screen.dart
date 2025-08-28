import 'package:flutter/material.dart';
import 'package:game_app/auth_pages/login_page.dart';
import 'package:game_app/auth_pages/signup_page.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Your color palette
    const Color darkBackground = Color(0xFF121212); // Dark background
    const Color primaryButtonColor = Color(0xFF6C9A8B); // Sage Green
    const Color secondaryButtonColor = Color(0xFF6C9A8B); // Sage Green (same for outline)
    const Color textColor = Colors.white; // White text for dark theme
    const Color secondaryTextColor = Color(0xFFC1DADB); // Soft Aqua for secondary text

    return Scaffold(
      backgroundColor: darkBackground, // Changed to dark background
      body: SafeArea(
        child: Stack(
          children: [
            // Centered and enlarged image (unchanged)
            const SizedBox(height: 20),
            Image.asset(
              'assets/open.png',
              height: 450, // Keeping original size
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            // Content moved to bottom (unchanged structure)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ready to compete?',
                      style: GoogleFonts.poppins(
                        color: textColor, // Changed to white
                        fontSize: 24, // Original size
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8), // Original spacing
                    Text(
                      'Lots of cool stuff happening — find tournaments, games, and exciting events near you.',
                      style: GoogleFonts.poppins(
                        color: secondaryTextColor, // Soft Aqua
                        fontSize: 14, // Original size
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40), // Original spacing

                    // Primary button - only color changed
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryButtonColor, // Sage Green
                          padding: const EdgeInsets.symmetric(vertical: 16), // Original
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // Original
                          ),
                        ),
                        child: Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            color: Colors.white, // Kept white on button
                            fontSize: 16, // Original
                            fontWeight: FontWeight.w600, // Original
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16), // Original spacing
                    
                    // Secondary button - only color changed
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16), // Original
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // Original
                          ),
                          side: BorderSide(
                            color: secondaryButtonColor, // Sage Green
                            width: 1.5, // Original
                          ),
                        ),
                        child: Text(
                          'I Have an Account',
                          style: GoogleFonts.poppins(
                            color: secondaryButtonColor, // Sage Green
                            fontSize: 16, // Original
                            fontWeight: FontWeight.w600, // Original
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20), // Original spacing
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}