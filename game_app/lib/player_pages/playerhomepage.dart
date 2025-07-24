import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/screens/auth_page.dart';
import 'package:game_app/player_pages/match_history_page.dart';
import 'package:game_app/screens/play_page.dart';
import 'package:game_app/screens/player_profile.dart';
import 'package:game_app/player_pages/player_stats.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:cached_network_image/cached_network_image.dart';

extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : this;
  }
}

class PlayerHomePage extends StatefulWidget {
  const PlayerHomePage({super.key});

  @override
  State<PlayerHomePage> createState() => _PlayerHomePageState();
}

class _PlayerHomePageState extends State<PlayerHomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _location = 'Hyderabad, India';
  String _userCity = 'hyderabad';
  bool _isLoadingLocation = false;
  bool _locationFetchCompleted = false;
  bool _hasNavigated = false;
  bool _showToast = false;
  String? _toastMessage;
  ToastificationType? _toastType;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _upcomingMatches = [];
  final TextEditingController _locationController = TextEditingController();
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) {
        await _getUserLocation();
      } else {
        if (mounted) {
          setState(() {
            _location = 'Hyderabad, India';
            _userCity = 'hyderabad';
            _locationFetchCompleted = true;
            _isLoadingLocation = false;
          });
        }
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
      'displayName': authState.user.email?.split('@')[0] ?? 'Player',
      'email': authState.user.email ?? '',
      'firstName': 'Player',
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
      debugPrint('No authenticated user found');
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

    final userId = authState.user.uid;
    return FirebaseFirestore.instance
        .collection('tournaments')
        .snapshots()
        .map((querySnapshot) {
      List<Map<String, dynamic>> allMatches = [];
      final now = DateTime.now();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final participants = data['participants'] as List<dynamic>? ?? [];
        final isParticipant = participants.any((p) => p is Map<String, dynamic> && p['id'] == userId);
        if (!isParticipant) continue;

        final matches = data['matches'] as List<dynamic>? ?? [];
        for (var match in matches) {
          try {
            final matchData = match as Map<String, dynamic>;
            final player1Id = matchData['player1Id']?.toString() ?? '';
            final player2Id = matchData['player2Id']?.toString() ?? '';
            final team1Ids = List<String>.from(matchData['team1Ids'] ?? []);
            final team2Ids = List<String>.from(matchData['team2Ids'] ?? []);
            final isUserMatch = player1Id == userId ||
                player2Id == userId ||
                team1Ids.contains(userId) ||
                team2Ids.contains(userId);

            if (!isUserMatch) continue;

            final matchStartTime = matchData['startTime'] != null
                ? (matchData['startTime'] as Timestamp).toDate()
                : (data['startDate'] as Timestamp).toDate();

            final isLive = (matchData['liveScores'] as Map<String, dynamic>?)?['isLive'] == true;
            final status = matchData['completed'] == true
                ? 'COMPLETED'
                : isLive
                    ? 'LIVE'
                    : matchStartTime.isAfter(now)
                        ? 'SCHEDULED'
                        : 'PAST';

            allMatches.add({
              'matchId': matchData['matchId']?.toString() ?? '',
              'tournamentId': doc.id,
              'tournamentName': data['name']?.toString() ?? 'Unnamed Tournament',
              'player1': matchData['player1']?.toString() ?? 'Unknown',
              'player2': matchData['player2']?.toString() ?? 'Unknown',
              'player1Id': player1Id,
              'player2Id': player2Id,
              'team1': List<String>.from(matchData['team1'] ?? ['Unknown']),
              'team2': List<String>.from(matchData['team2'] ?? ['Unknown']),
              'team1Ids': team1Ids,
              'team2Ids': team2Ids,
              'completed': matchData['completed'] ?? false,
              'round': matchData['round']?.toString() ?? '1',
              'startTime': matchStartTime,
              'isDoubles': matchData['team1Ids'] != null && matchData['team2Ids'] != null && matchData['team1Ids'].isNotEmpty && matchData['team2Ids'].isNotEmpty,
              'liveScores': matchData['liveScores'] ?? {'isLive': false, 'currentGame': 1},
              'location': (data['venue']?.toString().isNotEmpty == true && data['city']?.toString().isNotEmpty == true)
                  ? '${data['venue']}, ${data['city']}'
                  : data['city']?.toString() ?? 'Unknown',
              'status': status,
            });
          } catch (e) {
            debugPrint('Error processing match in tournament ${doc.id}: $e');
          }
        }
      }

      allMatches.sort((a, b) => (a['startTime'] as DateTime).compareTo(b['startTime']));
      return allMatches.take(5).toList();
    });
  }

  Color _getMatchStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return const Color(0xFFF4A261); // Accent
      case 'LIVE':
        return const Color(0xFF2A9D8F); // Success
      case 'PAST':
        return const Color(0xFF757575); // Text Secondary
      case 'COMPLETED':
        return const Color(0xFFE9C46A); // Mood Booster
      case 'CANCELLED':
        return const Color(0xFFE76F51); // Error
      default:
        return const Color(0xFF757575); // Text Secondary
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    if (kIsWeb || !mounted) return;

    setState(() {
      _isLoadingLocation = true;
      _locationFetchCompleted = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _location = 'Hyderabad, India';
            _userCity = 'hyderabad';
            _showToast = true;
            _toastMessage = 'Location services disabled';
            _toastType = ToastificationType.warning;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _location = 'Hyderabad, India';
              _userCity = 'hyderabad';
              _showToast = true;
              _toastMessage = 'Location permission denied';
              _toastType = ToastificationType.error;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _location = 'Hyderabad, India';
            _userCity = 'hyderabad';
            _showToast = true;
            _toastMessage = 'Location permission denied forever';
            _toastType = ToastificationType.error;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 5));

      if (mounted) {
        setState(() {
          _location = placemarks.isNotEmpty ? '${placemarks.first.locality ?? 'Hyderabad'}, India' : 'Hyderabad, India';
          _userCity = placemarks.isNotEmpty ? placemarks.first.locality?.toLowerCase() ?? 'hyderabad' : 'hyderabad';
          _showToast = true;
          _toastMessage = 'Location updated to $_location';
          _toastType = ToastificationType.success;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        setState(() {
          _location = 'Hyderabad, India';
          _userCity = 'hyderabad';
          _showToast = true;
          _toastMessage = 'Failed to fetch location';
          _toastType = ToastificationType.error;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationFetchCompleted = true;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _showToast = true;
          _toastMessage = 'Please enter a location';
          _toastType = ToastificationType.error;
        });
      }
      return;
    }

    try {
      final locations = await locationFromAddress(query).timeout(const Duration(seconds: 5));
      if (locations.isEmpty) {
        throw Exception('No locations found');
      }

      final location = locations.first;
      final placemarks = await placemarkFromCoordinates(location.latitude, location.longitude)
          .timeout(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _location = placemarks.isNotEmpty ? '${placemarks.first.locality ?? 'Hyderabad'}, India' : 'Hyderabad, India';
          _userCity = placemarks.isNotEmpty ? placemarks.first.locality?.toLowerCase() ?? 'hyderabad' : 'hyderabad';
          _showToast = true;
          _toastMessage = 'Location updated to $_location';
          _toastType = ToastificationType.success;
        });
      }
    } catch (e) {
      debugPrint('Search location error: $e');
      if (mounted) {
        setState(() {
          _location = 'Hyderabad, India';
          _userCity = 'hyderabad';
          _showToast = true;
          _toastMessage = 'Failed to find location';
          _toastType = ToastificationType.error;
        });
      }
    }
  }

  void _showLocationSearchDialog() {
    _locationController.clear();
    _animationController?.forward();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ScaleTransition(
            scale: _scaleAnimation!,
            child: FadeTransition(
              opacity: _fadeAnimation!,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D3557), // Deep Indigo
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Location',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFFDFCFB), // Background
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFA8DADC)), // Cool Blue Highlights
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _getUserLocation();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC1DADB).withOpacity(0.1), // Secondary
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC1DADB).withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location, color: Color(0xFFF4A261), size: 24), // Accent
                            const SizedBox(width: 12),
                            Text(
                              'Use Current Location',
                              style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB), fontSize: 16), // Background
                            ),
                            const Spacer(),
                            if (_isLoadingLocation)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261))), // Accent
                              )
                            else
                              const Icon(Icons.chevron_right, color: Color(0xFFA8DADC)), // Cool Blue Highlights
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: const Color(0xFFA8DADC).withOpacity(0.2), height: 1), // Cool Blue Highlights
                    const SizedBox(height: 16),
                    Text(
                      'Or search for a location',
                      style: GoogleFonts.poppins(color: const Color(0xFFA8DADC), fontSize: 14), // Cool Blue Highlights
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _locationController,
                      style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Enter city name',
                        hintStyle: GoogleFonts.poppins(color: const Color(0xFFA8DADC).withOpacity(0.7)), // Cool Blue Highlights
                        filled: true,
                        fillColor: const Color(0xFFC1DADB).withOpacity(0.1), // Secondary
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFA8DADC)), // Cool Blue Highlights
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFFC1DADB).withOpacity(0.1), // Secondary
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB), fontWeight: FontWeight.w500), // Background
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (_locationController.text.isNotEmpty) {
                                _searchLocation(_locationController.text);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: const Color(0xFF6C9A8B), // Primary
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Search',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: const Color(0xFFFDFCFB)), // Background
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
        );
      },
    );
  }

  Widget _buildWelcomeCard() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _userDataStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _userData == null) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))); // Accent
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading user data',
              style: GoogleFonts.poppins(color: const Color(0xFFE76F51)), // Error
            ),
          );
        }

        _userData = snapshot.data ?? _userData;
        if (_userData == null) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))); // Accent
        }

        final displayName = _userData!['firstName']?.toString().isNotEmpty == true
            ? '${StringExtension(_userData!['firstName'].toString()).capitalize()} ${_userData!['lastName']?.toString().isNotEmpty == true ? StringExtension(_userData!['lastName'].toString()).capitalize() : ''}'
            : 'Player';

        return Stack(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF), // Surface
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF333333).withOpacity(0.2), // Text Primary
                    blurRadius: 10,
                    offset: const Offset(0, 4),
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
                            color: const Color(0xFF757575), // Text Secondary
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          displayName,
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF333333), // Text Primary
                            fontSize: 20,
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
                                const Icon(Icons.sports_tennis, size: 16, color: Color(0xFFF4A261)), // Accent
                                const SizedBox(width: 8),
                                Text(
                                  '${_upcomingMatches.length} Upcoming Matches',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF757575), // Text Secondary
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
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFFC1DADB).withOpacity(0.2), // Secondary
                      backgroundImage: _userData!['profileImage']?.toString().isNotEmpty == true
                          ? (_userData!['profileImage'].toString().startsWith('http')
                              ? CachedNetworkImageProvider(_userData!['profileImage'])
                              : AssetImage(_userData!['profileImage']) as ImageProvider)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingMatches() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _upcomingMatchesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))); // Accent
        }

        if (snapshot.hasError) {
          debugPrint('Error loading upcoming matches: ${snapshot.error}');
          return Center(
            child: Text(
              'Error loading upcoming matches',
              style: GoogleFonts.poppins(color: const Color(0xFFE76F51)), // Error
            ),
          );
        }

        _upcomingMatches = snapshot.data ?? [];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF), // Surface
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF333333).withOpacity(0.2), // Text Primary
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
                      color: const Color(0xFF333333), // Text Primary
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.sports_tennis, color: Color(0xFFF4A261)), // Accent
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF757575)), // Text Secondary
                        onPressed: _initializeUserData,
                        tooltip: 'Refresh Matches',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_upcomingMatches.isEmpty)
                Column(
                  children: [
                    Text(
                      'No upcoming matches scheduled',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF757575), // Text Secondary
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _selectedIndex = 1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C9A8B), // Primary
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Find Tournaments',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFDFCFB), // Background
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              else
                ..._upcomingMatches.map((match) {
                  final matchStartTime = match['startTime'] as DateTime;
                  final authState = context.read<AuthBloc>().state;
                  final opponentName = authState is AuthAuthenticated && match['player1Id'] == authState.user.uid
                      ? match['player2']
                      : match['player1'];
                  final matchType = match['isDoubles'] ? 'Doubles' : 'Singles';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC1DADB).withOpacity(0.1), // Secondary
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getMatchStatusColor(match['status']),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Date',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFDFCFB), // Background
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                DateFormat('MMM').format(matchStartTime).toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFDFCFB), // Background
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('dd').format(matchStartTime),
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFFDFCFB), // Background
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                match['tournamentName'],
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF333333), // Text Primary
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                match['isDoubles']
                                    ? 'Team ${match['team1'].join(', ')} vs Team ${match['team2'].join(', ')}'
                                    : 'vs $opponentName',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF757575), // Text Secondary
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Color(0xFF757575)), // Text Secondary
                                  const SizedBox(width: 4),
                                  Text(
                                    match['location'],
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF757575), // Text Secondary
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                matchType,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF757575), // Text Secondary
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getMatchStatusColor(match['status']).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
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
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF), // Surface
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF333333).withOpacity(0.2), // Text Primary
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
              color: const Color(0xFF333333), // Text Primary
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickActionButton(
                icon: Icons.emoji_events,
                label: 'Tournaments',
                color: const Color(0xFFE9C46A), // Mood Booster
                onTap: () => setState(() => _selectedIndex = 1),
              ),
              _buildQuickActionButton(
                icon: Icons.history,
                label: 'Match History',
                color: const Color(0xFFE9C46A), // Mood Booster
                onTap: () async {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchHistoryPage(playerId: authState.user.uid),
                      ),
                    );
                  }
                },
              ),
              _buildQuickActionButton(
                icon: Icons.bar_chart,
                label: 'View Stats',
                color: const Color(0xFFE9C46A), // Mood Booster
                onTap: () async {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerStatsPage(userId: authState.user.uid),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
          ),
        ],
      ),
    );
  }

  Future<bool?> _showLogoutConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
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
                      style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB), fontWeight: FontWeight.w500), // Background
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: const Color(0xFFFDFCFB)), // Background
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
          ),
          description: Text(
            _toastMessage!,
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
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
        if (state is AuthUnauthenticated && !_hasNavigated && mounted) {
          _hasNavigated = true;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthPage()),
            (route) => false,
          );
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
          if (state is AuthUnauthenticated) {
            return const AuthPage();
          }

          if (state is AuthLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFFFDFCFB), // Background
              body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))), // Accent
            );
          }

          final List<Widget> pages = [
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildWelcomeCard(),
                  _buildQuickActions(),
                  _buildUpcomingMatches(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            PlayPage(userCity: _userCity, key: ValueKey(_userCity)),
            const PlayerProfilePage(),
          ];

          return WillPopScope(
            onWillPop: () async {
              if (_selectedIndex != 0) {
                setState(() => _selectedIndex = 0);
                return false;
              }
              return true;
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFFDFCFB), // Background
              appBar: _selectedIndex != 2
                  ? AppBar(
                      elevation: 0,
                      toolbarHeight: 80,
                      flexibleSpace: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C9A8B)
                        ),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SmashLive',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              color: const Color(0xFF333333), // Text Primary
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _showLocationSearchDialog,
                            child: Row(
                              children: [
                                const Icon(Icons.location_pin, color: Color(0xFF757575), size: 18), // Text Secondary
                                const SizedBox(width: 8),
                                _isLoadingLocation && !_locationFetchCompleted
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)), // Accent
                                        ),
                                      )
                                    : Flexible(
                                        child: Text(
                                          _location,
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF757575), // Text Secondary
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                const Icon(Icons.arrow_drop_down, color: Color(0xFF757575), size: 18), // Text Secondary
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.logout, color: Color(0xFF757575)), // Text Secondary
                          onPressed: () async {
                            final shouldLogout = await _showLogoutConfirmationDialog();
                            if (shouldLogout == true && mounted) {
                              context.read<AuthBloc>().add(AuthLogoutEvent());
                            }
                          },
                        ),
                      ],
                    )
                  : null,
              body: pages[_selectedIndex],
              bottomNavigationBar: BottomNavigationBar(
                backgroundColor: const Color(0xFFFFFFFF), // Surface
                selectedItemColor: const Color(0xFF6C9A8B), // Primary
                unselectedItemColor: const Color(0xFF757575), // Text Secondary
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6C9A8B), // Primary
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF757575), // Text Secondary
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home_filled),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.sports_tennis_outlined),
                    activeIcon: Icon(Icons.sports_tennis),
                    label: 'Matches',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}