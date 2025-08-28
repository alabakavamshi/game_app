import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/organiser_pages/manage_players_page.dart';
import 'package:game_app/screens/play_page.dart' show PlayPage;
import 'package:game_app/screens/player_profile.dart';
import 'package:game_app/organiser_pages/schedule_page.dart';
import 'package:game_app/auth_pages/welcome_screen.dart';
import 'package:game_app/tournaments/history_page.dart';
import 'package:game_app/tournaments/tournamnet_create.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

// Extension for string capitalization
extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : this;
  }
}

class OrganizerHomePage extends StatefulWidget {
  final bool showLocationDialog;
  final bool returnToPlayPage;

  const OrganizerHomePage({
    super.key,
    this.showLocationDialog = false,
    this.returnToPlayPage = false,
  });

  @override
  State<OrganizerHomePage> createState() => _OrganizerHomePageState();
}

class _OrganizerHomePageState extends State<OrganizerHomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  String _location = 'Hyderabad, India';
  String _userCity = 'hyderabad';
  bool _isLoadingLocation = false;
  bool _locationFetchCompleted = false;
  bool _shouldReturnToPlayPage = false;
  bool _hasNavigated = false;
  bool _showToast = false;
  String? _toastMessage;
  ToastificationType? _toastType;
  List<Map<String, dynamic>> _upcomingTournaments = [];
  Map<String, dynamic>? _userData;
  final TextEditingController _locationController = TextEditingController();
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    _initializeAnimations();
    _shouldReturnToPlayPage = widget.returnToPlayPage;
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
        if (widget.showLocationDialog) {
          _showLocationSearchDialog();
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
      'displayName': authState.user.email?.split('@')[0] ?? 'Organizer',
      'email': authState.user.email ?? '',
      'firstName': 'Organizer',
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

  Stream<List<Map<String, dynamic>>> _upcomingTournamentsStream() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('tournaments')
        .where('createdBy', isEqualTo: authState.user.uid)
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .orderBy('startDate', descending: false)
        .limit(5)
        .snapshots()
        .map((querySnapshot) {
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        final startTimeData = data['startTime'] as Map<String, dynamic>? ?? {'hour': 0, 'minute': 0};
        return {
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unnamed Tournament',
          'startDate': data['startDate'] ?? Timestamp.now(),
          'endDate': data['endDate'] ?? Timestamp.now(),
          'startTime': TimeOfDay(
            hour: startTimeData['hour'] as int? ?? 0,
            minute: startTimeData['minute'] as int? ?? 0,
          ),
          'location': (data['venue']?.toString().isNotEmpty == true &&
                  data['city']?.toString().isNotEmpty == true)
              ? '${data['venue']}, ${data['city']}'
              : 'Unknown',
          'status': data['status']?.toString() ?? 'open',
          'participantCount': (data['participants'] as List?)?.length ?? 0,
          'entryFee': (data['entryFee'] as num?)?.toDouble() ?? 0.0,
          'maxParticipants': data['maxParticipants']?.toInt() ?? 0,
          'createdBy': data['createdBy']?.toString() ?? '',
        };
      }).toList();
    });
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

      if (mounted && placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? '';
        final country = placemark.country ?? '';
        setState(() {
          _location = country.isNotEmpty ? '$city, $country' : city;
          _userCity = city.isNotEmpty ? city.toLowerCase() : 'hyderabad';
          _showToast = true;
          _toastMessage = city.isNotEmpty ? 'Location updated to $_location' : 'Unable to determine city';
          _toastType = city.isNotEmpty ? ToastificationType.success : ToastificationType.warning;
        });
      } else {
        if (mounted) {
          setState(() {
            _location = 'Hyderabad, India';
            _userCity = 'hyderabad';
            _showToast = true;
            _toastMessage = 'Unable to determine location';
            _toastType = ToastificationType.error;
          });
        }
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
          _toastMessage = 'Please enter a city name';
          _toastType = ToastificationType.error;
        });
      }
      return;
    }

    try {
      final locations = await locationFromAddress(query).timeout(const Duration(seconds: 5));
      if (locations.isNotEmpty) {
        final placemarks = await placemarkFromCoordinates(locations.first.latitude, locations.first.longitude)
            .timeout(const Duration(seconds: 3));
        if (mounted && placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final city = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.administrativeArea ?? query;
          final country = placemark.country ?? '';
          setState(() {
            _location = country.isNotEmpty ? '$city, $country' : city;
            _userCity = city.toLowerCase();
            _showToast = true;
            _toastMessage = 'Location set to $_location';
            _toastType = ToastificationType.success;
          });
        } else {
          if (mounted) {
            setState(() {
              _location = query;
              _userCity = query.toLowerCase();
              _showToast = true;
              _toastMessage = 'Location set to $_location';
              _toastType = ToastificationType.success;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _location = query;
            _userCity = query.toLowerCase();
            _showToast = true;
            _toastMessage = 'Location set to $_location';
            _toastType = ToastificationType.success;
          });
        }
      }
    } catch (e) {
      debugPrint('Search location error: $e');
      if (mounted) {
        setState(() {
          _location = query;
          _userCity = query.toLowerCase();
          _showToast = true;
          _toastMessage = 'Location set to $_location';
          _toastType = ToastificationType.success;
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
                          onPressed: () {
                            Navigator.pop(context);
                            if (_shouldReturnToPlayPage && mounted) {
                              setState(() {
                                _selectedIndex = 2;
                                _shouldReturnToPlayPage = false;
                              });
                            }
                          },
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)),
                                ),
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
                            onPressed: () {
                              Navigator.pop(context);
                              if (_shouldReturnToPlayPage && mounted) {
                                setState(() {
                                  _selectedIndex = 2;
                                  _shouldReturnToPlayPage = false;
                                });
                              }
                            },
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
            : 'Organizer';

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
                color: const Color(0xFF333333).withOpacity(0.2), // Text Primary
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
                      stream: _upcomingTournamentsStream(),
                      builder: (context, tournamentsSnapshot) {
                        if (tournamentsSnapshot.hasData) {
                          _upcomingTournaments = tournamentsSnapshot.data!;
                        }
                        return Row(
                          children: [
                            const Icon(Icons.emoji_events, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              '${_upcomingTournaments.length} Upcoming Tournaments',
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
                onTap: () => setState(() => _selectedIndex = 3),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
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

  Widget _buildUpcomingTournaments() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _upcomingTournamentsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))); // Accent
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading tournaments',
              style: GoogleFonts.poppins(color: const Color(0xFFE76F51)), // Error
            ),
          );
        }

        _upcomingTournaments = snapshot.data ?? [];

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
                    'Your Tournaments',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF333333),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C9A8B).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Color(0xFF6C9A8B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF6C9A8B)),
                        onPressed: _initializeUserData,
                        tooltip: 'Refresh Tournaments',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_upcomingTournaments.isEmpty)
                Column(
                  children: [
                    Text(
                      'No upcoming tournaments created yet',
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Create Tournament',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              else
                ..._upcomingTournaments.map((tournament) {
                  final startDate = (tournament['startDate'] as Timestamp).toDate();
                  (tournament['endDate'] as Timestamp).toDate();
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getTournamentStatusColor(tournament['status']),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: _getTournamentStatusColor(tournament['status']).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Start Date',
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
                                tournament['name'],
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF333333),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 14, color: Color(0xFF6C757D)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      tournament['location'],
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF6C757D),
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Entry: ₹${tournament['entryFee'].toStringAsFixed(0)}',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF6C757D),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getTournamentStatusColor(tournament['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getTournamentStatusColor(tournament['status']).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            tournament['status'].toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: _getTournamentStatusColor(tournament['status']),
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

  Color _getTournamentStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return const Color(0xFFF4A261); // Accent
      case 'ongoing':
        return const Color(0xFF2A9D8F); // Success
      case 'completed':
        return const Color(0xFFE9C46A); // Mood Booster
      case 'cancelled':
        return const Color(0xFFE76F51); // Error
      default:
        return const Color(0xFF757575); // Text Secondary
    }
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
                icon: Icons.history,
                label: 'History',
                color: const Color(0xFFF4A261),
                onTap: () async {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TournamentHistoryPage(userId: authState.user.uid),
                      ),
                    );
                  }
                },
              ),
              _buildQuickActionButton(
                icon: Icons.people,
                label: 'Manage Players',
                color: const Color(0xFF2A9D8F),
                onTap: () async {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManagePlayersPage(userId: authState.user.uid),
                      ),
                    );
                  }
                },
              ),
              _buildQuickActionButton(
                icon: Icons.schedule,
                label: 'Schedule',
                color: const Color(0xFFE9C46A),
                onTap: () async {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is AuthAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SchedulePage(userId: authState.user.uid),
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
    if (index < 0 || index >= 4) {
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
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          description: Text(
            _toastMessage!,
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: _toastType == ToastificationType.success
              ? const Color(0xFF2A9D8F)
              : _toastType == ToastificationType.error
                  ? const Color(0xFFE76F51)
                  : const Color(0xFFF4A261),
          foregroundColor: const Color(0xFFFDFCFB),
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
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
            return const WelcomeScreen();
          }

          if (state is AuthLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFFF8F9FA),
              body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))),
            );
          }

          final List<Widget> pages = [
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildWelcomeCard(),
                  _buildQuickActions(),
                  _buildUpcomingTournaments(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            state is AuthAuthenticated
                ? CreateTournamentPage(
                    userId: state.user.uid,
                    onBackPressed: () => setState(() => _selectedIndex = 0),
                    onTournamentCreated: () {
                      if (mounted) {
                        setState(() {
                          _selectedIndex = 2;
                        });
                      }
                    },
                  )
                : const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))),
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
              backgroundColor: const Color(0xFFF8F9FA),
              appBar: _selectedIndex != 3
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
                            'SmashLive',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: _showLocationSearchDialog,
                            child: Row(
                              children: [
                                const Icon(Icons.location_pin, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                _isLoadingLocation && !_locationFetchCompleted
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Flexible(
                                        child: Text(
                                          _location.isNotEmpty ? _location : 'Select a location',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white),
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
                                ? Icons.add_circle 
                                : Icons.add_circle_outline,
                            size: 24,
                          ),
                        ),
                        label: 'Create',
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
                                ? Icons.sports_tennis 
                                : Icons.sports_tennis_outlined,
                            size: 24,
                          ),
                        ),
                        label: 'Tournaments',
                      ),
                      BottomNavigationBarItem(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _selectedIndex == 3 
                                ? const Color(0xFF6C9A8B).withOpacity(0.15)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _selectedIndex == 3 
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