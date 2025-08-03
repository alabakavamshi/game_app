import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:badges/badges.dart' as badges;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class MatchControlPage extends StatefulWidget {
  final String tournamentId;
  final Map<String, dynamic> match;
  final int matchIndex;
  final bool isDoubles;

  const MatchControlPage({
    super.key,
    required this.tournamentId,
    required this.match,
    required this.matchIndex,
    required this.isDoubles,
  });

  @override
  State<MatchControlPage> createState() => _MatchControlPageState();
}

class _MatchControlPageState extends State<MatchControlPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late Map<String, dynamic> _match;
  String? _currentServer;
  String? _lastSetWinner;
  String? _lastServer;
  bool _isSetComplete = false;
  int? _lastTeam1Score;
  int? _lastTeam2Score;
  bool _showPlusOneTeam1 = false;
  bool _showPlusOneTeam2 = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  tz.TZDateTime? _matchStartTime;
  String? _countdown;
  Timer? _countdownTimer;
  bool _canStartMatch = false;
  String? _tournamentTimezone;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _match = Map.from(widget.match);
    _initializeMatchStartTime().then((_) {
      _lastTeam1Score = _getCurrentScore(true);
      _lastTeam2Score = _getCurrentScore(false);
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
      _startCountdown();
      _checkMatchCompletion();
    });
  }

  Future<void> _initializeMatchStartTime() async {
    if (_match['startTime'] != null) {
      final startTime = (_match['startTime'] as Timestamp).toDate();
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();
      final data = tournamentDoc.data();
      final timezoneName = data?['timezone'] as String? ?? 'UTC';
      final timezone = tz.getLocation(timezoneName);
      setState(() {
        _matchStartTime = tz.TZDateTime.from(startTime, timezone);
        _tournamentTimezone = timezoneName;
      });
      return;
    }
    final tournamentDoc = await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get();
    final data = tournamentDoc.data();
    final startDate = data?['startDate'] as Timestamp?;
    final startTimeData = data?['startTime'] as Map<String, dynamic>?;
    final timezoneName = data?['timezone'] as String? ?? 'UTC';
    final timezone = tz.getLocation(timezoneName);
    if (startDate != null && startTimeData != null) {
      final startDateTime = tz.TZDateTime.from(startDate.toDate(), timezone);
      final hour = startTimeData['hour'] as int? ?? 0;
      final minute = startTimeData['minute'] as int? ?? 0;
      setState(() {
        _matchStartTime = tz.TZDateTime(
          timezone,
          startDateTime.year,
          startDateTime.month,
          startDateTime.day,
          hour,
          minute,
        );
        _tournamentTimezone = timezoneName;
      });
    } else {
      final now = tz.TZDateTime.now(timezone).add(const Duration(minutes: 5));
      setState(() {
        _matchStartTime = now;
        _tournamentTimezone = timezoneName;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

 void _startCountdown() {
  if (_match['liveScores']?['isLive'] == true || _match['completed'] == true) {
    setState(() {
      _countdown = null;
    });
    _countdownTimer?.cancel();
    return;
  }
  if (_matchStartTime == null || _tournamentTimezone == null) {
    setState(() {
      _countdown = 'Start time not scheduled';
    });
    _countdownTimer?.cancel();
    return;
  }
  setState(() {
    _countdown = null;
  });
  _countdownTimer?.cancel();
  _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }
    final now = tz.TZDateTime.now(tz.getLocation(_tournamentTimezone!));
    final difference = _matchStartTime!.difference(now);
    if (difference.isNegative) {
      setState(() {
        _countdown = 'Match should have started';
        _canStartMatch = true;
      });
      timer.cancel();
    } else if (difference.inHours >= 24) {
      final days = difference.inDays;
      final hours = (difference.inHours % 24) + (difference.inMinutes % 60 >= 30 ? 1 : 0); // Round up if minutes >= 30
      setState(() {
        _countdown = '${days}d ${hours}h';
        _canStartMatch = false;
      });
    } else {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      final seconds = difference.inSeconds % 60;
      setState(() {
        _countdown = '${hours}h ${minutes}m ${seconds}s';
        _canStartMatch = false;
      });
    }
  });
}
  int _getCurrentScore(bool isTeam1) {
    final liveScores = _match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final scores = List<int>.from(
        liveScores[isTeam1 ? (widget.isDoubles ? 'team1' : 'player1') : (widget.isDoubles ? 'team2' : 'player2')] ?? [0, 0, 0]);
    return scores[currentGame - 1];
  }

  void _initializeServer() {
    final liveScores = _match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final team1Scores = List<int>.from(
        liveScores[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
    final team2Scores = List<int>.from(
        liveScores[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
    if (!liveScores.containsKey('isLive') || !liveScores['isLive']) {
      _currentServer = widget.isDoubles ? 'team1' : 'player1';
      _lastServer = _currentServer;
    } else if (liveScores['currentServer'] != null) {
      _currentServer = liveScores['currentServer'];
      _lastServer = _currentServer;
    } else if (_lastSetWinner != null && team1Scores[currentGame - 1] == 0 && team2Scores[currentGame - 1] == 0) {
      _currentServer = _lastSetWinner;
      _lastServer = _currentServer;
    } else if (_lastTeam1Score != null && _lastTeam2Score != null) {
      if (team1Scores[currentGame - 1] > _lastTeam1Score!) {
        _currentServer = widget.isDoubles ? 'team1' : 'player1';
        _lastServer = _currentServer;
      } else if (team2Scores[currentGame - 1] > _lastTeam2Score!) {
        _currentServer = widget.isDoubles ? 'team2' : 'player2';
        _lastServer = _currentServer;
      } else {
        _currentServer = _lastServer ?? (widget.isDoubles ? 'team1' : 'player1');
      }
    } else {
      _currentServer = widget.isDoubles ? 'team1' : 'player1';
      _lastServer = _currentServer;
    }
  }

  void _listenToMatchUpdates() {
    FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data != null && mounted) {
            if (data['matches'] != null) {
              final matches = List<Map<String, dynamic>>.from(data['matches']);
              if (matches.length > widget.matchIndex) {
                final newMatch = matches[widget.matchIndex];
                final newStartTime = newMatch['startTime'] as Timestamp?;
                if (newStartTime != null && _tournamentTimezone != null) {
                  final timezone = tz.getLocation(_tournamentTimezone!);
                  final newStartTimeTZ = tz.TZDateTime.from(newStartTime.toDate(), timezone);
                  if (_matchStartTime != newStartTimeTZ) {
                    setState(() {
                      _matchStartTime = newStartTimeTZ;
                    });
                    _startCountdown();
                  }
                }
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
                  _lastTeam1Score = newTeam1Score;
                  _lastTeam2Score = newTeam2Score;
                  _checkSetCompletion();
                  _initializeServer();
                });
              }
            }
          }
        });
  }

  int _getCurrentScoreFromMatch(Map<String, dynamic> match, bool isTeam1) {
    final liveScores = match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final scores = List<int>.from(
        liveScores[isTeam1 ? (widget.isDoubles ? 'team1' : 'player1') : (widget.isDoubles ? 'team2' : 'player2')] ?? [0, 0, 0]);
    return scores[currentGame - 1];
  }

  Future<void> _startMatch() async {
    if (_isLoading || !mounted || !_canStartMatch) {
      if (!_canStartMatch && mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.warning,
          title: Text('Cannot Start Match', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('Please wait until the scheduled start time.', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE9C46A),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();
      final matches = List<Map<String, dynamic>>.from(tournamentDoc.data()!['matches']);
      matches[widget.matchIndex] = {
        ..._match,
        'liveScores': {
          'isLive': true,
          'startTime': Timestamp.now(),
          'currentGame': 1,
          widget.isDoubles ? 'team1' : 'player1': [0, 0, 0],
          widget.isDoubles ? 'team2' : 'player2': [0, 0, 0],
          'currentServer': widget.isDoubles ? 'team1' : 'player1',
        },
      };
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': matches});
      setState(() {
        _match = matches[widget.matchIndex];
        _currentServer = widget.isDoubles ? 'team1' : 'player1';
        _lastServer = _currentServer;
      });
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text('Match Started', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('The match has started successfully.', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2A9D8F),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text('Error', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('Failed to start match: $e', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLiveScore(bool isTeam1) async {
    if (_isLoading || !mounted || _isSetComplete || _match['completed'] == true) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();
      final updatedMatches =
          List<Map<String, dynamic>>.from(tournamentDoc.data()!['matches']);
      final currentScores = Map<String, dynamic>.from(_match['liveScores']);
      final currentGame = currentScores['currentGame'] as int;
      final key =
          isTeam1 ? (widget.isDoubles ? 'team1' : 'player1') : (widget.isDoubles ? 'team2' : 'player2');
      final opponentKey =
          !isTeam1 ? (widget.isDoubles ? 'team1' : 'player1') : (widget.isDoubles ? 'team2' : 'player2');
      final scores = List<int>.from(currentScores[key]);
      final opponentScores = List<int>.from(currentScores[opponentKey]);
      scores[currentGame - 1]++;
      scores[currentGame - 1] = scores[currentGame - 1].clamp(0, 30);
      _lastTeam1Score = List<int>.from(currentScores[widget.isDoubles ? 'team1' : 'player1'])[currentGame - 1];
      _lastTeam2Score = List<int>.from(currentScores[widget.isDoubles ? 'team2' : 'player2'])[currentGame - 1];
      _currentServer = key;
      _lastServer = _currentServer;
      updatedMatches[widget.matchIndex] = {
        ..._match,
        'liveScores': {
          ...currentScores,
          key: scores,
          opponentKey: opponentScores,
          'currentServer': _currentServer,
        },
      };
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': updatedMatches});
      setState(() {
        _match = updatedMatches[widget.matchIndex];
        _checkSetCompletion();
        _initializeServer();
      });
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text('Update Failed', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('Failed to update score: $e', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _decreaseScore(bool isTeam1) async {
    if (_isLoading || !mounted || _isSetComplete || _match['completed'] == true) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();
      final updatedMatches =
          List<Map<String, dynamic>>.from(tournamentDoc.data()!['matches']);
      final currentScores = Map<String, dynamic>.from(_match['liveScores']);
      final currentGame = currentScores['currentGame'] as int;
      final key =
          isTeam1 ? (widget.isDoubles ? 'team1' : 'player1') : (widget.isDoubles ? 'team2' : 'player2');
      final scores = List<int>.from(currentScores[key]);
      scores[currentGame - 1]--;
      scores[currentGame - 1] = scores[currentGame - 1].clamp(0, 30);
      _lastTeam1Score = List<int>.from(currentScores[widget.isDoubles ? 'team1' : 'player1'])[currentGame - 1];
      _lastTeam2Score = List<int>.from(currentScores[widget.isDoubles ? 'team2' : 'player2'])[currentGame - 1];
      _lastServer = _currentServer;
      updatedMatches[widget.matchIndex] = {
        ..._match,
        'liveScores': {
          ...currentScores,
          key: scores,
          'currentServer': _currentServer,
        },
      };
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': updatedMatches});
      setState(() {
        _match = updatedMatches[widget.matchIndex];
        _checkSetCompletion();
        _initializeServer();
      });
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text('Update Failed', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('Failed to update score: $e', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkMatchCompletion() {
    final currentGame = _match['liveScores']?['currentGame'] ?? 1;
    final team1Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
    final team2Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
    int team1Wins = 0;
    int team2Wins = 0;
    for (int i = 0; i < currentGame; i++) {
      if (_isSetWon(team1Scores[i], team2Scores[i])) {
        team1Wins++;
      } else if (_isSetWon(team2Scores[i], team1Scores[i])) {
        team2Wins++;
      }
    }
    if (team1Wins >= 2 || team2Wins >= 2) {
      _endMatch();
    }
  }

  bool _isSetWon(int score, int opponentScore) {
    return (score >= 21 && (score - opponentScore >= 2)) || score == 30;
  }

  void _checkSetCompletion() {
    final liveScores = _match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final team1Scores = List<int>.from(
        liveScores[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
    final team2Scores = List<int>.from(
        liveScores[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
    final currentSetScore = team1Scores[currentGame - 1];
    final opponentSetScore = team2Scores[currentGame - 1];
    bool isSetComplete = false;
    String? setWinner;
    if (_isSetWon(currentSetScore, opponentSetScore)) {
      isSetComplete = true;
      setWinner = widget.isDoubles ? 'team1' : 'player1';
    } else if (_isSetWon(opponentSetScore, currentSetScore)) {
      isSetComplete = true;
      setWinner = widget.isDoubles ? 'team2' : 'player2';
    }
    setState(() {
      _isSetComplete = isSetComplete;
      _lastSetWinner = setWinner;
    });
    if (isSetComplete) {
      _checkMatchCompletion();
    }
  }

  Future<void> _endMatch() async {
    if (_isLoading || !mounted || _match['completed'] == true) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();
      final updatedMatches =
          List<Map<String, dynamic>>.from(tournamentDoc.data()!['matches']);
      final currentScores = Map<String, dynamic>.from(_match['liveScores'] ?? {});
      final currentGame = currentScores['currentGame'] as int? ?? 1;
      final team1Scores = List<int>.from(
          currentScores[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
      final team2Scores = List<int>.from(
          currentScores[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
      int team1Wins = 0;
      int team2Wins = 0;
      for (int i = 0; i < currentGame; i++) {
        if (_isSetWon(team1Scores[i], team2Scores[i])) {
          team1Wins++;
        } else if (_isSetWon(team2Scores[i], team1Scores[i])) {
          team2Wins++;
        }
      }
      String? winner;
      String terminationReason = 'Match concluded normally';
      if (team1Wins >= 2) {
        winner = widget.isDoubles ? 'team1' : 'player1';
      } else if (team2Wins >= 2) {
        winner = widget.isDoubles ? 'team2' : 'player2';
      } else if (currentGame == 3 && team1Wins > team2Wins) {
        winner = widget.isDoubles ? 'team1' : 'player1';
      } else if (currentGame == 3 && team2Wins > team1Wins) {
        winner = widget.isDoubles ? 'team2' : 'player2';
      } else {
        terminationReason = 'Match terminated manually without a winner';
      }

      List<Map<String, dynamic>> updatedParticipants =
          List<Map<String, dynamic>>.from(tournamentDoc.data()!['participants'] ?? []);
      if (winner != null) {
        List<String> winnerIds;
        if (widget.isDoubles) {
          winnerIds = winner == 'team1'
              ? List<String>.from(_match['team1Ids'] ?? [])
              : List<String>.from(_match['team2Ids'] ?? []);
        } else {
          winnerIds = [
            winner == 'player1' ? _match['player1Id'] : _match['player2Id'],
          ];
        }
        updatedParticipants = updatedParticipants.map((p) {
          final participantId = p['id'] as String;
          if (winnerIds.contains(participantId)) {
            final currentScore = p['score'] as int? ?? 0;
            return {...p, 'score': currentScore + 2};
          }
          return p;
        }).toList();
      }

      updatedMatches[widget.matchIndex] = {
        ..._match,
        'completed': true,
        'winner': winner,
        'terminationReason': terminationReason,
        'liveScores': {
          ...currentScores,
          'isLive': false,
          'endTime': Timestamp.now(),
        },
      };
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({
        'participants': updatedParticipants,
        'matches': updatedMatches,
      });
      setState(() {
        _match = updatedMatches[widget.matchIndex];
        _countdownTimer?.cancel();
        _countdown = null;
      });
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text('Match Terminated', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text(
            winner != null
                ? 'Winner: ${winner == 'team1' || winner == 'player1' ? (widget.isDoubles ? _match['team1'].join(', ') : _match['player1']) : (widget.isDoubles ? _match['team2'].join(', ') : _match['player2'])}'
                : 'Match terminated without a winner: $terminationReason',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)),
          ),
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFF2A9D8F),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text('Error', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('Failed to terminate match: $e', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startNextSet() async {
    if (_isLoading || !mounted || !_isSetComplete || _match['completed'] == true) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();
      final updatedMatches =
          List<Map<String, dynamic>>.from(tournamentDoc.data()!['matches']);
      final currentScores = Map<String, dynamic>.from(_match['liveScores']);
      final currentGame = currentScores['currentGame'] as int;
      int team1Wins = 0;
      int team2Wins = 0;
      final team1Scores = List<int>.from(
          currentScores[widget.isDoubles ? 'team1' : 'player1']);
      final team2Scores = List<int>.from(
          currentScores[widget.isDoubles ? 'team2' : 'player2']);
      for (int i = 0; i < currentGame; i++) {
        if (_isSetWon(team1Scores[i], team2Scores[i])) {
          team1Wins++;
        } else if (_isSetWon(team2Scores[i], team1Scores[i])) {
          team2Wins++;
        }
      }
      if (team1Wins >= 2 || team2Wins >= 2) {
        await _endMatch();
        return;
      }
      if (currentGame >= 3) {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.warning,
            title: Text('Match Limit Reached', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
            description: Text('Maximum sets (3) reached. Please end the match.', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
            autoCloseDuration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFFE9C46A),
            foregroundColor: const Color(0xFFFDFCFB),
            alignment: Alignment.bottomCenter,
          );
        }
        return;
      }
      team1Scores[currentGame] = 0;
      team2Scores[currentGame] = 0;
      updatedMatches[widget.matchIndex] = {
        ..._match,
        'liveScores': {
          ...currentScores,
          'currentGame': currentGame + 1,
          widget.isDoubles ? 'team1' : 'player1': team1Scores,
          widget.isDoubles ? 'team2' : 'player2': team2Scores,
          'currentServer': _lastSetWinner,
        },
      };
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'matches': updatedMatches});
      setState(() {
        _match = updatedMatches[widget.matchIndex];
        _isSetComplete = false;
        _currentServer = _lastSetWinner;
        _lastServer = _currentServer;
      });
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: Text('Next Set Started', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('Set ${currentGame + 1} has begun.', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2A9D8F),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: Text('Error', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          description: Text('Failed to start next set: $e', style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB))),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFFE76F51),
          foregroundColor: const Color(0xFFFDFCFB),
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildScoreDisplay() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            badges.Badge(
              showBadge: _currentServer == (widget.isDoubles ? 'team1' : 'player1'),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: Color(0xFFF4A261),
              ),
              position: badges.BadgePosition.topEnd(end: -20, top: -10),
              badgeContent:
                  const Icon(Icons.sports_tennis, size: 12, color: Color(0xFFFDFCFB)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getCurrentScore(true)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFDFCFB),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '-',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFA8DADC),
                  fontSize: 32,
                ),
              ),
            ),
            badges.Badge(
              showBadge: _currentServer == (widget.isDoubles ? 'team2' : 'player2'),
              badgeStyle: const badges.BadgeStyle(
                badgeColor: Color(0xFFF4A261),
              ),
              position: badges.BadgePosition.topEnd(end: -20, top: -10),
              badgeContent:
                  const Icon(Icons.sports_tennis, size: 12, color: Color(0xFFFDFCFB)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_getCurrentScore(false)}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFDFCFB),
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showPlusOneTeam1)
          Positioned(
            left: 30,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A9D8F).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+1',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2A9D8F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_showPlusOneTeam2)
          Positioned(
            right: 30,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A9D8F).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+1',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF2A9D8F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Text(
          'POINT CONTROL',
          style: GoogleFonts.poppins(
            color: const Color(0xFFA8DADC),
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildScoreButton(
              label: 'POINT ',
              icon: Icons.add,
              onPressed: () => _updateLiveScore(true),
              isEnabled: !_isLoading,
              color: const Color.fromARGB(255, 29, 109, 112),
            ),
            _buildScoreButton(
              label: 'POINT ',
              icon: Icons.add,
              onPressed: () => _updateLiveScore(false),
              isEnabled: !_isLoading,
              color: const Color.fromARGB(255, 29, 109, 112),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildScoreButton(
              label: 'POINT ',
              icon: Icons.remove,
              onPressed: () => _decreaseScore(true),
              isEnabled: !_isLoading,
              color: const Color.fromARGB(255, 199, 160, 60),
            ),
            _buildScoreButton(
              label: 'POINT ',
              icon: Icons.remove,
              onPressed: () => _decreaseScore(false),
              isEnabled: !_isLoading,
              color: const Color.fromARGB(255, 199, 160, 60),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSetCompletionUI() {
    final currentGame = _match['liveScores']?['currentGame'] ?? 1;
    final team1Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
    final team2Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
    int team1Wins = 0;
    int team2Wins = 0;
    for (int i = 0; i < currentGame; i++) {
      if (_isSetWon(team1Scores[i], team2Scores[i])) {
        team1Wins++;
      } else if (_isSetWon(team2Scores[i], team1Scores[i])) {
        team2Wins++;
      }
    }
    final isMatchOver = team1Wins >= 2 || team2Wins >= 2;
    return Column(
      children: [
        Text(
          'Set $currentGame Completed',
          style: GoogleFonts.poppins(
            color: const Color(0xFFF4A261),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_lastSetWinner == (widget.isDoubles ? 'team1' : 'player1')
              ? (widget.isDoubles ? _match['team1'].join(' & ') : _match['player1'])
              : (widget.isDoubles ? _match['team2'].join(' & ') : _match['player2'])} won the set',
          style: GoogleFonts.poppins(
            color: const Color(0xFFFDFCFB),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 16),
        if (!isMatchOver && currentGame < 3)
          _buildModernButton(
            text: 'START SET ${currentGame + 1}',
            gradient: const LinearGradient(
              colors: [Color(0xFF6C9A8B), Color(0xFFC1DADB)],
            ),
            onPressed: _startNextSet,
            isLoading: _isLoading,
          ),
        const SizedBox(height: 12),
        _buildModernButton(
          text: isMatchOver ? 'CONCLUDE MATCH' : 'TERMINATE MATCH',
          gradient: const LinearGradient(
            colors: [Color(0xFFE76F51), Color(0xFFF4A261)],
          ),
          onPressed: _endMatch,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Widget _buildScoreButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isEnabled,
    required Color color,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isEnabled ? color.withOpacity(0.2) : const Color(0xFF757575).withOpacity(0.1),
          border: Border.all(
            color: isEnabled ? color : const Color(0xFF757575),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isEnabled ? color : const Color(0xFF757575)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isEnabled ? color : const Color(0xFF757575),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required LinearGradient gradient,
    required VoidCallback? onPressed,
    required bool isLoading,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D3557).withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFDFCFB)),
                ),
              )
            : Text(
                text,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFDFCFB),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  String _getServiceCourt(bool isTeam1) {
    final liveScores = _match['liveScores'] ?? {};
    final currentGame = liveScores['currentGame'] ?? 1;
    final scores = List<int>.from(
        liveScores[isTeam1 ? (widget.isDoubles ? 'team1' : 'player1') : (widget.isDoubles ? 'team2' : 'player2')] ?? [0, 0, 0]);
    return scores[currentGame - 1].isEven ? 'Right' : 'Left';
  }

  String? _getSetWinner(int setIndex) {
    final team1Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
    final team2Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
    if (_isSetWon(team1Scores[setIndex], team2Scores[setIndex])) {
      return widget.isDoubles ? _match['team1'].join(', ') : _match['player1'];
    } else if (_isSetWon(team2Scores[setIndex], team1Scores[setIndex])) {
      return widget.isDoubles ? _match['team2'].join(', ') : _match['player2'];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = _match['completed'] == true;
    final isLive = _match['liveScores']?['isLive'] == true;
    final currentGame = _match['liveScores']?['currentGame'] ?? 1;
    final team1Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
    final team2Scores = List<int>.from(
        _match['liveScores']?[widget.isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
    int team1Wins = 0;
    int team2Wins = 0;
    for (int i = 0; i < currentGame; i++) {
      if (_isSetWon(team1Scores[i], team2Scores[i])) {
        team1Wins++;
      } else if (_isSetWon(team2Scores[i], team1Scores[i])) {
        team2Wins++;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 2, 61, 65),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withOpacity(0.05),
                  border: Border(bottom: BorderSide(color: const Color(0xFFFDFCFB).withOpacity(0.1))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFFA8DADC)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Round ${_match['round']}',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFFDFCFB),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_matchStartTime != null && _tournamentTimezone != null)
                            Text(
                              '${DateFormat('MMM dd, yyyy HH:mm').format(_matchStartTime!)} ($_tournamentTimezone)',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFA8DADC),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimationConfiguration.synchronized(
                  duration: const Duration(milliseconds: 1000),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.isDoubles
                                            ? _match['team1'].join(', ')
                                            : _match['player1'],
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFFDFCFB),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (isLive &&
                                        _currentServer ==
                                            (widget.isDoubles ? 'team1' : 'player1'))
                                      Flexible(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.sports_tennis,
                                              size: 16,
                                              color: const Color(0xFFF4A261),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Serving (${_getServiceCourt(true)})',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(0xFFF4A261),
                                                  fontSize: MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              360
                                                          ? 10
                                                          : 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Set $currentGame',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFFA8DADC),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildScoreDisplay(),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFA8DADC).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$team1Wins',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFA8DADC),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFA8DADC).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$team2Wins',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFA8DADC),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.isDoubles
                                            ? _match['team2'].join(', ')
                                            : _match['player2'],
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFFFDFCFB),
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (isLive &&
                                        _currentServer ==
                                            (widget.isDoubles ? 'team2' : 'player2'))
                                      Flexible(
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.sports_tennis,
                                              size: 16,
                                              color: const Color(0xFFF4A261),
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Serving (${_getServiceCourt(false)})',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(0xFFF4A261),
                                                  fontSize: MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              360
                                                          ? 10
                                                          : 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (currentGame > 1)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            children: List.generate(currentGame - 1, (index) {
                              final winner = _getSetWinner(index);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  children: [
                                    Text(
                                      'Set ${index + 1}: ${team1Scores[index]} - ${team2Scores[index]}',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFFFDFCFB),
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (winner != null)
                                      Text(
                                        'Set ${index + 1} won by $winner',
                                        style: GoogleFonts.poppins(
                                          color: const Color(0xFF2A9D8F),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ),
                      if (!isCompleted)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: (!isLive)
                              ? Column(
                                  children: [
                                    if (_countdown != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'Countdown: $_countdown',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFFA8DADC),
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    _buildModernButton(
                                      text: _isLoading
                                          ? 'Starting...'
                                          : 'Start Match',
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2A9D8F), Color(0xFF6C9A8B)],
                                      ),
                                      onPressed: _startMatch,
                                      isLoading: _isLoading,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                )
                              : (_isSetComplete
                                  ? _buildSetCompletionUI()
                                  : _buildActionButtons()),
                        ),
                    ],
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