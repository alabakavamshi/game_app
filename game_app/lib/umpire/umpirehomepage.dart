import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/screens/player_profile.dart';
import 'package:game_app/auth_pages/welcome_screen.dart';
import 'package:game_app/umpire/umpire_matches.dart';
import 'package:game_app/umpire/umpire_schedule.dart';
import 'package:game_app/umpire/umpire_stats.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class StringExtension {
  StringExtension(this.value);
  final String value;

  String capitalize() {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}

class UmpireHomePage extends StatefulWidget {
  const UmpireHomePage({super.key});

  @override
  State<UmpireHomePage> createState() => _UmpireHomePageState();
}

class _UmpireHomePageState extends State<UmpireHomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _location = 'Hyderabad, India';
  String _userCity = 'hyderabad';
  Position? _lastPosition;
  final TextEditingController _locationController = TextEditingController();
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  Animation<double>? _fadeAnimation;
  bool _showToast = false;
  String? _toastMessage;
  ToastificationType? _toastType;
  bool _hasNavigated = false;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _upcomingMatches = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(authState.user.uid);
        userDocRef.get().then((userDoc) {
          if (userDoc.exists && userDoc.data()?['city']?.toString().isNotEmpty == true) {
            if (mounted) {
              setState(() {
                _userCity = userDoc.data()!['city'].toString().toLowerCase();
                _location = '${StringExtension(_userCity).capitalize()}, India';
              });
            }
          } else if (!kIsWeb) {
            _getUserLocation();
          } else {
            if (mounted) {
              setState(() {
                _location = 'Hyderabad, India';
                _userCity = 'hyderabad';
              });
            }
          }
        });
      }
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOutQuint),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
    _animationController?.forward();
  }

  Future<void> _initializeUserData() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(authState.user.uid);
    final userDoc = await userDocRef.get();

    final defaultUser = {
      'createdAt': Timestamp.now(),
      'displayName': authState.user.email?.split('@')[0] ?? 'Umpire',
      'email': authState.user.email ?? '',
      'firstName': 'Umpire',
      'lastName': '',
      'gender': 'unknown',
      'phone': '',
      'profileImage': '',
      'city': _userCity.isNotEmpty ? _userCity : 'hyderabad',
      'updatedAt': Timestamp.now(),
    };

    if (!userDoc.exists) {
      await userDocRef.set(defaultUser);
      if (mounted) {
        setState(() => _userData = defaultUser);
      }
    } else {
      if (mounted) {
        setState(() => _userData = userDoc.data() ?? defaultUser);
      }
    }
  }

  Stream<Map<String, dynamic>?> _userDataStream() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return Stream.value(null);
    }
    return FirebaseFirestore.instance
        .collection('users')
        .doc(authState.user.uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Stream<List<Map<String, dynamic>>> _upcomingMatchesStream() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      debugPrint('No authenticated user found');
      return Stream.value([]);
    }

    final umpireEmail = authState.user.email?.toLowerCase().trim();
    debugPrint('Authenticated umpire email: $umpireEmail');

    return FirebaseFirestore.instance
        .collection('tournaments')
        .snapshots()
        .map((querySnapshot) {
      List<Map<String, dynamic>> upcomingMatches = [];
      final now = DateTime.now();
      debugPrint('Fetched ${querySnapshot.docs.length} tournaments');

      for (var tournamentDoc in querySnapshot.docs) {
        final tournamentData = tournamentDoc.data();
        final matches = tournamentData['matches'] as List<dynamic>? ?? [];
        debugPrint('Tournament ${tournamentDoc.id}: ${matches.length} matches');

        for (var match in matches) {
          try {
            final matchData = match as Map<String, dynamic>;
            if (matchData['completed'] == true) {
              debugPrint('Skipping completed match: ${matchData['matchId']}');
              continue;
            }

            String? matchUmpireEmail;
            if (matchData['umpire'] is Map<String, dynamic>?) {
              final matchUmpire = matchData['umpire'] as Map<String, dynamic>?;
              matchUmpireEmail = (matchUmpire?['email'] as String?)?.toLowerCase().trim();
            } else if (matchData['umpireEmail'] is String?) {
              matchUmpireEmail = (matchData['umpireEmail'] as String?)?.toLowerCase().trim();
            }

            if (matchUmpireEmail == null) {
              debugPrint('No umpire assigned for match: ${matchData['matchId']}');
              continue;
            }

            if (matchUmpireEmail != umpireEmail) {
              debugPrint('Match ${matchData['matchId']} assigned to different umpire: $matchUmpireEmail');
              continue;
            }

            final matchStartTime = matchData['startTime'] as Timestamp?;
            if (matchStartTime == null) {
              debugPrint('No startTime for match: ${matchData['matchId']}');
              continue;
            }

            final matchTime = matchStartTime.toDate();
            final isLive = (matchData['liveScores'] as Map<String, dynamic>?)?['isLive'] == true;
            final status = isLive
                ? 'LIVE'
                : matchTime.isAfter(now)
                    ? 'SCHEDULED'
                    : 'PAST';

            debugPrint('Processing match: ${matchData['matchId']}, isLive: $isLive, startTime: $matchTime, status: $status');
            upcomingMatches.add({
              'id': matchData['matchId'] as String? ?? 'match_${tournamentDoc.id}_${matches.indexOf(match)}',
              'tournamentId': tournamentDoc.id,
              'name': '${tournamentData['name'] as String? ?? 'Tournament'} - ${matchData['matchId'] ?? 'Match ${matches.indexOf(match) + 1}'}',
              'startDate': matchStartTime,
              'location': (tournamentData['venue'] as String?)?.isNotEmpty == true && (tournamentData['city'] as String?)?.isNotEmpty == true
                  ? '${tournamentData['venue']}, ${tournamentData['city']}'
                  : tournamentData['city'] as String? ?? 'Unknown venue',
              'status': status,
              'player1Id': matchData['player1Id'] as String? ?? 'Unknown',
              'player2Id': matchData['player2Id'] as String? ?? 'Unknown',
              'isDoubles': matchData['isDoubles'] ?? false,
              'tournamentName': tournamentData['name'] as String? ?? 'Unknown Tournament',
            });
          } catch (e) {
            debugPrint('[ERROR] Processing match in stream: $e');
          }
        }
      }
      debugPrint('Upcoming matches count: ${upcomingMatches.length}');
      return upcomingMatches.take(5).toList();
    });
  }

  Future<List<Map<String, String>>> _fetchPlayerNames(List<Map<String, dynamic>> matches) async {
    final List<Map<String, String>> playerNames = [];
    final Set<String> uniqueIds = {};

    for (var match in matches) {
      final player1Id = match['player1Id'] as String?;
      final player2Id = match['player2Id'] as String?;
      if (player1Id != null && player1Id != 'Unknown') uniqueIds.add(player1Id);
      if (player2Id != null && player2Id != 'Unknown') uniqueIds.add(player2Id);
    }

    if (uniqueIds.isEmpty) {
      debugPrint('No unique player IDs to fetch');
      return playerNames;
    }

    debugPrint('Fetching player names for IDs: $uniqueIds');
    final userDocs = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: uniqueIds.toList())
        .get();

    for (var doc in userDocs.docs) {
      final data = doc.data();
      final name = '${data['firstName'] ?? 'Unknown'} ${data['lastName'] ?? ''}'.trim();
      playerNames.add({
        'id': doc.id,
        'name': name.isEmpty ? 'Unknown Player' : name,
      });
      debugPrint('Fetched player: ${doc.id} - $name');
    }

    return playerNames;
  }

  Color _getMatchStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return const Color(0xFFF4A261); // Accent
      case 'LIVE':
        return const Color(0xFF2A9D8F); // Success
      case 'PAST':
        return const Color(0xFFE9C46A); // Mood Booster
      case 'COMPLETED':
        return const Color(0xFFE9C46A); // Mood Booster
      case 'CANCELLED':
        return const Color(0xFFE76F51); // Error
      default:
        return const Color(0xFF757575); // Text - Secondary
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    if (!mounted || kIsWeb) return;

    setState(() {
    });

    try {
      if (_lastPosition == null) {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          _lastPosition = lastPosition;
          await _updateLocationFromPosition(lastPosition);
          return;
        }
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await _handleLocationServiceDisabled();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _handlePermissionDenied();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _handlePermissionDeniedForever();
        return;
      }

      Position? position;
      bool success = false;
      int attempts = 0;
      const int maxAttempts = 3;

      while (!success && attempts < maxAttempts) {
        attempts++;
        try {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          );
          success = true;
        } on TimeoutException {
          if (attempts == maxAttempts) {
            throw TimeoutException('Location fetch timed out after $maxAttempts attempts');
          }
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (position != null) {
        _lastPosition = position;
        await _updateLocationFromPosition(position);
      } else {
        throw Exception('Failed to get location after $maxAttempts attempts');
      }

      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && mounted) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authState.user.uid)
            .update({'city': _userCity});
      }

      if (mounted) {
        setState(() {
          _showToast = true;
          _toastMessage = 'Location updated to $_location';
          _toastType = ToastificationType.success;
        });
      }
    } on TimeoutException {
      _handleLocationTimeout();
    } catch (e) {
      _handleLocationError(e);
    } finally {
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  Future<void> _updateLocationFromPosition(Position position) async {
    if (!mounted) return;

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        if (mounted) {
          setState(() {
            _location = '${place.locality ?? 'Hyderabad'}, ${place.country ?? 'India'}';
            _userCity = place.locality?.toLowerCase() ?? 'hyderabad';
          });
        }
        return;
      }

      final fallbackPlacemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 3));

      if (fallbackPlacemarks.isNotEmpty) {
        final place = fallbackPlacemarks.first;
        if (mounted) {
          setState(() {
            _location = '${place.locality ?? 'Hyderabad'}, ${place.country ?? 'India'}';
            _userCity = place.locality?.toLowerCase() ?? 'hyderabad';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _location = 'Hyderabad, India';
            _userCity = 'hyderabad';
          });
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
      if (mounted) {
        setState(() {
          _location = 'Hyderabad, India';
          _userCity = 'hyderabad';
        });
      }
    }
  }

  Future<void> _handleLocationServiceDisabled() async {
    if (!mounted) return;

    final opened = await Geolocator.openLocationSettings();
    if (opened) {
      await Future.delayed(const Duration(seconds: 2));
      await _getUserLocation();
    } else {
      if (mounted) {
        setState(() {
          _location = 'Hyderabad, India';
          _userCity = 'hyderabad';
          _showToast = true;
          _toastMessage = 'Please enable location services manually.';
          _toastType = ToastificationType.warning;
        });
      }
    }
  }

  void _handlePermissionDenied() {
    if (!mounted) return;
    _showPermissionDeniedDialog();
  }

  void _handlePermissionDeniedForever() {
    if (!mounted) return;
    _showPermissionDeniedForeverDialog();
  }

  void _handleLocationTimeout() {
    if (mounted) {
      setState(() {
        _location = 'Hyderabad, India';
        _userCity = 'hyderabad';
        _showToast = true;
        _toastMessage = 'Could not fetch location quickly. Using default: Hyderabad.';
        _toastType = ToastificationType.warning;
      });
    }
  }

  void _handleLocationError(dynamic e) {
    debugPrint('Location error: $e');
    if (mounted) {
      setState(() {
        _location = 'Hyderabad, India';
        _userCity = 'hyderabad';
        _showToast = true;
        _toastMessage = 'Failed to fetch location: ${e.toString()}. Using default: Hyderabad.';
        _toastType = ToastificationType.error;
      });
    }
  }


  Future<bool?> _showLogoutConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: _scaleAnimation!,
          child: FadeTransition(
            opacity: _fadeAnimation!,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1D3557), // Deep Indigo
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA8DADC).withOpacity(0.7)), // Cool Blue Highlights
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confirm Logout',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFDFCFB), // Background
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Are you sure you want to logout?',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFA8DADC), // Cool Blue Highlights
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          backgroundColor: const Color(0xFFC1DADB).withOpacity(0.1), // Secondary
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFDFCFB), // Background
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          backgroundColor: const Color(0xFFE76F51), // Error
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFFDFCFB), // Background
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF), // Surface
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Location Permission Denied',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333), // Text - Primary
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This app needs location permission to fetch your current location. Please enable it in settings.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF757575), // Text - Secondary
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFF757575), // Text - Secondary
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: Text(
              'Enable',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C9A8B), // Primary
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF), // Surface
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Location Permission Denied Forever',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333), // Text - Primary
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Location permission has been permanently denied. You can enable it in app settings.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF757575), // Text - Secondary
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFF757575), // Text - Secondary
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            child: Text(
              'Enable',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C9A8B), // Primary
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserWelcomeCard() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userDataStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _userData == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))); // Accent
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading user data',
              style: GoogleFonts.poppins(
                color: const Color(0xFFE76F51), // Error
              ),
            ),
          );
        }

        _userData = snapshot.data ?? _userData;
        if (_userData == null) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))); // Accent
        }

        final displayName = _userData!['firstName']?.toString().isNotEmpty == true
            ? '${StringExtension(_userData!['firstName'].toString()).capitalize()} ${_userData!['lastName']?.toString().isNotEmpty == true ? StringExtension(_userData!['lastName'].toString()).capitalize() : ''}'
            : 'Umpire';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C9A8B), Color(0xFF5A8A7A)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF333333).withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back,',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _upcomingMatchesStream(),
                      builder: (context, matchesSnapshot) {
                        if (matchesSnapshot.hasData) {
                          _upcomingMatches = matchesSnapshot.data!;
                        }
                        return Row(
                          children: [
                            const Icon(Icons.sports_tennis, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              '${_upcomingMatches.length} Upcoming Matches',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedIndex = 2),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    backgroundImage: _userData!['profileImage']?.toString().isNotEmpty == true
                        ? (_userData!['profileImage'].toString().startsWith('http')
                            ? CachedNetworkImageProvider(_userData!['profileImage'])
                            : AssetImage(_userData!['profileImage']) as ImageProvider)
                        : const AssetImage('assets/logo.png') as ImageProvider,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingMatches() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _upcomingMatchesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))); // Accent
        }
        if (snapshot.hasError) {
          debugPrint('Snapshot error: ${snapshot.error}');
          return Center(
            child: Text(
              'Error loading matches',
              style: GoogleFonts.poppins(
                color: const Color(0xFFE76F51), // Error
              ),
            ),
          );
        }
        _upcomingMatches = snapshot.data ?? [];
        debugPrint('Upcoming matches: $_upcomingMatches');

        return FutureBuilder<List<Map<String, String>>>(
          future: _fetchPlayerNames(_upcomingMatches),
          builder: (context, playerNamesSnapshot) {
            if (playerNamesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))); // Accent
            }
            if (playerNamesSnapshot.hasError || !playerNamesSnapshot.hasData) {
              debugPrint('Player names error: ${playerNamesSnapshot.error}');
              return Center(
                child: Text(
                  'Error loading player names',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE76F51), // Error
                  ),
                ),
              );
            }

            final playerNames = playerNamesSnapshot.data ?? [];
            final playerNameMap = {for (var p in playerNames) p['id']!: p['name']!};
            debugPrint('Player name map: $playerNameMap');

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF333333).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Matches',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF333333),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C9A8B).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sports_tennis,
                          color: Color(0xFF6C9A8B),
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_upcomingMatches.isEmpty)
                    Column(
                      children: [
                        Text(
                          'No matches assigned',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF757575),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() => _selectedIndex = 1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C9A8B),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'View Matches',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ..._upcomingMatches.map((match) {
                      final startDate = (match['startDate'] as Timestamp).toDate();
                      final player1Id = match['player1Id'] as String?;
                      final player2Id = match['player2Id'] as String?;
                      final player1Name = playerNameMap[player1Id] ?? player1Id ?? 'Unknown Player';
                      final player2Name = playerNameMap[player2Id] ?? player2Id ?? 'Unknown Player';
                      final tournamentName = match['tournamentName'] as String? ?? 'Unknown Tournament';
                      debugPrint('Match: $match, Player1: $player1Name, Player2: $player2Name, Tournament: $tournamentName');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE9ECEF),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: _getMatchStatusColor(match['status']),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getMatchStatusColor(match['status']).withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Date',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM').format(startDate).toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd').format(startDate),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tournamentName,
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF333333),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Color(0xFF6C757D),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              match['location'] as String,
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF6C757D),
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        match['isDoubles'] ? 'Doubles' : 'Singles',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF6C757D),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              player1Name,
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF333333),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'vs',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF6C757D),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              player2Name,
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF333333),
                                                fontSize: 14,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _getMatchStatusColor(match['status']).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getMatchStatusColor(match['status']).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    match['status'].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: _getMatchStatusColor(match['status']),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF333333).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              color: const Color(0xFF333333),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionButton(
                icon: Icons.sports_tennis,
                label: 'Matches',
                color: const Color(0xFF6C9A8B),
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildQuickActionButton(
                icon: Icons.schedule,
                label: 'Schedule',
                color: const Color(0xFFF4A261),
                onTap: () async {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UmpireSchedulePage(
                          userId: authState.user.uid,
                          userEmail: authState.user.email ?? '',
                        ),
                      ),
                    );
                  }
                },
              ),
              _buildQuickActionButton(
                icon: Icons.bar_chart,
                label: 'Stats',
                color: const Color(0xFF2A9D8F),
                onTap: () async {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UmpireStatsPage(
                          userId: authState.user.uid,
                          userEmail: authState.user.email ?? '',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFF333333),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index < 0 || index >= 3) {
      debugPrint('Invalid index: $index');
      return;
    }
    if (mounted) {
      setState(() => _selectedIndex = index);
    }
    debugPrint('Selected tab: $index');
  }

  @override
  Widget build(BuildContext context) {
    if (_showToast && _toastMessage != null && _toastType != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        toastification.show(
          context: context,
          type: _toastType!,
          title: Text(
            _toastType == ToastificationType.success
                ? 'Success'
                : _toastType == ToastificationType.error
                    ? 'Error'
                    : 'Info',
            style: GoogleFonts.poppins(
              color: const Color(0xFFFDFCFB), // Background
            ),
          ),
          description: Text(
            _toastMessage!,
            style: GoogleFonts.poppins(
              color: const Color(0xFFFDFCFB), // Background
            ),
          ),
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: _toastType == ToastificationType.success
              ? const Color(0xFF2A9D8F) // Success
              : _toastType == ToastificationType.error
                  ? const Color(0xFFE76F51) // Error
                  : const Color(0xFFF4A261), // Accent
          foregroundColor: const Color(0xFFFDFCFB), // Background
          alignment: Alignment.bottomCenter,
        );
        if (mounted) {
          setState(() {
            _showToast = false;
            _toastMessage = null;
            _toastType = null;
          });
        }
      });
    }

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        debugPrint('UmpireHomePage Auth state: $state');
        if (state is AuthUnauthenticated && mounted && !_hasNavigated) {
          _hasNavigated = true;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
          debugPrint('Navigated to AuthPage due to unauthenticated state');
        } else if (state is AuthError && mounted) {
          setState(() {
            _showToast = true;
            _toastMessage = state.message;
            _toastType = ToastificationType.error;
          });
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          debugPrint('Building UmpireHomePage with state: $state');
          if (state is AuthUnauthenticated) {
            return const WelcomeScreen();
          }

          if (state is AuthLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFFF8F9FA),
              body: Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))),
            );
          }

          final List<Widget> pages = [
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildUserWelcomeCard(),
                  _buildQuickActions(),
                  _buildUpcomingMatches(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            const UmpireMatchesPage(),
            const PlayerProfilePage(),
          ];

          return WillPopScope(
            onWillPop: () async {
              if (_selectedIndex != 0) {
                if (mounted) {
                  setState(() => _selectedIndex = 0);
                }
                return false;
              }
              return true;
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFF8F9FA),
              appBar: _selectedIndex == 0
                ? AppBar(
                    elevation: 0,
                    toolbarHeight: 80,
                    backgroundColor: Colors.white,
                    flexibleSpace: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6C9A8B), Color(0xFF5A8A7A)],
                        ),
                      ),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SmashLive Umpire',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                       
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.logout,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        onPressed: () async {
                          if (state is AuthAuthenticated && mounted) {
                            final shouldLogout = await _showLogoutConfirmationDialog();
                            if (shouldLogout == true) {
                              context.read<AuthBloc>().add(AuthLogoutEvent());
                              setState(() {
                                _showToast = true;
                                _toastMessage = 'You have been logged out successfully.';
                                _toastType = ToastificationType.success;
                              });
                              debugPrint('User logged out');
                            }
                          } else if (mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  )
                : _selectedIndex == 1
                    ? AppBar(
                        backgroundColor: const Color(0xFF6C9A8B),
                        elevation: 0,
                        title: Text(
                          'My Officiating Schedule',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF333333),
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        centerTitle: true,
                      )
                    : null,
              body: pages[_selectedIndex],
              bottomNavigationBar: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BottomNavigationBar(
                    backgroundColor: Colors.white,
                    selectedItemColor: const Color(0xFF6C9A8B),
                    unselectedItemColor: const Color(0xFF9E9E9E),
                    currentIndex: _selectedIndex,
                    onTap: _onItemTapped,
                    type: BottomNavigationBarType.fixed,
                    elevation: 0,
                    selectedLabelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    items: [
                      BottomNavigationBarItem(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 0 
                                ? const Color(0xFF6C9A8B).withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedIndex == 0 
                                ? Icons.home_filled 
                                : Icons.home_outlined,
                            size: 24,
                          ),
                        ),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 1 
                                ? const Color(0xFF6C9A8B).withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedIndex == 1 
                                ? Icons.sports_tennis 
                                : Icons.sports_tennis_outlined,
                            size: 24,
                          ),
                        ),
                        label: 'Matches',
                      ),
                      BottomNavigationBarItem(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 2 
                                ? const Color(0xFF6C9A8B).withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedIndex == 2 
                                ? Icons.person 
                                : Icons.person_outline,
                            size: 24,
                          ),
                        ),
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MatchDetailsPage extends StatelessWidget {
  final String matchId;
  final String tournamentId;

  const MatchDetailsPage({super.key, required this.matchId, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Match Details',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFFDFCFB),
      ),
      body: Center(
        child: Text(
          'Match ID: $matchId\nTournament ID: $tournamentId',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333),
          ),
        ),
      ),
    );
  }
}