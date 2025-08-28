import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class MatchDetailsPage extends StatefulWidget {
  final String tournamentId;
  final Map<String, dynamic> match;
  final int matchIndex;
  final bool isCreator;
  final bool isDoubles;
  final bool isUmpire;
  final VoidCallback onDeleteMatch;

  const MatchDetailsPage({
    super.key,
    required this.tournamentId,
    required this.match,
    required this.matchIndex,
    required this.isCreator,
    required this.isDoubles,
    required this.isUmpire,
    required this.onDeleteMatch,
  });

  @override
  State<MatchDetailsPage> createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late Map<String, dynamic> _match;
  final _umpireNameController = TextEditingController();
  final _umpireEmailController = TextEditingController();
  final _umpirePhoneController = TextEditingController();
  late String _initialUmpireName;
  late String _initialUmpireEmail;
  late String _initialUmpirePhone;
  String? _currentServer;
  String? _lastServer;
  int? _lastTeam1Score;
  int? _lastTeam2Score;
  bool _showPlusOneTeam1 = false;
  bool _showPlusOneTeam2 = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _debounceTimer;
  Timer? _countdownTimer;
  String? _countdown;
  Timestamp? _matchStartTime;
  String _tournamentTimezone = 'UTC';
  tz.Location? _timezoneLocation;
  bool _isTimezoneInitialized = false;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _match = Map.from(widget.match);
    _umpireNameController.text = _match['umpire']?['name'] ?? '';
    _umpireEmailController.text = _match['umpire']?['email'] ?? '';
    _umpirePhoneController.text = _match['umpire']?['phone'] ?? '';
    _initialUmpireName = _umpireNameController.text;
    _initialUmpireEmail = _umpireEmailController.text;
    _initialUmpirePhone = _umpirePhoneController.text;
    _lastTeam1Score = _getCurrentScore(true);
    _lastTeam2Score = _getCurrentScore(false);
    _matchStartTime = _match['startTime'] as Timestamp?;
    _initializeTimezone();
    _initializeServer();
    _listenToMatchUpdates();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _umpireNameController.dispose();
    _umpireEmailController.dispose();
    _umpirePhoneController.dispose();
    _animationController.dispose();
    _debounceTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTimezone() async {
    try {
      final tournamentDoc =
          await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .get();

      final timezone = tournamentDoc.data()?['timezone'] as String? ?? 'UTC';

      setState(() {
        _tournamentTimezone = timezone;
        try {
          _timezoneLocation = tz.getLocation(timezone);
        } catch (e) {
          debugPrint('Invalid timezone: $timezone, defaulting to UTC');
          _tournamentTimezone = 'UTC';
          _timezoneLocation = tz.getLocation('UTC');
        }
        _isTimezoneInitialized = true;
      });
      _startCountdown();
    } catch (e) {
      debugPrint('Error initializing timezone: $e');
      setState(() {
        _tournamentTimezone = 'UTC';
        _timezoneLocation = tz.getLocation('UTC');
        _isTimezoneInitialized = true;
      });
      _startCountdown();
    }
  }

  DateTime _convertToTournamentTime(Timestamp timestamp) {
    if (_timezoneLocation == null) return timestamp.toDate();
    final utcTime = timestamp.toDate();
    return tz.TZDateTime.from(utcTime, _timezoneLocation!);
  }

  String _formatDateWithTimezone(DateTime date) {
    final timezoneAbbreviation =
        _tournamentTimezone == 'Asia/Kolkata'
            ? 'IST'
            : _tournamentTimezone.split('/').last;
    return '${DateFormat('MMM dd, yyyy h:mm a').format(date)} ($timezoneAbbreviation)';
  }

  void _startCountdown() {
    if (!_isTimezoneInitialized || _timezoneLocation == null) {
      _countdownTimer?.cancel();
      _countdownTimer = Timer(
        const Duration(milliseconds: 100),
        _startCountdown,
      );
      return;
    }

    if (_match['liveScores']?['isLive'] == true ||
        _match['completed'] == true) {
      setState(() => _countdown = null);
      _countdownTimer?.cancel();
      return;
    }

    if (_matchStartTime == null) {
      setState(() => _countdown = 'Start time not scheduled');
      _countdownTimer?.cancel();
      return;
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = tz.TZDateTime.now(_timezoneLocation!);
      final startTime = _convertToTournamentTime(_matchStartTime!);
      final difference = startTime.difference(now);

      if (difference.isNegative) {
        setState(() => _countdown = 'Match should have started');
        timer.cancel();
      } else {
        setState(() {
          _countdown = _formatDuration(difference);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays >= 1) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours >= 1) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
  }

  Future<void> _updateMatchStartTime() async {
    if (_isLoading ||
        _match['liveScores']?['isLive'] == true ||
        _match['completed'] == true ||
        !_isTimezoneInitialized) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tournamentDoc =
          await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .get();
      final data = tournamentDoc.data();
      if (data == null) {
        throw Exception('Tournament data not found');
      }

      // Get tournament time bounds in local timezone
      final tournamentStartDate = tz.TZDateTime.from(
        (data['startDate'] as Timestamp).toDate(),
        _timezoneLocation!,
      );
      final tournamentEndDate = tz.TZDateTime.from(
        (data['endDate'] as Timestamp).toDate(),
        _timezoneLocation!,
      );
      final now = tz.TZDateTime.now(_timezoneLocation!);

      final firstDate =
          now.isAfter(tournamentStartDate) ? now : tournamentStartDate;
      final lastDate = tournamentEndDate;

      final initialDate =
          _matchStartTime != null
              ? _convertToTournamentTime(_matchStartTime!)
              : now;

      // Show date picker in local timezone
      final newDate = await showDatePicker(
        context: context,
        initialDate:
            initialDate.isBefore(firstDate)
                ? firstDate
                : (initialDate.isAfter(lastDate) ? lastDate : initialDate),
        firstDate: firstDate,
        lastDate: lastDate,
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6C9A8B),
                onPrimary: Color(0xFFFDFCFB),
                surface: Color(0xFFFFFFFF),
                onSurface: Color(0xFF333333),
              ),
              textTheme: GoogleFonts.poppinsTextTheme(),
            ),
            child: child!,
          );
        },
      );

      if (newDate == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Show time picker in local timezone
      final newTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF6C9A8B),
                onPrimary: Color(0xFFFDFCFB),
                surface: Color(0xFFFFFFFF),
                onSurface: Color(0xFF333333),
              ),
              textTheme: GoogleFonts.poppinsTextTheme(),
            ),
            child: child!,
          );
        },
      );

      if (newTime == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Combine date and time in local timezone
      final newDateTime = tz.TZDateTime(
        _timezoneLocation!,
        newDate.year,
        newDate.month,
        newDate.day,
        newTime.hour,
        newTime.minute,
      );

      // Validate against tournament bounds
      if (newDateTime.isBefore(tournamentStartDate)) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(
            'Invalid Date',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          description: Text(
            'Selected date cannot be before ${DateFormat('MMM dd, yyyy').format(tournamentStartDate)}',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
        setState(() => _isLoading = false);
        return;
      }

      if (newDateTime.isAfter(tournamentEndDate)) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(
            'Invalid Date',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          description: Text(
            'Selected date cannot be after ${DateFormat('MMM dd, yyyy').format(tournamentEndDate)}',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Convert to UTC for storage
      final utcDateTime = newDateTime.toUtc();
      final updatedMatches = List<Map<String, dynamic>>.from(data['matches']);
      updatedMatches[widget.matchIndex] = {
        ..._match,
        'startTime': Timestamp.fromDate(utcDateTime),
      };

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': updatedMatches});

      setState(() {
        _match = updatedMatches[widget.matchIndex];
        _matchStartTime = Timestamp.fromDate(utcDateTime);
        _startCountdown();
      });

      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: Text(
          'Start Time Updated',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Match start time updated to ${_formatDateWithTimezone(newDateTime)}',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2A9D8F),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } catch (e) {
      debugPrint('Error updating match start time: $e');
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Update Failed',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Failed to update start time: ${e.toString()}',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initializeServer() {
    final liveScores = _match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final team1Scores = List<int>.from(
      liveScores[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0],
    );
    final team2Scores = List<int>.from(
      liveScores[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0],
    );

    if (!liveScores.containsKey('isLive') || !liveScores['isLive']) {
      _currentServer = widget.isDoubles ? 'team1' : 'player1';
      _lastServer = _currentServer;
    } else if (liveScores['currentServer'] != null) {
      _currentServer = liveScores['currentServer'];
      _lastServer = _currentServer;
    } else {
      String? lastSetWinner;
      for (int i = 0; i < currentGame - 1; i++) {
        if (team1Scores[i] >= 21 && (team1Scores[i] - team2Scores[i]) >= 2 ||
            team1Scores[i] == 30) {
          lastSetWinner = widget.isDoubles ? 'team1' : 'player1';
        } else if (team2Scores[i] >= 21 &&
                (team2Scores[i] - team1Scores[i]) >= 2 ||
            team2Scores[i] == 30) {
          lastSetWinner = widget.isDoubles ? 'team2' : 'player2';
        }
      }
      if (team1Scores[currentGame - 1] == 0 &&
          team2Scores[currentGame - 1] == 0 &&
          lastSetWinner != null) {
        _currentServer = lastSetWinner;
        _lastServer = _currentServer;
      } else if (_lastTeam1Score != null && _lastTeam2Score != null) {
        if (team1Scores[currentGame - 1] > _lastTeam1Score!) {
          _currentServer = widget.isDoubles ? 'team1' : 'player1';
          _lastServer = _currentServer;
        } else if (team2Scores[currentGame - 1] > _lastTeam2Score!) {
          _currentServer = widget.isDoubles ? 'team2' : 'player2';
          _lastServer = _currentServer;
        } else {
          _currentServer =
              _lastServer ?? (widget.isDoubles ? 'team1' : 'player1');
        }
      } else {
        _currentServer = widget.isDoubles ? 'team1' : 'player1';
        _lastServer = _currentServer;
      }
    }
  }

  int _getCurrentScore(bool isTeam1) {
    final liveScores = _match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final scores = List<int>.from(
      liveScores[isTeam1
              ? (widget.isDoubles ? 'team1' : 'player1')
              : (widget.isDoubles ? 'team2' : 'player2')] ??
          [0, 0, 0],
    );
    return scores[currentGame - 1];
  }

  String _getServiceCourt(bool isTeam1) {
    final liveScores = _match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final scores = List<int>.from(
      liveScores[isTeam1
              ? (widget.isDoubles ? 'team1' : 'player1')
              : (widget.isDoubles ? 'team2' : 'player2')] ??
          [0, 0, 0],
    );
    return scores[currentGame - 1].isEven ? 'Right' : 'Left';
  }

  void _listenToMatchUpdates() {
    FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data != null && data['matches'] != null && mounted) {
            final matches = List<Map<String, dynamic>>.from(data['matches']);
            if (matches.length > widget.matchIndex) {
              final newMatch = matches[widget.matchIndex];
              final newTeam1Score = _getCurrentScoreFromMatch(newMatch, true);
              final newTeam2Score = _getCurrentScoreFromMatch(newMatch, false);
              if (newTeam1Score > (_lastTeam1Score ?? 0)) {
                setState(() {
                  _showPlusOneTeam1 = true;
                  _animationController.forward().then((_) {
                    _animationController.reverse();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) setState(() => _showPlusOneTeam1 = false);
                    });
                  });
                });
              } else if (newTeam2Score > (_lastTeam2Score ?? 0)) {
                setState(() {
                  _showPlusOneTeam2 = true;
                  _animationController.forward().then((_) {
                    _animationController.reverse();
                    Future.delayed(const Duration(milliseconds: 100), () {
                      if (mounted) setState(() => _showPlusOneTeam2 = false);
                    });
                  });
                });
              }
              setState(() {
                _match = newMatch;
                if (_matchStartTime == null ||
                    _match['startTime'] == _matchStartTime) {
                  _matchStartTime = _match['startTime'] as Timestamp?;
                }
                _umpireNameController.text = _match['umpire']?['name'] ?? '';
                _umpireEmailController.text = _match['umpire']?['email'] ?? '';
                _umpirePhoneController.text = _match['umpire']?['phone'] ?? '';
                _initialUmpireName = _umpireNameController.text;
                _initialUmpireEmail = _umpireEmailController.text;
                _initialUmpirePhone = _umpirePhoneController.text;
                _lastTeam1Score = newTeam1Score;
                _lastTeam2Score = newTeam2Score;
                _initializeServer();
                _startCountdown();
              });
            }
          }
        });
  }

  int _getCurrentScoreFromMatch(Map<String, dynamic> match, bool isTeam1) {
    final liveScores = match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final scores = List<int>.from(
      liveScores[isTeam1
              ? (widget.isDoubles ? 'team1' : 'player1')
              : (widget.isDoubles ? 'team2' : 'player2')] ??
          [0, 0, 0],
    );
    return scores[currentGame - 1];
  }

  bool get _isUmpireButtonDisabled {
    final name = _umpireNameController.text.trim();
    final email = _umpireEmailController.text.trim();
    final phone = _umpirePhoneController.text.trim();
    final isLive = _match['liveScores']?['isLive'] == true;
    return isLive ||
        (name.isEmpty && email.isEmpty && phone.isEmpty) ||
        (name == _initialUmpireName &&
            email == _initialUmpireEmail &&
            phone == _initialUmpirePhone);
  }

  Future<void> _fetchUserData(String email) async {
    if (_match['liveScores']?['isLive'] == true) return;
    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return;
    }

    try {
      final query =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .where('role', isEqualTo: 'umpire')
              .limit(1)
              .get();

      if (query.docs.isNotEmpty && mounted) {
        final userData = query.docs.first.data();
        setState(() {
          _umpireNameController.text =
              '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                  .trim();
          _umpirePhoneController.text = userData['phone'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _updateUmpireDetails() async {
    if (_isLoading || _isUmpireButtonDisabled) return;
    if (_match['liveScores']?['isLive'] == true) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Update Not Allowed',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Umpire details cannot be updated after the match has started.',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    final name = _umpireNameController.text.trim();
    final email = _umpireEmailController.text.trim();
    final phone = _umpirePhoneController.text.trim();

    if (email.isEmpty) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Email Required',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Please enter an email address.',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Invalid Email',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Please enter a valid email address.',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    if (phone.isNotEmpty && !RegExp(r'^\+\d{11,12}$').hasMatch(phone)) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Invalid Phone',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Please enter a valid phone number with country code (e.g., +919346297919).',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailQuery =
          await FirebaseFirestore.instance
              .collection('users')
              .where('email', isEqualTo: email)
              .where('role', isNotEqualTo: 'umpire')
              .limit(1)
              .get();

      if (emailQuery.docs.isNotEmpty) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text(
            'Unauthorized Email',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          description: Text(
            'Email is not authorized as umpire.',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
        return;
      }

      if (phone.isNotEmpty) {
        final phoneQuery =
            await FirebaseFirestore.instance
                .collection('users')
                .where('phone', isEqualTo: phone)
                .where('role', isNotEqualTo: 'umpire')
                .limit(1)
                .get();

        if (phoneQuery.docs.isNotEmpty) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: Text(
              'Unauthorized Phone',
              style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
            ),
            description: Text(
              'Phone is not authorized as umpire.',
              style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
            ),
            autoCloseDuration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFE76F51),
            foregroundColor: const Color(0xFFFDFCFB),
            alignment: Alignment.bottomCenter,
          );
          return;
        }
      }

      final tournamentDoc =
          await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(widget.tournamentId)
              .get();
      final updatedMatches = List<Map<String, dynamic>>.from(
        tournamentDoc.data()!['matches'],
      );

      updatedMatches[widget.matchIndex] = {
        ..._match,
        'umpire': {'name': name, 'email': email, 'phone': phone},
      };

      final umpireQuery =
          await FirebaseFirestore.instance
              .collection('umpire_credentials')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();

      if (umpireQuery.docs.isNotEmpty) {
        final umpireDocId = umpireQuery.docs.first.id;
        await FirebaseFirestore.instance
            .collection('umpire_credentials')
            .doc(umpireDocId)
            .update({
              'name': name,
              'phone': phone,
              'tournamentId': widget.tournamentId,
              'updatedAt': Timestamp.now(),
            });
      } else {
        final newUmpireDoc =
            FirebaseFirestore.instance.collection('umpire_credentials').doc();
        await newUmpireDoc.set({
          'uid': newUmpireDoc.id,
          'name': name,
          'email': email,
          'phone': phone,
          'tournamentId': widget.tournamentId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': updatedMatches});

      _initialUmpireName = name;
      _initialUmpireEmail = email;
      _initialUmpirePhone = phone;

      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: Text(
          'Umpire Details Saved',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Umpire details have been saved successfully.',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2A9D8F),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } catch (e) {
      if (e.toString().contains('requires an index')) {
        debugPrint(
          '''Firestore index required. Create the following indexes in firestore.indexes.json:
{
  "indexes": [
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "email", "order": "ASCENDING" },
        { "fieldPath": "role", "order": "ASCENDING" }
      ]
    },
    {
      "collectionGroup": "users",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "phone", "order": "ASCENDING" },
        { "fieldPath": "role", "order": "ASCENDING" }
      ]
    }
  ]
}
Then run: firebase deploy --only firestore:indexes
Error details: $e''',
        );
      }
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Save Failed',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Failed to save umpire details: $e',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startMatch() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final updatedMatches = List<Map<String, dynamic>>.from(
        (await FirebaseFirestore.instance
                .collection('tournaments')
                .doc(widget.tournamentId)
                .get())
            .data()!['matches'],
      );
      updatedMatches[widget.matchIndex] = {
        ..._match,
        'liveScores': {
          ..._match['liveScores'] ?? {},
          'isLive': true,
          'startTime': Timestamp.now(),
          'currentGame': 1,
          'currentServer': widget.isDoubles ? 'team1' : 'player1',
          widget.isDoubles ? 'team1' : 'player1': [0, 0, 0],
          widget.isDoubles ? 'team2' : 'player2': [0, 0, 0],
        },
      };

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': updatedMatches});

      setState(() {
        _match = updatedMatches[widget.matchIndex];
        _initializeServer();
      });

      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: Text(
          'Match Started',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'The match is now live.',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2A9D8F),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Start Failed',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Failed to start match: $e',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLiveScore(bool isTeam1, int gameIndex, int delta) async {
    if (_isLoading || !widget.isUmpire) return;
    setState(() => _isLoading = true);

    try {
      final updatedMatches = List<Map<String, dynamic>>.from(
        (await FirebaseFirestore.instance
                .collection('tournaments')
                .doc(widget.tournamentId)
                .get())
            .data()!['matches'],
      );
      final currentScores = Map<String, dynamic>.from(_match['liveScores']);
      final key =
          isTeam1
              ? (widget.isDoubles ? 'team1' : 'player1')
              : (widget.isDoubles ? 'team2' : 'player2');
      final scores = List<int>.from(currentScores[key]);
      final newScore = (scores[gameIndex] + delta).clamp(0, 30);
      scores[gameIndex] = newScore;

      final newServer =
          isTeam1
              ? (widget.isDoubles ? 'team1' : 'player1')
              : (widget.isDoubles ? 'team2' : 'player2');
      updatedMatches[widget.matchIndex] = {
        ..._match,
        'liveScores': {
          ...currentScores,
          key: scores,
          'currentServer':
              newScore > scores[gameIndex]
                  ? newServer
                  : currentScores['currentServer'],
        },
      };

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': updatedMatches});

      setState(() {
        _match = updatedMatches[widget.matchIndex];
        _lastTeam1Score = _getCurrentScore(true);
        _lastTeam2Score = _getCurrentScore(false);
        _initializeServer();
      });

      final team1Scores = List<int>.from(
        currentScores[widget.isDoubles ? 'team1' : 'player1'],
      );
      final team2Scores = List<int>.from(
        currentScores[widget.isDoubles ? 'team2' : 'player2'],
      );
      final currentSetScore =
          isTeam1 ? scores[gameIndex] : team1Scores[gameIndex];
      final opponentSetScore =
          isTeam1 ? team2Scores[gameIndex] : scores[gameIndex];

      if ((currentSetScore >= 21 &&
              (currentSetScore - opponentSetScore >= 2)) ||
          currentSetScore == 30) {
        await _advanceGame();
      }

      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: Text(
          'Score Updated',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Live score has been updated.',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF2A9D8F),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Update Failed',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Failed to update score: $e',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _advanceGame() async {
    if (_isLoading || !widget.isUmpire) return;
    setState(() => _isLoading = true);

    try {
      final updatedMatches = List<Map<String, dynamic>>.from(
        (await FirebaseFirestore.instance
                .collection('tournaments')
                .doc(widget.tournamentId)
                .get())
            .data()!['matches'],
      );
      final currentGame = _match['liveScores']['currentGame'] as int;
      final team1Scores = List<int>.from(
        _match['liveScores'][widget.isDoubles ? 'team1' : 'player1'],
      );
      final team2Scores = List<int>.from(
        _match['liveScores'][widget.isDoubles ? 'team2' : 'player2'],
      );

      int team1Wins = 0;
      int team2Wins = 0;
      for (int i = 0; i < currentGame; i++) {
        if (team1Scores[i] >= 21 && (team1Scores[i] - team2Scores[i]) >= 2 ||
            team1Scores[i] == 30) {
          team1Wins++;
        } else if (team2Scores[i] >= 21 &&
                (team2Scores[i] - team1Scores[i]) >= 2 ||
            team2Scores[i] == 30) {
          team2Wins++;
        }
      }

      String? newServer;
      if (team1Scores[currentGame - 1] >= 21 &&
              (team1Scores[currentGame - 1] - team2Scores[currentGame - 1]) >=
                  2 ||
          team1Scores[currentGame - 1] == 30) {
        newServer = widget.isDoubles ? 'team1' : 'player1';
      } else if (team2Scores[currentGame - 1] >= 21 &&
              (team2Scores[currentGame - 1] - team1Scores[currentGame - 1]) >=
                  2 ||
          team2Scores[currentGame - 1] == 30) {
        newServer = widget.isDoubles ? 'team2' : 'player2';
      }

      String? winner;
      if (team1Wins >= 2) {
        winner = widget.isDoubles ? 'team1' : 'player1';
      } else if (team2Wins >= 2) {
        winner = widget.isDoubles ? 'team2' : 'player2';
      }

      if (winner != null) {
        List<String> winnerIds =
            widget.isDoubles
                ? (winner == 'team1'
                    ? List<String>.from(_match['team1Ids'])
                    : List<String>.from(_match['team2Ids']))
                : [
                  winner == 'player1'
                      ? _match['player1Id']
                      : _match['player2Id'],
                ];

        final updatedParticipants = List<Map<String, dynamic>>.from(
          (await FirebaseFirestore.instance
                  .collection('tournaments')
                  .doc(widget.tournamentId)
                  .get())
              .data()!['participants'],
        );
        final newParticipants =
            updatedParticipants.map((p) {
              final participantId = p['id'] as String;
              if (winnerIds.contains(participantId)) {
                final currentScore = p['score'] as int? ?? 0;
                return {...p, 'score': currentScore + 2};
              }
              return p;
            }).toList();

        updatedMatches[widget.matchIndex] = {
          ..._match,
          'completed': true,
          'winner': winner,
          'liveScores': {..._match['liveScores'], 'isLive': false},
        };

        await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId)
            .update({
              'participants': newParticipants,
              'matches': updatedMatches,
            });

        setState(() => _match = updatedMatches[widget.matchIndex]);

        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text(
            'Match Completed',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          description: Text(
            'Winner: ${winner == 'team1' || winner == 'player1' ? (widget.isDoubles ? _match['team1'].join(', ') : _match['player1']) : (widget.isDoubles ? _match['team2'].join(', ') : _match['player2'])}',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2A9D8F),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      } else if (currentGame < 3) {
        updatedMatches[widget.matchIndex] = {
          ..._match,
          'liveScores': {
            ..._match['liveScores'],
            'currentGame': currentGame + 1,
            'currentServer': newServer ?? _match['liveScores']['currentServer'],
          },
        };

        await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(widget.tournamentId)
            .update({'matches': updatedMatches});

        setState(() {
          _match = updatedMatches[widget.matchIndex];
          _initializeServer();
        });

        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text(
            'Game Advanced',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          description: Text(
            'Moved to the next game.',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2A9D8F),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: Text(
          'Advance Failed',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        description: Text(
          'Failed to advance game: $e',
          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: const Color(0xFFFDFCFB),
        alignment: Alignment.bottomCenter,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getAllSetResults() {
    final team1Scores = List<int>.from(
      _match['liveScores']?[widget.isDoubles ? 'team1' : 'player1'] ??
          [0, 0, 0],
    );
    final team2Scores = List<int>.from(
      _match['liveScores']?[widget.isDoubles ? 'team2' : 'player2'] ??
          [0, 0, 0],
    );

    return List.generate(3, (index) {
      final team1Score = team1Scores.length > index ? team1Scores[index] : null;
      final team2Score = team2Scores.length > index ? team2Scores[index] : null;

      String? winner;
      if (team1Score != null && team2Score != null) {
        if ((team1Score >= 21 && (team1Score - team2Score) >= 2) ||
            team1Score == 30) {
          winner =
              widget.isDoubles ? _match['team1'].join(', ') : _match['player1'];
        } else if ((team2Score >= 21 && (team2Score - team1Score) >= 2) ||
            team2Score == 30) {
          winner =
              widget.isDoubles ? _match['team2'].join(', ') : _match['player2'];
        }
      }

      return {
        'setNumber': index + 1,
        'team1Score': team1Score,
        'team2Score': team2Score,
        'winner': winner,
        'isCompleted': winner != null,
      };
    });
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int? maxLength,
    bool isRequired = false,
    ValueChanged<String>? onChanged,
  }) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLength: maxLength,
            style: GoogleFonts.poppins(
              color: const Color(0xFF333333),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              label: RichText(
                text: TextSpan(
                  text: label,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF757575),
                    fontSize: 14,
                  ),
                  children:
                      isRequired
                          ? [
                            const TextSpan(
                              text: ' *',
                              style: TextStyle(color: Color(0xFFE76F51)),
                            ),
                          ]
                          : [],
                ),
              ),
              hintText: isRequired ? 'Required' : null,
              hintStyle: GoogleFonts.poppins(
                color: const Color(0xFF757575).withOpacity(0.7),
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFFF4A261), size: 20),
              suffixIcon: suffixIcon,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFC1DADB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF6C9A8B),
                  width: 1.5,
                ),
              ),
              counterStyle: GoogleFonts.poppins(
                color: const Color(0xFF757575),
                fontSize: 12,
              ),
              filled: true,
              fillColor: const Color(0xFFC1DADB).withOpacity(0.1),
            ),
            onChanged: (value) {
              setState(() {});
              if (onChanged != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required LinearGradient gradient,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: isLoading || onPressed == null ? null : onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                gradient:
                    isLoading || onPressed == null
                        ? LinearGradient(
                          colors: [
                            const Color(0xFF757575),
                            const Color(0xFF757575).withOpacity(0.7),
                          ],
                        )
                        : gradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF333333).withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFDFCFB),
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        text,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFDFCFB),
                        ),
                      ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScoreButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE9C46A).withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE9C46A).withOpacity(0.5)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color(0xFFE9C46A),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required List<Widget> children,
    bool isLive = false,
  }) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isLive
                        ? const Color(0xFFE76F51)
                        : const Color(0xFFC1DADB).withOpacity(0.5),
                width: isLive ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF333333).withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
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
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    if (isLive) _buildLiveStatusBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE76F51).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFDFCFB),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'LIVE',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFDFCFB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFF4A261), size: 18),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF757575),
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF333333),
                fontWeight: FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetScoreCard({
    required int setNumber,
    required int? team1Score,
    required int? team2Score,
    required String? winner,
    required bool isCurrentSet,
  }) {
    final isCompleted = winner != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isCurrentSet
                ? const Color(0xFF2A9D8F).withOpacity(0.1)
                : const Color(0xFFFDFCFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isCurrentSet
                  ? const Color(0xFF2A9D8F)
                  : const Color(0xFFC1DADB).withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF333333).withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Set $setNumber',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: isCurrentSet ? FontWeight.w600 : FontWeight.w500,
              color:
                  isCurrentSet
                      ? const Color(0xFF2A9D8F)
                      : const Color(0xFF333333),
            ),
          ),
          Row(
            children: [
              Text(
                team1Score != null ? '$team1Score' : '-',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight:
                      winner ==
                              (widget.isDoubles
                                  ? _match['team1'].join(', ')
                                  : _match['player1'])
                          ? FontWeight.w700
                          : FontWeight.w500,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '-',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF757575),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                team2Score != null ? '$team2Score' : '-',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight:
                      winner ==
                              (widget.isDoubles
                                  ? _match['team2'].join(', ')
                                  : _match['player2'])
                          ? FontWeight.w700
                          : FontWeight.w500,
                  color: const Color(0xFF333333),
                ),
              ),
            ],
          ),
          if (isCompleted)
            Icon(Icons.check_circle, color: const Color(0xFF2A9D8F), size: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _match['completed'] == true;
    final isLive = _match['liveScores']?['isLive'] == true;
    final currentSet = _match['liveScores']?['currentGame'] ?? 1;
    final allSetResults = _getAllSetResults();
    final currentSetIndex = currentSet - 1;

    int team1Wins = 0;
    int team2Wins = 0;
    for (final set in allSetResults) {
      if (set['winner'] ==
          (widget.isDoubles ? _match['team1'].join(', ') : _match['player1'])) {
        team1Wins++;
      } else if (set['winner'] ==
          (widget.isDoubles ? _match['team2'].join(', ') : _match['player2'])) {
        team2Wins++;
      }
    }

    final matchWinner =
        isCompleted
            ? (_match['winner'] == 'team1' || _match['winner'] == 'player1'
                ? (widget.isDoubles
                    ? _match['team1'].join(', ')
                    : _match['player1'])
                : (widget.isDoubles
                    ? _match['team2'].join(', ')
                    : _match['player2']))
            : null;

    final startTimeDisplay =
        _matchStartTime != null && _isTimezoneInitialized
            ? _formatDateWithTimezone(
              _convertToTournamentTime(_matchStartTime!),
            )
            : 'Loading...';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF6C9A8B),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFCFB),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: const Color(0xFF6C9A8B),
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  color: const Color(0xFFFDFCFB),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  widget.isDoubles
                      ? 'Team Match Details'
                      : 'Singles Match Details',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFDFCFB),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: [
                  if (widget.isCreator && !isCompleted)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          widget.onDeleteMatch();
                          Navigator.pop(context);
                        }
                      },
                      itemBuilder:
                          (context) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete Match',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFE76F51),
                                ),
                              ),
                            ),
                          ],
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFFFDFCFB),
                      ),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: AnimationConfiguration.synchronized(
                    duration: const Duration(milliseconds: 1000),
                    child: Column(
                      children: AnimationConfiguration.toStaggeredList(
                        duration: const Duration(milliseconds: 500),
                        childAnimationBuilder:
                            (child) => SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(child: child),
                            ),
                        children: [
                          _buildDetailSection(
                            title: 'Match Information',
                            children: [
                              _buildDetailRow(
                                icon: Icons.sports_tennis,
                                label: 'Round',
                                value: 'Round ${_match['round']}',
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.isDoubles
                                            ? _match['team1'].join(', ')
                                            : _match['player1'],
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF333333),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text(
                                        'vs',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF757575),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        widget.isDoubles
                                            ? _match['team2'].join(', ')
                                            : _match['player2'],
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF333333),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildDetailRow(
                                icon: Icons.access_time,
                                label: 'Start Time',
                                value: startTimeDisplay,
                              ),
                              if (_countdown != null)
                                _buildDetailRow(
                                  icon: Icons.timer,
                                  label: 'Countdown',
                                  value: _countdown!,
                                ),
                              if (matchWinner != null)
                                _buildDetailRow(
                                  icon: Icons.emoji_events,
                                  label: 'Winner',
                                  value: matchWinner,
                                ),
                              if (widget.isCreator && !isLive && !isCompleted)
                                const SizedBox(height: 12),
                              if (widget.isCreator && !isLive && !isCompleted)
                                _buildModernButton(
                                  text: 'Update Start Time',
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2A9D8F),
                                      Color(0xFF6C9A8B),
                                    ],
                                  ),
                                  isLoading: _isLoading,
                                  onPressed: _updateMatchStartTime,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailSection(
                            title: 'Live Score',
                            isLive: isLive,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          widget.isDoubles
                                              ? _match['team1'].join(', ')
                                              : _match['player1'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: const Color(0xFF333333),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              _getCurrentScore(true).toString(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 32,
                                                color: const Color(0xFF2A9D8F),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_showPlusOneTeam1)
                                              Positioned(
                                                top: -10,
                                                child: FadeTransition(
                                                  opacity: _fadeAnimation,
                                                  child: ScaleTransition(
                                                    scale: _scaleAnimation,
                                                    child: Text(
                                                      '+1',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 16,
                                                            color: const Color(
                                                              0xFFE76F51,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (isLive && widget.isUmpire)
                                          Column(
                                            children: [
                                              const SizedBox(height: 8),
                                              _buildScoreButton(
                                                label: '+1',
                                                onPressed:
                                                    () => _updateLiveScore(
                                                      true,
                                                      currentSetIndex,
                                                      1,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              _buildScoreButton(
                                                label: '-1',
                                                onPressed:
                                                    () => _updateLiveScore(
                                                      true,
                                                      currentSetIndex,
                                                      -1,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        if (isLive)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              _currentServer ==
                                                      (widget.isDoubles
                                                          ? 'team1'
                                                          : 'player1')
                                                  ? 'Serving (${_getServiceCourt(true)})'
                                                  : '',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: const Color(0xFF757575),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      ':',
                                      style: GoogleFonts.poppins(
                                        fontSize: 24,
                                        color: const Color(0xFF333333),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          widget.isDoubles
                                              ? _match['team2'].join(', ')
                                              : _match['player2'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: const Color(0xFF333333),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(
                                              _getCurrentScore(
                                                false,
                                              ).toString(),
                                              style: GoogleFonts.poppins(
                                                fontSize: 32,
                                                color: const Color(0xFF2A9D8F),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_showPlusOneTeam2)
                                              Positioned(
                                                top: -10,
                                                child: FadeTransition(
                                                  opacity: _fadeAnimation,
                                                  child: ScaleTransition(
                                                    scale: _scaleAnimation,
                                                    child: Text(
                                                      '+1',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 16,
                                                            color: const Color(
                                                              0xFFE76F51,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (isLive && widget.isUmpire)
                                          Column(
                                            children: [
                                              const SizedBox(height: 8),
                                              _buildScoreButton(
                                                label: '+1',
                                                onPressed:
                                                    () => _updateLiveScore(
                                                      false,
                                                      currentSetIndex,
                                                      1,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              _buildScoreButton(
                                                label: '-1',
                                                onPressed:
                                                    () => _updateLiveScore(
                                                      false,
                                                      currentSetIndex,
                                                      -1,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        if (isLive)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              _currentServer ==
                                                      (widget.isDoubles
                                                          ? 'team2'
                                                          : 'player2')
                                                  ? 'Serving (${_getServiceCourt(false)})'
                                                  : '',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: const Color(0xFF757575),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Current Set: $currentSet',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF2A9D8F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children:
                                    allSetResults.asMap().entries.map((entry) {
                                      final set = entry.value;
                                      final isCurrentSet =
                                          entry.key == currentSetIndex;
                                      return _buildSetScoreCard(
                                        setNumber: set['setNumber'],
                                        team1Score: set['team1Score'],
                                        team2Score: set['team2Score'],
                                        winner: set['winner'],
                                        isCurrentSet: isCurrentSet,
                                      );
                                    }).toList(),
                              ),
                              if (team1Wins > 0 || team2Wins > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Set Wins: ${widget.isDoubles ? _match['team1'].join(', ') : _match['player1']} ($team1Wins) vs ${widget.isDoubles ? _match['team2'].join(', ') : _match['player2']} ($team2Wins)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              if (widget.isUmpire && !isLive && !isCompleted)
                                const SizedBox(height: 12),
                              if (widget.isUmpire && !isLive && !isCompleted)
                                _buildModernButton(
                                  text: 'Start Match',
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2A9D8F),
                                      Color(0xFF6C9A8B),
                                    ],
                                  ),
                                  isLoading: _isLoading,
                                  onPressed: _startMatch,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailSection(
                            title: 'Umpire Details',
                            children: [
                              _buildModernTextField(
                                controller: _umpireNameController,
                                label: 'Umpire Name',
                                icon: Icons.person,
                                isRequired: false,
                              ),
                              const SizedBox(height: 12),
                              _buildModernTextField(
                                controller: _umpireEmailController,
                                label: 'Umpire Email',
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                isRequired: true,
                                onChanged: (value) {
                                  _debounceTimer?.cancel();
                                  _debounceTimer = Timer(
                                    const Duration(milliseconds: 500),
                                    () => _fetchUserData(value),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _buildModernTextField(
                                controller: _umpirePhoneController,
                                label: 'Umpire Phone',
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                maxLength: 13,
                                isRequired: false,
                              ),
                              const SizedBox(height: 12),
                              if (widget.isCreator)
                                _buildModernButton(
                                  text: 'Save Umpire Details',
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2A9D8F),
                                      Color(0xFF6C9A8B),
                                    ],
                                  ),
                                  isLoading: _isLoading,
                                  onPressed:
                                      _isUmpireButtonDisabled
                                          ? null
                                          : _updateUmpireDetails,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}