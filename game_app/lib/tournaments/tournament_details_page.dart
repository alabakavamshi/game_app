import 'dart:core';
import 'dart:math';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/models/tournament.dart';
import 'package:game_app/tournaments/match_details_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/timezone.dart';
import 'dart:io';
import 'package:toastification/toastification.dart';


extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

class TournamentDetailsPage extends StatefulWidget {
  final Tournament tournament;
  final String creatorName;

  const TournamentDetailsPage({
    super.key,
    required this.tournament,
    required this.creatorName,
  });

  @override
  State<TournamentDetailsPage> createState() => _TournamentDetailsPageState();
}

class _TournamentDetailsPageState extends State<TournamentDetailsPage>
    with SingleTickerProviderStateMixin {
        String? _tournamentProfileImage;
        
  bool _isLoading = false;
  bool _hasJoined = false;
  bool _showMatchGenerationOptions = false;
  bool _isUmpire = false;
  late TabController _tabController;
  late List<Map<String, dynamic>> _participants;
  late List<Map<String, dynamic>> _teams;
  late List<Map<String, dynamic>> _matches;
  final Map<String, Map<String, dynamic>> _leaderboardData = {};

  final Color _primaryColor = const Color(0xFF6C9A8B);
  final Color _secondaryColor = const Color(0xFFC1DADB);
  final Color _accentColor = const Color(0xFFF4A261);
  final Color _textColor = const Color(0xFF333333);
  final Color _secondaryText = const Color(0xFF757575);
  final Color _cardBackground = const Color(0xFFFFFFFF);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _warningColor = const Color(0xFFFFC107);
  final Color _errorColor = const Color(0xFFE76F51);
  final Color _goldColor = const Color(0xFFFFD700);
  final Color _silverColor = const Color(0xFFC0C0C0);
  final Color _bronzeColor = const Color(0xFFCD7F32);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _participants = List.from(widget.tournament.participants);
    _teams = List.from(widget.tournament.teams);
    _matches = List.from(widget.tournament.matches);
    _checkIfJoined();
    _checkIfUmpire();
    _generateLeaderboardData();
    _listenToTournamentUpdates();
  }

 void _listenToTournamentUpdates() {
  FirebaseFirestore.instance
      .collection('tournaments')
      .doc(widget.tournament.id)
      .snapshots()
      .listen((snapshot) async {
    if (!mounted) return;
    if (!snapshot.exists || snapshot.data() == null) {
      debugPrint('Tournament document does not exist or is empty');
      return;
    }
    final data = snapshot.data()!;
    try {
      // Load participants with names
      final participants = List<Map<String, dynamic>>.from(data['participants'] ?? []);
      final updatedParticipants = await _loadParticipantNames(participants);

      // Load teams with player names if doubles tournament
      List<Map<String, dynamic>> updatedTeams = [];
      if (_isDoublesTournament()) {
        updatedTeams = await _loadTeamPlayerNames(List<Map<String, dynamic>>.from(data['teams'] ?? []));
      } else {
        updatedTeams = List<Map<String, dynamic>>.from(data['teams'] ?? []);
      }

      // Validate matches
      final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);
      for (var match in matches) {
        if (!match.containsKey('matchId') || !match.containsKey('liveScores')) {
          debugPrint('Invalid match data: $match');
          continue;
        }
      }

      setState(() {
        _participants = updatedParticipants;
        _teams = updatedTeams;
        _matches = matches;
       
        _tournamentProfileImage = data['profileImage']?.toString();
      });
      await _generateLeaderboardData();
      await _updateNextRoundMatches();
    } catch (e) {
      debugPrint('Error processing tournament updates: $e');
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Update Error'),
        description: Text('Failed to process tournament data: $e'),
        autoCloseDuration: const Duration(seconds: 2),
      );
    }
  }, onError: (e) {
    debugPrint('Error in tournament updates: $e');
    toastification.show(
      context: context,
      type: ToastificationType.error,
      title: const Text('Update Error'),
      description: Text('Failed to update tournament data: $e'),
      autoCloseDuration: const Duration(seconds: 2),
    );
  });
}


Future<List<Map<String, dynamic>>> _loadParticipantNames(List<Map<String, dynamic>> participants) async {
  final updatedParticipants = <Map<String, dynamic>>[];
  
  for (var participant in participants) {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(participant['id'])
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        updatedParticipants.add({
          ...participant,
          'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
          'firstName': userData['firstName'],
          'lastName': userData['lastName'],
        });
      } else {
        updatedParticipants.add({
          ...participant,
          'name': 'Unknown Player',
          'firstName': 'Unknown',
          'lastName': '',
        });
      }
    } catch (e) {
      debugPrint('Error loading user ${participant['id']}: $e');
      updatedParticipants.add({
        ...participant,
        'name': 'Error Loading',
        'firstName': 'Error',
        'lastName': '',
      });
    }
  }
  
  return updatedParticipants;
}

Future<List<Map<String, dynamic>>> _loadTeamPlayerNames(List<Map<String, dynamic>> teams) async {
  final updatedTeams = <Map<String, dynamic>>[];
  
  for (var team in teams) {
    try {
      final updatedPlayers = <Map<String, dynamic>>[];
      
      for (var player in team['players']) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(player['id'])
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          updatedPlayers.add({
            ...player,
            'firstName': userData['firstName'],
            'lastName': userData['lastName'],
          });
        } else {
          updatedPlayers.add({
            ...player,
            'firstName': 'Unknown',
            'lastName': '',
          });
        }
      }
      
      updatedTeams.add({
        ...team,
        'players': updatedPlayers,
      });
    } catch (e) {
      debugPrint('Error loading team players: $e');
      updatedTeams.add(team);
    }
  }
  
  return updatedTeams;
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkIfJoined() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final userId = authState.user.uid;
      setState(() {
        _hasJoined = _participants.any((p) => p['id'] == userId);
      });
    }
  }

  void _checkIfUmpire() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final userEmail = authState.user.email;
      if (userEmail != null) {
        final umpireDoc = await FirebaseFirestore.instance
            .collection('umpire_credentials')
            .doc(userEmail)
            .get();
        if (mounted) {
          setState(() {
            _isUmpire = umpireDoc.exists;
          });
        }
      }
    }
  }

  Future<void> _resetMatches() async {
  if (_isLoading || !_canCreateMatches) return;

  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Reset All Matches?',
        style: GoogleFonts.poppins(
          color: _textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        'This will delete all current matches and allow you to generate new ones. This action cannot be undone.',
        style: GoogleFonts.poppins(
          color: _secondaryText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: _secondaryText,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Reset',
            style: GoogleFonts.poppins(
              color: _errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  setState(() {
    _isLoading = true;
  });

  try {
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .update({'matches': []});

    if (mounted) {
      setState(() {
        _matches = [];
        _showMatchGenerationOptions = true;
      });
      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: const Text('Matches Reset'),
        description: const Text('All matches have been successfully reset.'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _successColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
    }
  } catch (e) {
    if (mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Reset Failed'),
        description: Text('Failed to reset matches: $e'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  Future<void> _uploadTournamentImage() async {
  if (_isLoading) return;
  setState(() {
    _isLoading = true;
  });

  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final file = File(pickedFile.path);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('tournament_images/${widget.tournament.id}.jpg');
    await storageRef.putFile(file);
    final downloadUrl = await storageRef.getDownloadURL();

    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .update({'profileImage': downloadUrl});

    if (mounted) {
      setState(() {
        _tournamentProfileImage = downloadUrl;
      });
      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: const Text('Image Uploaded'),
        description: const Text('Tournament image updated successfully!'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _successColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
    }
  } catch (e) {
    if (mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Upload Failed'),
        description: Text('Failed to upload image: $e'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  void _showImageOptionsDialog(bool isCreator) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Image Options',
          style: GoogleFonts.poppins(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.visibility, color: _accentColor),
              title: Text(
                'View Image',
                style: GoogleFonts.poppins(
                  color: _textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showFullImageDialog();
              },
            ),
            if (isCreator)
              ListTile(
                leading: Icon(Icons.edit, color: _accentColor),
                title: Text(
                  'Edit Image',
                  style: GoogleFonts.poppins(
                    color: _textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _uploadTournamentImage();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: _secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImageDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: widget.tournament.profileImage != null &&
                      widget.tournament.profileImage!.isNotEmpty
                  ? Image.network(
                      widget.tournament.profileImage!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/tournament_placholder.jpg',
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      'assets/tournament_placholder.jpg',
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateLeaderboardData() async {
  final isDoubles = _isDoublesTournament();
  final competitors = isDoubles ? _teams : _participants;
  final groups = _computeGroups(
    competitors: competitors,
    matches: _matches,
    isDoubles: isDoubles,
  );

  _leaderboardData.clear(); // Clear existing data

  for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
    final groupCompetitors = groups[groupIndex];
    for (var competitor in groupCompetitors) {
      final competitorId = isDoubles ? competitor['teamId'] as String : competitor['id'] as String;
      String name;
      int score = 0;

      if (isDoubles) {
        final playerNames = competitor['players'].map((player) {
          final firstName = player['firstName'] ?? 'Unknown';
          final lastName = player['lastName']?.toString() ?? '';
          return '$firstName $lastName'.trim();
        }).toList();
        name = playerNames.join(' & ');

        // Calculate score for team based on matches
        for (var match in _matches) {
          if (match['completed'] == true && match['winner'] != null) {
            final winner = match['winner'] as String;
            final winningTeamIds = winner == 'team1'
                ? List<String>.from(match['team1Ids'])
                : List<String>.from(match['team2Ids']);
            final teamPlayerIds = competitor['players'].map((p) => p['id'] as String).toList();
            if (teamPlayerIds.every((id) => winningTeamIds.contains(id))) {
              score += 1;
            }
          }
        }
      } else {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(competitorId)
            .get();
        final userData = userDoc.data() ?? await _createDefaultUser(competitorId);
        final firstName = userData['firstName']?.toString() ?? 'Unknown';
        final lastName = userData['lastName']?.toString() ?? '';
        name = '$firstName $lastName'.trim();
        score = competitor['score'] as int? ?? 0;
      }

      _leaderboardData[competitorId] = {
        'name': name,
        'score': score,
        'group': groupIndex, // Store group index for filtering
      };
    }
  }

  if (mounted) {
    setState(() {});
  }
}
  Future<Map<String, dynamic>> _createDefaultUser(String userId) async {
    final defaultUser = {
      'createdAt': Timestamp.now(),
      'displayName': userId,
      'email': '$userId@unknown.com',
      'firstName': 'Unknown',
      'lastName': '',
      'gender': 'unknown',
      'phone': '',
      'profileImage': 'assets/default_profile.jpg',
      'updatedAt': Timestamp.now(),
    };
    await FirebaseFirestore.instance.collection('users').doc(userId).set(defaultUser);
    return defaultUser;
  }

  String? _getRequiredGender() {
    final gameFormat = widget.tournament.gameFormat.toLowerCase();
    if (gameFormat.contains("women's")) return 'female';
    if (gameFormat.contains("men's")) return 'male';
    return null;
  }

  bool _isDoublesTournament() {
    return widget.tournament.gameFormat.toLowerCase().contains('doubles');
  }

  Future<void> _generateTeams() async {
    if (!_isDoublesTournament()) {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .update({'teams': []});
      setState(() {
        _teams = [];
      });
      return;
    }

    final genderCounts = <String, int>{};
    for (var participant in _participants) {
      final gender = (participant['gender'] as String? ?? 'unknown').toLowerCase();
      genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;
    }
    final maleCount = genderCounts['male'] ?? 0;
    final femaleCount = genderCounts['female'] ?? 0;
    final minPairs = maleCount < femaleCount ? maleCount : femaleCount;

    final males = _participants
        .where((p) => (p['gender'] as String? ?? 'unknown').toLowerCase() == 'male')
        .toList();
    final females = _participants
        .where((p) => (p['gender'] as String? ?? 'unknown').toLowerCase() == 'female')
        .toList();

    males.shuffle();
    females.shuffle();

    final newTeams = <Map<String, dynamic>>[];
    for (int i = 0; i < minPairs; i++) {
      final maleData = await _getUserData(males[i]['id']);
      final femaleData = await _getUserData(females[i]['id']);
      final team = {
        'teamId': 'team_${newTeams.length + 1}',
        'players': [
          {
            'id': males[i]['id'],
            'gender': 'male',
            'firstName': maleData['firstName']?.toString() ?? 'Unknown',
            'lastName': maleData['lastName']?.toString() ?? '',
          },
          {
            'id': females[i]['id'],
            'gender': 'female',
            'firstName': femaleData['firstName']?.toString() ?? 'Unknown',
            'lastName': femaleData['lastName']?.toString() ?? '',
          },
        ],
      };
      newTeams.add(team);
    }

    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .update({'teams': newTeams});

    if (mounted) {
      setState(() {
        _teams = newTeams;
      });
    }
  }

Future<String> _getDisplayName(String userId) async {
  if (userId == 'TBD') return 'TBD';
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final userData = userDoc.data();
  return userData != null
      ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim()
      : 'TBD';
}

  Future<Map<String, dynamic>> _getUserData(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return userDoc.data() ?? await _createDefaultUser(userId);
  }

  

  Future<void> _generateMatches() async {
    if (_isLoading || !_canCreateMatches) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final existingMatches = {
        for (var match in _matches) match['matchId'] as String: match
      };

      final newMatches = <Map<String, dynamic>>[];
      final updatedParticipants = _participants.map((p) => {...p, 'score': 0}).toList();

      DateTime matchStartDate = widget.tournament.startDate;
      final startHour = widget.tournament.startDate.hour;
final startMinute = widget.tournament.startDate.minute;
      if (_isDoublesTournament()) {
        if (_teams.length < 2) {
          throw 'Need at least 2 teams to schedule matches.';
        }

        switch (widget.tournament.gameType.toLowerCase()) {
          case 'knockout':
  final shuffledParticipants = List<Map<String, dynamic>>.from(_participants)..shuffle();
  List<Map<String, dynamic>> currentRoundParticipants = shuffledParticipants;
  int round = 1;
  int matchIndex = 0;

  print('DEBUG: Starting knockout generation with ${currentRoundParticipants.length} participants');

  while (currentRoundParticipants.length > 1) {
    final nextRoundParticipants = <Map<String, dynamic>>[];
    final nextRoundMatches = <Map<String, dynamic>>[];

    print('DEBUG: Generating matches for round $round, participants: ${currentRoundParticipants.map((p) => p['id']).toList()}');

    for (int i = 0; i < currentRoundParticipants.length - 1; i += 2) {
      final player1 = currentRoundParticipants[i];
      final player2 = currentRoundParticipants[i + 1];
      final matchId = 'match_${player1['id']}_vs_${player2['id']}_r$round';
      print('DEBUG: Creating match $matchId for round $round');

      if (!existingMatches.containsKey(matchId)) {
        newMatches.add({
          'matchId': matchId,
          'round': round,
          'player1': await _getDisplayName(player1['id']),
          'player2': await _getDisplayName(player2['id']),
          'player1Id': player1['id'],
          'player2Id': player2['id'],
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            matchStartDate.year,
            matchStartDate.month,
            matchStartDate.day + matchIndex,
            startHour,
            startMinute,
          )),
          'winnerMatchId': null,
        });
        matchIndex++;
      }

      // Create or link to next round match
      if (round == 1 && currentRoundParticipants.length == 4) {
        // For 4 players, create one second-round match for both first-round winners
        final nextRoundMatchId = 'match_r2_final';
        if (!existingMatches.containsKey(nextRoundMatchId)) {
          print('DEBUG: Creating next round match $nextRoundMatchId with winnerMatchId $matchId');
          nextRoundMatches.add({
            'matchId': nextRoundMatchId,
            'round': round + 1,
            'player1': null,
            'player2': null,
            'player1Id': null,
            'player2Id': null,
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'player1': [0, 0, 0],
              'player2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'player1',
            },
            'startTime': null,
            'winnerMatchId': matchId, // Link to first first-round match
          });
        }
        nextRoundParticipants.add({'id': null, 'winnerMatchId': matchId});
      } else if (currentRoundParticipants.length > 2) {
        // For larger tournaments, create next-round matches dynamically
        final nextRoundMatchId = 'match_r${round + 1}_m${(i ~/ 2) + 1}';
        if (!existingMatches.containsKey(nextRoundMatchId)) {
          print('DEBUG: Creating next round match $nextRoundMatchId with winnerMatchId $matchId');
          nextRoundMatches.add({
            'matchId': nextRoundMatchId,
            'round': round + 1,
            'player1': null,
            'player2': null,
            'player1Id': null,
            'player2Id': null,
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'player1': [0, 0, 0],
              'player2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'player1',
            },
            'startTime': null,
            'winnerMatchId': matchId,
          });
        }
        nextRoundParticipants.add({'id': null, 'winnerMatchId': matchId});
      }
    }

    if (currentRoundParticipants.length % 2 != 0) {
      final byePlayer = currentRoundParticipants.last;
      final byeMatchId = 'match_${byePlayer['id']}_bye_r$round';
      print('DEBUG: Creating bye match $byeMatchId for player ${byePlayer['id']}');
      if (!existingMatches.containsKey(byeMatchId)) {
        newMatches.add({
          'matchId': byeMatchId,
          'round': round,
          'player1': await _getDisplayName(byePlayer['id']),
          'player2': 'Bye',
          'player1Id': byePlayer['id'],
          'player2Id': 'bye',
          'completed': true,
          'winner': 'player1',
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            matchStartDate.year,
            matchStartDate.month,
            matchStartDate.day + matchIndex,
            startHour,
            startMinute,
          )),
          'winnerMatchId': null,
        });
        matchIndex++;
      }
      nextRoundParticipants.add({'id': byePlayer['id'], 'winnerMatchId': byeMatchId});
    }

    newMatches.addAll(nextRoundMatches);
    currentRoundParticipants = nextRoundParticipants;
    round++;
  }
  print('DEBUG: Generated matches: ${newMatches.map((m) => m['matchId']).toList()}');
  break;

          case 'double elimination':
            newMatches.addAll(await _generateDoubleEliminationMatches(
              competitors: _teams,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
            ));
            break;

          case 'round-robin':
            final competitors = List<Map<String, dynamic>>.from(_teams);
            final numCompetitors = competitors.length;
            final isOdd = numCompetitors.isOdd;
            if (isOdd) {
              competitors.add({
                'teamId': 'bye',
                'players': [{'id': 'bye', 'firstName': 'Bye', 'lastName': ''}]
              });
            }
            final n = competitors.length;
            final totalRounds = n - 1;
            final matchesPerRound = n ~/ 2;
            final rounds = <List<Map<String, dynamic>>>[];
            for (var i = 0; i < totalRounds; i++) {
              rounds.add([]);
            }

            for (var round = 0; round < totalRounds; round++) {
              for (var i = 0; i < matchesPerRound; i++) {
                final team1 = competitors[i];
                final team2 = competitors[n - 1 - i];
                if (team1['teamId'] == 'bye' || team2['teamId'] == 'bye') continue;
                final team1Names = team1['players']
                    .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                    .toList();
                final team2Names = team2['players']
                    .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                    .toList();
                final team1Ids = team1['players'].map((p) => p['id']).toList();
                final team2Ids = team2['players'].map((p) => p['id']).toList();
                final matchId = 'match_${team1Ids.join('_')}_vs_${team2Ids.join('_')}';

                if (!existingMatches.containsKey(matchId)) {
                  rounds[round].add({
                    'matchId': matchId,
                    'round': round + 1,
                    'team1': team1Names,
                    'team2': team2Names,
                    'team1Ids': team1Ids,
                    'team2Ids': team2Ids,
                    'completed': false,
                    'winner': null,
                    'umpire': {'name': '', 'email': '', 'phone': ''},
                    'liveScores': {
                      'team1': [0, 0, 0],
                      'team2': [0, 0, 0],
                      'currentGame': 1,
                      'isLive': false,
                      'currentServer': 'team1',
                    },
                  });
                }
              }
              final temp = competitors.sublist(1, n - 1);
              competitors.setRange(1, n - 1, temp.sublist(1)..add(temp[0]));
            }

            final playerLastPlayDate = <String, DateTime>{};
            for (var round in rounds) {
              for (var match in round) {
                final team1Ids = List<String>.from(match['team1Ids']);
                final team2Ids = List<String>.from(match['team2Ids']);
                final allPlayerIds = [...team1Ids, ...team2Ids];
                DateTime candidateDate = matchStartDate;
                bool conflict;
                do {
                  conflict = false;
                  for (var playerId in allPlayerIds) {
                    final lastPlayDate = playerLastPlayDate[playerId];
                    if (lastPlayDate != null &&
                        candidateDate.difference(lastPlayDate).inDays.abs() < 1) {
                      conflict = true;
                      candidateDate = candidateDate.add(const Duration(days: 1));
                      break;
                    }
                  }
                } while (conflict);
                match['startTime'] = Timestamp.fromDate(DateTime(
                  candidateDate.year,
                  candidateDate.month,
                  candidateDate.day,
                  startHour,
                  startMinute,
                ));
                for (var playerId in allPlayerIds) {
                  playerLastPlayDate[playerId] = candidateDate;
                }
                newMatches.add(match);
                matchStartDate = candidateDate.add(const Duration(days: 1));
              }
            }
            break;

          case 'group + knockout':
            newMatches.addAll(await _generateGroupKnockoutMatches(
              competitors: _teams,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
            ));
            break;

          case 'team format':
            newMatches.addAll(await _generateTeamFormatMatches(
              competitors: _teams,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
            ));
            break;

          case 'ladder':
            newMatches.addAll(await _generateLadderMatches(
              competitors: _teams,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
            ));
            break;

          case 'swiss format':
            newMatches.addAll(await _generateSwissMatches(
              competitors: _teams,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
            ));
            break;

          default:
            throw 'Unsupported tournament type: ${widget.tournament.gameType}';
        }
      } else {
        if (_participants.length < 2) {
          throw 'Need at least 2 participants to schedule matches.';
        }

        switch (widget.tournament.gameType.toLowerCase()) {
          case 'knockout':
            final shuffledParticipants = List<Map<String, dynamic>>.from(_participants)..shuffle();
            List<Map<String, dynamic>> currentRoundParticipants = shuffledParticipants;
            int round = 1;
            int matchIndex = 0;

            while (currentRoundParticipants.length > 1) {
              final nextRoundParticipants = <Map<String, dynamic>>[];
              for (int i = 0; i < currentRoundParticipants.length - 1; i += 2) {
                final player1 = currentRoundParticipants[i];
                final player2 = currentRoundParticipants[i + 1];
                final matchId = 'match_${player1['id']}_vs_${player2['id']}_r$round';
                if (!existingMatches.containsKey(matchId)) {
                  newMatches.add({
                    'matchId': matchId,
                    'round': round,
                    'player1': await _getDisplayName(player1['id']),
                    'player2': await _getDisplayName(player2['id']),
                    'player1Id': player1['id'],
                    'player2Id': player2['id'],
                    'completed': false,
                    'winner': null,
                    'umpire': {'name': '', 'email': '', 'phone': ''},
                    'liveScores': {
                      'player1': [0, 0, 0],
                      'player2': [0, 0, 0],
                      'currentGame': 1,
                      'isLive': false,
                      'currentServer': 'player1',
                    },
                    'startTime': round == 1
                        ? Timestamp.fromDate(DateTime(
                            matchStartDate.year,
                            matchStartDate.month,
                            matchStartDate.day + matchIndex,
                            startHour,
                            startMinute,
                          ))
                        : null,
                    'winnerMatchId': null,
                  });
                  matchIndex++;
                }
                nextRoundParticipants.add({'id': 'TBD', 'winnerMatchId': matchId});
              }
              if (currentRoundParticipants.length % 2 != 0) {
                nextRoundParticipants.add(currentRoundParticipants.last); // Bye or unpaired participant
              }
              currentRoundParticipants = nextRoundParticipants;
              round++;
            }
            break;

          case 'double elimination':
            newMatches.addAll(await _generateDoubleEliminationMatches(
              competitors: _participants,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
              isDoubles: false,
            ));
            break;

          case 'round-robin':
            final competitors = List<Map<String, dynamic>>.from(_participants);
            final numCompetitors = competitors.length;
            final isOdd = numCompetitors.isOdd;
            if (isOdd) {
              competitors.add({
                'id': 'bye',
                'firstName': 'Bye',
                'lastName': '',
                'name': 'Bye',
                'gender': 'none',
                'score': 0,
              });
            }
            final n = competitors.length;
            final totalRounds = n - 1;
            final matchesPerRound = n ~/ 2;
            final rounds = List.generate(totalRounds, (_) => <Map<String, dynamic>>[]);

            // Generate round-robin schedule using the circle method
            for (var round = 0; round < totalRounds; round++) {
              for (var i = 0; i < matchesPerRound; i++) {
                // Pair competitors: i vs (n-1-i) in first round, then rotate
                final player1Index = i;
                final player2Index = n - 1 - i;

                // Adjust indices for rotation, keeping last competitor fixed
                final adjustedPlayer1Index = (player1Index + round) % (n - 1);
                final adjustedPlayer2Index = (player2Index + round) % (n - 1);

                final player1 = (player1Index == n - 1)
                    ? competitors[n - 1]
                    : competitors[adjustedPlayer1Index];
                final player2 = (player2Index == n - 1)
                    ? competitors[n - 1]
                    : competitors[adjustedPlayer2Index];

                if (player1['id'] == 'bye' || player2['id'] == 'bye') continue;

                final matchId = 'match_${player1['id']}_vs_${player2['id']}';

                if (!existingMatches.containsKey(matchId)) {
                  rounds[round].add({
                    'matchId': matchId,
                    'round': round + 1,
                    'player1': await _getDisplayName(player1['id']),
                    'player2': await _getDisplayName(player2['id']),
                    'player1Id': player1['id'],
                    'player2Id': player2['id'],
                    'completed': false,
                    'winner': null,
                    'umpire': {'name': '', 'email': '', 'phone': ''},
                    'liveScores': {
                      'player1': [0, 0, 0],
                      'player2': [0, 0, 0],
                      'currentGame': 1,
                      'isLive': false,
                      'currentServer': 'player1',
                    },
                  });
                }
              }

              // Rotate competitors (circle method: fix one, rotate others)
              if (round < totalRounds - 1) {
                final last = competitors[n - 1];
                for (var i = n - 1; i > 1; i--) {
                  competitors[i] = competitors[i - 1];
                }
                competitors[1] = last;
              }
            }

            final playerLastPlayDate = <String, DateTime>{};
            for (var round in rounds) {
              for (var match in round) {
                final player1Id = match['player1Id'] as String;
                final player2Id = match['player2Id'] as String;
                DateTime candidateDate = matchStartDate;
                bool conflict;
                do {
                  conflict = false;
                  for (var playerId in [player1Id, player2Id]) {
                    final lastPlayDate = playerLastPlayDate[playerId];
                    if (lastPlayDate != null &&
                        candidateDate.difference(lastPlayDate).inDays.abs() < 1) {
                      conflict = true;
                      candidateDate = candidateDate.add(const Duration(days: 1));
                      break;
                    }
                  }
                } while (conflict);
                match['startTime'] = Timestamp.fromDate(DateTime(
                  candidateDate.year,
                  candidateDate.month,
                  candidateDate.day,
                  startHour,
                  startMinute,
                ));
                playerLastPlayDate[player1Id] = candidateDate;
                playerLastPlayDate[player2Id] = candidateDate;
                newMatches.add(match);
                matchStartDate = candidateDate.add(const Duration(days: 1));
              }
            }
            break;

          case 'group + knockout':
            newMatches.addAll(await _generateGroupKnockoutMatches(
              competitors: _participants,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
              isDoubles: false,
            ));
            break;

          case 'team format':
            newMatches.addAll(await _generateTeamFormatMatches(
              competitors: _participants,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
              isDoubles: false,
            ));
            break;

          case 'ladder':
            newMatches.addAll(await _generateLadderMatches(
              competitors: _participants,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
              isDoubles: false,
            ));
            break;

          case 'swiss format':
            newMatches.addAll(await _generateSwissMatches(
              competitors: _participants,
              existingMatches: existingMatches,
              startDate: matchStartDate,
              startHour: startHour,
              startMinute: startMinute,
              isDoubles: false,
            ));
            break;

          default:
            throw 'Unsupported tournament type: ${widget.tournament.gameType}';
        }
      }

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .update({'participants': updatedParticipants, 'matches': newMatches});

      if (mounted) {
        setState(() {
          _participants = updatedParticipants;
          _matches = newMatches;
          _showMatchGenerationOptions = false;
        });
        await _generateLeaderboardData();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Matches Scheduled'),
          description: const Text('Match schedule has been successfully generated!'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _successColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to generate matches: $e'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
}

  Future<void> _updateNextRoundMatches() async {
  final matches = List<Map<String, dynamic>>.from(_matches);
  bool updated = false;
  final isDoubles = _isDoublesTournament();
  final isGroupKnockout = widget.tournament.gameType.toLowerCase() == 'group + knockout';

  print('DEBUG: Starting _updateNextRoundMatches. isDoubles: $isDoubles, isGroupKnockout: $isGroupKnockout, Total matches: ${matches.length}');

  if (isGroupKnockout) {
    // Check if all group stage matches are completed
    final groupMatches = matches.where((m) => m['phase'] == 'group').toList();
    final allGroupMatchesCompleted = groupMatches.every((m) => m['completed'] == true && m['winner'] != null);
    print('DEBUG: Group stage matches: ${groupMatches.length}, all completed: $allGroupMatchesCompleted');

    if (!allGroupMatchesCompleted) {
      print('DEBUG: Group stage incomplete, skipping knockout match updates');
      return;
    }

    // Calculate group stage rankings
    final groupRankings = <String, List<Map<String, dynamic>>>{};
    final groups = _participants.fold<Map<String, List<Map<String, dynamic>>>>(
      {},
      (acc, p) {
        final group = p['group'] ?? 'A'; // Default to group A for single-group tournaments
        acc[group] = acc[group] ?? [];
        acc[group]!.add({...p, 'score': p['score'] ?? 0});
        return acc;
      },
    );

    for (var group in groups.keys) {
      final groupParticipants = groups[group]!;
      final groupMatches = matches.where((m) => m['group'] == group && m['phase'] == 'group' && m['completed'] == true).toList();

      // Update scores based on match results
      for (var participant in groupParticipants) {
        int score = 0;
        for (var match in groupMatches) {
          if (match['winner'] == 'player1' && match['player1Id'] == participant['id']) {
            score += 2;
          } else if (match['winner'] == 'player2' && match['player2Id'] == participant['id']) {
            score += 2;
          }
        }
        participant['score'] = score;
      }

      // Sort by score (descending)
      groupParticipants.sort((a, b) => b['score'].compareTo(a['score']));
      groupRankings[group] = groupParticipants.take(2).toList(); // Top 2 per group
    }

    // Update knockout matches with qualifiers
    final qualifiers = groupRankings.values.expand((list) => list).toList();
    qualifiers.shuffle(); // Random seeding
    print('DEBUG: Qualifiers for knockout: ${qualifiers.map((q) => q['id']).toList()}');

    for (var match in matches) {
     if (match['phase'] == 'knockout' && match['round'] == groupMatches.map((m) => m['round'] as int).reduce((a, b) => a > b ? a : b) + 1){
        print('DEBUG: Processing knockout match ${match['matchId']} in round ${match['round']}');
        if (qualifiers.isEmpty) {
          print('DEBUG: WARNING - No qualifiers available for match ${match['matchId']}');
          continue;
        }
        final player1 = qualifiers.removeAt(0);
        final player2 = qualifiers.isNotEmpty ? qualifiers.removeAt(0) : null;

        if (player2 == null) {
          // Bye match
          print('DEBUG: Updating match ${match['matchId']} with player1: ${player1['name']}, player2: Bye');
          match['player1'] = await _getDisplayName(player1['id']);
          match['player1Id'] = player1['id'];
          match['player2'] = 'Bye';
          match['player2Id'] = 'bye';
          match['completed'] = true;
          match['winner'] = 'player1';
          match['qualifierInfo'] = {
            'player1': 'Group ${groupRankings.keys.firstWhere((k) => groupRankings[k]!.contains(player1))} #${groupRankings.values.firstWhere((v) => v.contains(player1)).indexOf(player1) + 1}',
            'player2': 'Bye',
          };
          updated = true;
        } else {
          print('DEBUG: Updating match ${match['matchId']} with player1: ${player1['name']}, player2: ${player2['name']}');
          match['player1'] = await _getDisplayName(player1['id']);
          match['player1Id'] = player1['id'];
          match['player2'] = await _getDisplayName(player2['id']);
          match['player2Id'] = player2['id'];
          match['qualifierInfo'] = {
            'player1': 'Group ${groupRankings.keys.firstWhere((k) => groupRankings[k]!.contains(player1))} #${groupRankings.values.firstWhere((v) => v.contains(player1)).indexOf(player1) + 1}',
            'player2': 'Group ${groupRankings.keys.firstWhere((k) => groupRankings[k]!.contains(player2))} #${groupRankings.values.firstWhere((v) => v.contains(player2)).indexOf(player2) + 1}',
          };
          updated = true;
        }
        if (match['startTime'] == null) {
          match['startTime'] = Timestamp.fromDate(DateTime(
            widget.tournament.startDate.year,
            widget.tournament.startDate.month,
           widget.tournament.startDate.day + (match['round'] as num).toInt() - 1,
          widget.tournament.startDate.hour,
widget.tournament.startDate.minute,
          ));
          print('DEBUG: Set startTime for match ${match['matchId']} to ${match['startTime'].toDate()}');
        }
      }
    }
  } else {
    // Existing logic for knockout tournaments
    final firstRoundMatchIds = matches
        .where((m) => m['round'] == 1)
        .map((m) => m['matchId'] as String)
        .toList();
    print('DEBUG: First-round match IDs: $firstRoundMatchIds');

    for (var match in matches) {
      if (match['completed'] != true || match['winner'] == null) {
        print('DEBUG: Skipping match ${match['matchId']}: completed=${match['completed']}, winner=${match['winner']}');
        continue;
      }

      print('DEBUG: Processing completed match ${match['matchId']} in round ${match['round']}, winner: ${match['winner']}');

      final winnerId = match['winner'] == (isDoubles ? 'team1' : 'player1')
          ? (isDoubles ? match['team1Ids'] : match['player1Id'])
          : (isDoubles ? match['team2Ids'] : match['player2Id']);
      final winnerName = match['winner'] == (isDoubles ? 'team1' : 'player1')
          ? (isDoubles ? match['team1'] : match['player1'])
          : (isDoubles ? match['team2'] : match['player2']);

      bool winnerAssigned = false;
      for (var nextMatch in matches) {
        if (nextMatch['round'] == match['round'] + 1 && firstRoundMatchIds.contains(match['matchId'])) {
          print('DEBUG: Checking next match ${nextMatch['matchId']} in round ${nextMatch['round']} for first-round match ${match['matchId']}');

          if ((nextMatch[isDoubles ? 'team1Ids' : 'player1Id'] == null ||
                  nextMatch[isDoubles ? 'team1Ids' : 'player1Id'] == 'TBD') &&
              nextMatch[isDoubles ? 'team2Ids' : 'player2Id'] != winnerId) {
            print('DEBUG: Updating slot 1 for match ${nextMatch['matchId']} with winner $winnerName');
            if (isDoubles) {
              nextMatch['team1Ids'] = List.from(winnerId);
              nextMatch['team1'] = List.from(winnerName);
            } else {
              nextMatch['player1Id'] = winnerId;
              nextMatch['player1'] = winnerName;
            }
            updated = true;
            winnerAssigned = true;
          } else if ((nextMatch[isDoubles ? 'team2Ids' : 'player2Id'] == null ||
                      nextMatch[isDoubles ? 'team2Ids' : 'player2Id'] == 'TBD') &&
                     nextMatch[isDoubles ? 'team1Ids' : 'player1Id'] != winnerId) {
            print('DEBUG: Updating slot 2 for match ${nextMatch['matchId']} with winner $winnerName');
            if (isDoubles) {
              nextMatch['team2Ids'] = List.from(winnerId);
              nextMatch['team2'] = List.from(winnerName);
            } else {
              nextMatch['player2Id'] = winnerId;
              nextMatch['player2'] = winnerName;
            }
            updated = true;
            winnerAssigned = true;
          } else {
            print('DEBUG: WARNING - Cannot assign winner to match ${nextMatch['matchId']}: '
                  'player1/team1=${nextMatch[isDoubles ? 'team1Ids' : 'player1Id']}, '
                  'player2/team2=${nextMatch[isDoubles ? 'team2Ids' : 'player2Id']}');
          }

          if (nextMatch['startTime'] == null) {
            final prevMatchTime = match['startTime'] as Timestamp?;
            if (prevMatchTime != null) {
              nextMatch['startTime'] = Timestamp.fromDate(
                prevMatchTime.toDate().add(const Duration(days: 1)),
              );
              print('DEBUG: Set startTime for match ${nextMatch['matchId']} to ${nextMatch['startTime'].toDate()}');
              updated = true;
            } else {
              print('DEBUG: WARNING - Previous match ${match['matchId']} has no startTime');
            }
          }
        }
      }

      if (!winnerAssigned) {
        print('DEBUG: WARNING - No next match found for winner of ${match['matchId']}');
      }
    }
  }

  // Debug pass for remaining TBD slots
  print('DEBUG: Checking for remaining TBD slots in knockout matches');
  for (var match in matches) {
    if (match['phase'] == 'knockout' &&
        ((match[isDoubles ? 'team1Ids' : 'player1Id'] == 'TBD' ||
          match[isDoubles ? 'team1Ids' : 'player1Id'] == null ||
          match[isDoubles ? 'team2Ids' : 'player2Id'] == 'TBD' ||
          match[isDoubles ? 'team2Ids' : 'player2Id'] == null))) {
      print('DEBUG: WARNING - Match ${match['matchId']} in round ${match['round']} has TBD slots: '
            'player1/team1=${match[isDoubles ? 'team1Ids' : 'player1Id']}, '
            'player2/team2=${match[isDoubles ? 'team2Ids' : 'player2Id']}');
    }
  }

  if (updated) {
    print('DEBUG: Updating Firestore with modified matches');
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .update({'matches': matches});

    if (mounted) {
      setState(() {
        _matches = matches;
      });
      print('DEBUG: State updated with new matches');
      await _generateLeaderboardData();
      print('DEBUG: Leaderboard data regenerated');
    }
  } else {
    print('DEBUG: No updates made to matches');
  }
}


Future<List<Map<String, dynamic>>> _generateDoubleEliminationMatches({
  required List<Map<String, dynamic>> competitors,
  required Map<String, Map<String, dynamic>> existingMatches,
  required DateTime startDate,
  required int startHour,
  required int startMinute,
  bool isDoubles = false,
}) async {
  final newMatches = <Map<String, dynamic>>[];
  final shuffledCompetitors = List<Map<String, dynamic>>.from(competitors)..shuffle();
  final n = shuffledCompetitors.length;
  if (n < 2) {
    throw Exception('Need at least 2 competitors for double elimination.');
  }

  final playerLastPlayDate = <String, DateTime>{};
  DateTime currentDate = startDate;

  // Winners' Bracket
  List<Map<String, dynamic>> winnersBracket = shuffledCompetitors;
  int winnersRound = 1;

  while (winnersBracket.length > 1) {
    final nextRoundCompetitors = <Map<String, dynamic>>[];
    for (int i = 0; i < winnersBracket.length - 1; i += 2) {
      final competitor1 = winnersBracket[i];
      final competitor2 = winnersBracket[i + 1];

      // Validate competitor data
      final comp1Id = competitor1['id'] as String? ?? '';
      final comp2Id = competitor2['id'] as String? ?? '';
      if (comp1Id.isEmpty || comp2Id.isEmpty) {
        print('Warning: Skipping match due to missing competitor ID at index $i');
        continue;
      }

      String matchId;
      Map<String, dynamic> match;

      if (isDoubles) {
        final team1Ids = (competitor1['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
        final team2Ids = (competitor2['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
        if (team1Ids.contains(null) || team2Ids.contains(null)) {
          print('Warning: Skipping match due to invalid team data at index $i');
          continue;
        }
        matchId = 'wb_match_${team1Ids.join('_')}_vs_${team2Ids.join('_')}_r$winnersRound';
        if (!existingMatches.containsKey(matchId)) {
          bool conflict;
          do {
            conflict = false;
            for (var playerId in [...team1Ids, ...team2Ids]) {
              if (playerId == null) continue;
              final lastPlayDate = playerLastPlayDate[playerId];
              if (lastPlayDate != null &&
                  currentDate.difference(lastPlayDate).inDays.abs() < 1) {
                conflict = true;
                currentDate = currentDate.add(const Duration(days: 1));
                break;
              }
            }
          } while (conflict);

          match = {
            'matchId': matchId,
            'round': winnersRound,
            'bracket': 'winners',
            'team1': (competitor1['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? [],
            'team2': (competitor2['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? [],
            'team1Ids': team1Ids,
            'team2Ids': team2Ids,
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'team1': [0, 0, 0],
              'team2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'team1',
            },
            'startTime': Timestamp.fromDate(DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              startHour,
              startMinute,
            )),
          };
          newMatches.add(match);
          for (var playerId in [...team1Ids, ...team2Ids]) {
            if (playerId != null) playerLastPlayDate[playerId] = currentDate;
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }
      } else {
        matchId = 'wb_match_${comp1Id}_vs_${comp2Id}_r$winnersRound';
        if (!existingMatches.containsKey(matchId)) {
          bool conflict;
          do {
            conflict = false;
            for (var playerId in [comp1Id, comp2Id]) {
              final lastPlayDate = playerLastPlayDate[playerId];
              if (lastPlayDate != null &&
                  currentDate.difference(lastPlayDate).inDays.abs() < 1) {
                conflict = true;
                currentDate = currentDate.add(const Duration(days: 1));
                break;
              }
            }
          } while (conflict);

          match = {
            'matchId': matchId,
            'round': winnersRound,
            'bracket': 'winners',
            'player1': await _getDisplayName(comp1Id),
            'player2': await _getDisplayName(comp2Id),
            'player1Id': comp1Id,
            'player2Id': comp2Id,
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'player1': [0, 0, 0],
              'player2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'player1',
            },
            'startTime': Timestamp.fromDate(DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              startHour,
              startMinute,
            )),
          };
          newMatches.add(match);
          playerLastPlayDate[comp1Id] = currentDate;
          playerLastPlayDate[comp2Id] = currentDate;
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
      nextRoundCompetitors.add({'id': 'TBD', 'winnerMatchId': matchId});
    }
    if (winnersBracket.length % 2 != 0) {
      final lastCompetitor = winnersBracket.last;
      final lastCompId = lastCompetitor['id'] as String? ?? '';
      if (lastCompId.isNotEmpty && lastCompId != 'bye') {
        nextRoundCompetitors.add(lastCompetitor);
        if (!isDoubles) {
          playerLastPlayDate[lastCompId] = currentDate;
        } else {
          final teamIds = (lastCompetitor['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
          for (var playerId in teamIds) {
            if (playerId != null) {
              playerLastPlayDate[playerId] = currentDate;
            }
          }
        }
      }
    }
    winnersBracket = nextRoundCompetitors;
    winnersRound++;
  }

  // Losers' Bracket
  List<Map<String, dynamic>> losersBracket = [];
  int losersRound = 1;
  final winnersRound1Matches = newMatches.where((m) => m['bracket'] == 'winners' && m['round'] == 1).toList();

  // Initialize losers' bracket with losers from winners' round 1
  for (var match in winnersRound1Matches) {
    losersBracket.add({'id': 'TBD', 'loserMatchId': match['matchId']});
  }

  // Generate losers' bracket matches
  int winnersRoundToProcess = 2;
  while (losersBracket.length > 1) {
    final nextRoundCompetitors = <Map<String, dynamic>>[];
    for (int i = 0; i < losersBracket.length - 1; i += 2) {
      final competitor1 = losersBracket[i];
      final competitor2 = losersBracket[i + 1];

      final comp1Id = competitor1['id'] as String? ?? 'TBD';
      final comp2Id = competitor2['id'] as String? ?? 'TBD';

      final matchId = 'lb_match_${comp1Id}_vs_${comp2Id}_r$losersRound';
      if (!existingMatches.containsKey(matchId)) {
        bool conflict;
        do {
          conflict = false;
          for (var playerId in [comp1Id, comp2Id]) {
            if (playerId == 'TBD' || playerId.isEmpty) continue;
            final lastPlayDate = playerLastPlayDate[playerId];
            if (lastPlayDate != null &&
                currentDate.difference(lastPlayDate).inDays.abs() < 1) {
              conflict = true;
              currentDate = currentDate.add(const Duration(days: 1));
              break;
            }
          }
        } while (conflict);

        final match = {
          'matchId': matchId,
          'round': losersRound,
          'bracket': 'losers',
          'player1': comp1Id == 'TBD' ? 'TBD' : await _getDisplayName(comp1Id),
          'player2': comp2Id == 'TBD' ? 'TBD' : await _getDisplayName(comp2Id),
          'player1Id': comp1Id,
          'player2Id': comp2Id,
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            startHour,
            startMinute,
          )),
        };
        newMatches.add(match);
        if (comp1Id != 'TBD' && comp1Id.isNotEmpty) {
          playerLastPlayDate[comp1Id] = currentDate;
        }
        if (comp2Id != 'TBD' && comp2Id.isNotEmpty) {
          playerLastPlayDate[comp2Id] = currentDate;
        }
        currentDate = currentDate.add(const Duration(days: 1));
      }
      nextRoundCompetitors.add({'id': 'TBD', 'winnerMatchId': matchId});
    }
    if (losersBracket.length % 2 != 0) {
      final lastCompetitor = losersBracket.last;
      final lastCompId = lastCompetitor['id'] as String? ?? 'TBD';
      nextRoundCompetitors.add(lastCompetitor);
      if (lastCompId != 'TBD' && lastCompId.isNotEmpty) {
        playerLastPlayDate[lastCompId] = currentDate;
      }
    }
    losersBracket = nextRoundCompetitors;
    losersRound++;

    // Add losers from the next winners' round
    final nextWinnersRoundMatches = newMatches
        .where((m) => m['bracket'] == 'winners' && m['round'] == winnersRoundToProcess)
        .toList();
    if (nextWinnersRoundMatches.isNotEmpty) {
      final newLosers = nextWinnersRoundMatches
          .map((m) => {'id': 'TBD', 'loserMatchId': m['matchId']})
          .toList();
      losersBracket.addAll(newLosers);
      winnersRoundToProcess++;
    }
  }

  // Grand Final
  final winnersFinal = newMatches
      .where((m) => m['bracket'] == 'winners' && m['round'] == winnersRound - 1)
      .firstOrNull;
  final losersFinal = newMatches
      .where((m) => m['bracket'] == 'losers' && m['round'] == losersRound - 1)
      .firstOrNull;

  if (winnersFinal != null && losersFinal != null) {
    final grandFinalId = 'gf_match_TBD_vs_TBD_r1';
    if (!existingMatches.containsKey(grandFinalId)) {
      newMatches.add({
        'matchId': grandFinalId,
        'round': 1,
        'bracket': 'grand_final',
        'player1': 'TBD',
        'player1Id': 'TBD',
        'player2': 'TBD',
        'player2Id': 'TBD',
        'completed': false,
        'winner': null,
        'umpire': {'name': '', 'email': '', 'phone': ''},
        'liveScores': {
          'player1': [0, 0, 0],
          'player2': [0, 0, 0],
          'currentGame': 1,
          'isLive': false,
          'currentServer': 'player1',
        },
        'startTime': Timestamp.fromDate(DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          startHour,
          startMinute,
        )),
        'winnerMatchId': winnersFinal['matchId'],
        'loserMatchId': losersFinal['matchId'],
      });
      currentDate = currentDate.add(const Duration(days: 1));

      // Optional second grand final
      final grandFinal2Id = 'gf_match_TBD_vs_TBD_r2';
      if (!existingMatches.containsKey(grandFinal2Id)) {
        newMatches.add({
          'matchId': grandFinal2Id,
          'round': 2,
          'bracket': 'grand_final',
          'player1': 'TBD',
          'player1Id': 'TBD',
          'player2': 'TBD',
          'player2Id': 'TBD',
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            startHour,
            startMinute,
          )),
          'winnerMatchId': grandFinalId,
        });
      }
    }
  }

  return newMatches;
}

List<List<Map<String, dynamic>>> _computeGroups({
  required List<Map<String, dynamic>> competitors,
  required List<Map<String, dynamic>> matches,
  required bool isDoubles,
}) {
  final groups = <List<Map<String, dynamic>>>[];
  final groupMap = <int, List<Map<String, dynamic>>>{};

  // Extract group assignments from matches
  for (var match in matches) {
    if (match['phase'] == 'group' && match['group'] is int) {
      final groupIndex = match['group'] as int;
      final competitor1Ids = isDoubles ? match['team1Ids'] as List<dynamic>? ?? [] : [match['player1Id']].whereType<String>().toList();
      final competitor2Ids = isDoubles ? match['team2Ids'] as List<dynamic>? ?? [] : [match['player2Id']].whereType<String>().toList();

      groupMap.putIfAbsent(groupIndex, () => []);

      for (var competitorId in [...competitor1Ids, ...competitor2Ids]) {
        final competitor = competitors.firstWhere(
          (c) => (isDoubles ? c['teamId'] : c['id']) == competitorId,
          orElse: () => <String, dynamic>{},
        );
        if (competitor.isNotEmpty && !groupMap[groupIndex]!.contains(competitor)) {
          groupMap[groupIndex]!.add(competitor);
        }
      }
    }
  }

  // Convert groupMap to list of groups
  final sortedGroupIndices = groupMap.keys.toList()..sort();
  for (var index in sortedGroupIndices) {
    groups.add(groupMap[index]!);
  }

  // Fallback: Create groups if none found
  if (groups.isEmpty && competitors.isNotEmpty) {
    final shuffledCompetitors = List<Map<String, dynamic>>.from(competitors)..shuffle(Random(42));
    final numCompetitors = shuffledCompetitors.length;
    if (numCompetitors <= 8) {
      groups.add(shuffledCompetitors);
    } else {
      final groupCount = (numCompetitors / 4).ceil();
      int participantsPerGroup = (numCompetitors / groupCount).floor();
      int extraParticipants = numCompetitors % groupCount;
      int startIndex = 0;
      for (int i = 0; i < groupCount; i++) {
        int currentGroupSize = participantsPerGroup + (extraParticipants > 0 ? 1 : 0);
        if (startIndex + currentGroupSize > numCompetitors) {
          currentGroupSize = numCompetitors - startIndex;
        }
        groups.add(shuffledCompetitors.sublist(startIndex, startIndex + currentGroupSize));
        startIndex += currentGroupSize;
        if (extraParticipants > 0) extraParticipants--;
      }
    }
  }

  return groups;
}

Future<List<Map<String, dynamic>>> _generateGroupKnockoutMatches({
  required List<Map<String, dynamic>> competitors,
  required Map<String, Map<String, dynamic>> existingMatches,
  required DateTime startDate,
  required int startHour,
  required int startMinute,
  bool isDoubles = false,
}) async {
  final newMatches = <Map<String, dynamic>>[];
  final shuffledCompetitors = List<Map<String, dynamic>>.from(competitors)..shuffle();
  final numCompetitors = shuffledCompetitors.length;

  // Determine number of groups based on participants
  final groupCount = (numCompetitors <= 4) ? 1 : (numCompetitors / 4).ceil();
  final groups = <List<Map<String, dynamic>>>[];
  int participantsPerGroup = (numCompetitors / groupCount).floor();
  int extraParticipants = numCompetitors % groupCount;
  int startIndex = 0;

  for (int i = 0; i < groupCount; i++) {
    int currentGroupSize = participantsPerGroup + (extraParticipants > 0 ? 1 : 0);
    if (startIndex + currentGroupSize > numCompetitors) {
      currentGroupSize = numCompetitors - startIndex;
    }
    groups.add(shuffledCompetitors.sublist(startIndex, startIndex + currentGroupSize));
    startIndex += currentGroupSize;
    if (extraParticipants > 0) extraParticipants--;
  }

  DateTime currentDate = startDate;
  int round = 1;
  final playerLastPlayDate = <String, DateTime>{};

  // Generate round-robin matches within each group
  for (var group in groups) {
    final groupIndex = groups.indexOf(group) + 1;
    final groupName = String.fromCharCode(64 + groupIndex); // A, B, C, ...
    final n = group.length;
    final competitorsWithBye = List<Map<String, dynamic>>.from(group);
    if (n.isOdd) {
      competitorsWithBye.add({
        'id': 'bye_$groupIndex',
        'teamId': 'bye_$groupIndex',
        'players': [{'id': 'bye_$groupIndex', 'firstName': 'Bye', 'lastName': ''}],
      });
    }
    final totalRounds = competitorsWithBye.length - 1;
    final matchesPerRound = competitorsWithBye.length ~/ 2;
    final rounds = List.generate(totalRounds, (_) => <Map<String, dynamic>>[]);

    for (var r = 0; r < totalRounds; r++) {
      for (var i = 0; i < matchesPerRound; i++) {
        final competitor1 = competitorsWithBye[i];
        final competitor2 = competitorsWithBye[competitorsWithBye.length - 1 - i];
        if (competitor1['id']?.toString().startsWith('bye_') == true ||
            competitor2['id']?.toString().startsWith('bye_') == true ||
            (isDoubles &&
                (competitor1['teamId']?.toString().startsWith('bye_') == true ||
                    competitor2['teamId']?.toString().startsWith('bye_') == true))) {
          continue;
        }

        String matchId;
        Map<String, dynamic> match;
        if (isDoubles) {
          final team1Ids = competitor1['players'].map((p) => p['id']).toList();
          final team2Ids = competitor2['players'].map((p) => p['id']).toList();
          matchId = 'group_match_${team1Ids.join('_')}_vs_${team2Ids.join('_')}_g$groupName';
          if (!existingMatches.containsKey(matchId)) {
            match = {
              'matchId': matchId,
              'round': round,
              'group': groupName,
              'team1': competitor1['players'].map((p) => '${p['firstName']} ${p['lastName']}'.trim()).toList(),
              'team2': competitor2['players'].map((p) => '${p['firstName']} ${p['lastName']}'.trim()).toList(),
              'team1Ids': team1Ids,
              'team2Ids': team2Ids,
              'completed': false,
              'winner': null,
              'umpire': {'name': '', 'email': '', 'phone': ''},
              'liveScores': {
                'team1': [0, 0, 0],
                'team2': [0, 0, 0],
                'currentGame': 1,
                'isLive': false,
                'currentServer': 'team1',
              },
              'phase': 'group',
            };
            rounds[r].add(match);
          }
        } else {
          matchId = 'group_match_${competitor1['id']}_vs_${competitor2['id']}_g$groupName';
          if (!existingMatches.containsKey(matchId)) {
            match = {
              'matchId': matchId,
              'round': round,
              'group': groupName,
              'player1': await _getDisplayName(competitor1['id']),
              'player2': await _getDisplayName(competitor2['id']),
              'player1Id': competitor1['id'],
              'player2Id': competitor2['id'],
              'completed': false,
              'winner': null,
              'umpire': {'name': '', 'email': '', 'phone': ''},
              'liveScores': {
                'player1': [0, 0, 0],
                'player2': [0, 0, 0],
                'currentGame': 1,
                'isLive': false,
                'currentServer': 'player1',
              },
              'phase': 'group',
            };
            rounds[r].add(match);
          }
        }
      }
      final temp = competitorsWithBye.sublist(1);
      competitorsWithBye.setRange(1, competitorsWithBye.length, [...temp.sublist(1), temp[0]]);
      round++;
    }

    for (var r in rounds) {
      for (var match in r) {
        final competitor1Ids = isDoubles ? List<String>.from(match['team1Ids']) : [match['player1Id']];
        final competitor2Ids = isDoubles ? List<String>.from(match['team2Ids']) : [match['player2Id']];
        final allPlayerIds = [...competitor1Ids, ...competitor2Ids];
        DateTime candidateDate = currentDate;
        bool conflict;
        do {
          conflict = false;
          for (var playerId in allPlayerIds) {
            final lastPlayDate = playerLastPlayDate[playerId];
            if (lastPlayDate != null && candidateDate.difference(lastPlayDate).inDays.abs() < 1) {
              conflict = true;
              candidateDate = candidateDate.add(const Duration(days: 1));
              break;
            }
          }
        } while (conflict);
        match['startTime'] = Timestamp.fromDate(DateTime(
          candidateDate.year,
          candidateDate.month,
          candidateDate.day,
          startHour,
          startMinute,
        ));
        for (var playerId in allPlayerIds) {
          playerLastPlayDate[playerId] = candidateDate;
        }
        newMatches.add(match);
        currentDate = candidateDate.add(const Duration(days: 1));
      }
    }
  }

  // Check if all group stage matches are completed
  final groupMatches = existingMatches.values.where((m) => m['phase'] == 'group').toList();
  final allGroupMatchesCompleted = groupMatches.isNotEmpty &&
      groupMatches.every((m) => m['completed'] == true && m['winner'] != null);
  print('DEBUG: Group stage matches: ${groupMatches.length}, all completed: $allGroupMatchesCompleted');

  // Generate knockout matches
  int currentRoundMatches = (numCompetitors <= 4) ? 1 : (groupCount * 2 / 2).floor();
  int knockoutRound = 1;
  int matchCounter = 1;
  int totalRound = round;

  // Always generate knockout match with TBD if group stage is incomplete
  for (int i = 0; i < currentRoundMatches; i++) {
    final matchId = 'knockout_match_${matchCounter}_r$knockoutRound';
    if (!existingMatches.containsKey(matchId)) {
      final match = {
        'matchId': matchId,
        'round': totalRound,
        'phase': 'knockout',
        'player1': 'TBD',
        'player2': 'TBD',
        'player1Id': null,
        'player2Id': null,
        'completed': false,
        'winner': null,
        'umpire': {'name': '', 'email': '', 'phone': ''},
        'liveScores': {
          'player1': [0, 0, 0],
          'player2': [0, 0, 0],
          'currentGame': 1,
          'isLive': false,
          'currentServer': 'player1',
        },
        'startTime': Timestamp.fromDate(DateTime(
          currentDate.year,
          currentDate.month,
          currentDate.day,
          startHour,
          startMinute,
        )),
        'qualifierInfo': {
          'player1': 'Group A #1',
          'player2': 'Group A #2',
        },
      };
      newMatches.add(match);
      matchCounter++;
      currentDate = currentDate.add(const Duration(days: 1));
    }
    totalRound++;
  }

  if (!allGroupMatchesCompleted) {
    print('DEBUG: Group stage incomplete, generated knockout matches with TBD');
    return newMatches;
  }

  // Calculate group stage rankings
  final groupRankings = <String, List<Map<String, dynamic>>>{};
  for (var group in groups) {
    final groupIndex = groups.indexOf(group) + 1;
    final groupName = String.fromCharCode(64 + groupIndex);
    final groupParticipants = group.map((p) => {...p, 'score': 0}).toList();

    // Fetch completed group stage matches
    final groupMatches = existingMatches.values
        .where((m) => m['group'] == groupName && m['phase'] == 'group' && m['completed'] == true)
        .toList();

    // Update scores based on match results
    for (var participant in groupParticipants) {
      int score = 0;
      for (var match in groupMatches) {
        if (match['winner'] == 'player1' && match['player1Id'] == participant['id']) {
          score += 2; // Win gives 2 points
        } else if (match['winner'] == 'player2' && match['player2Id'] == participant['id']) {
          score += 2;
        }
      }
      participant['score'] = score;
    }

    // Sort by score (descending)
    groupParticipants.sort((a, b) {
      int scoreCompare = b['score'].compareTo(a['score']);
      if (scoreCompare != 0) return scoreCompare;
      return 0; // Add tiebreaker logic if needed
    });

    groupRankings[groupName] = groupParticipants.take(2).toList(); // Top 2 per group
  }

  // Generate knockout phase matches with actual players
  final qualifiers = groupRankings.values.expand((list) => list).toList();
  if (qualifiers.length < 2) {
    print('DEBUG: Not enough qualifiers (${qualifiers.length}) for knockout phase');
    return newMatches;
  }

  // Reset matchCounter and totalRound for knockout phase
  matchCounter = 1;
  totalRound = round;
  qualifiers.shuffle(); // Random seeding
  for (int i = 0; i < currentRoundMatches; i++) {
    final player1 = qualifiers[i * 2];
    final player2 = i * 2 + 1 < qualifiers.length ? qualifiers[i * 2 + 1] : null;
    String matchId;
    Map<String, dynamic> match;

    if (player2 == null) {
      // Bye match
      matchId = 'knockout_match_${matchCounter}_r$knockoutRound';
      if (!existingMatches.containsKey(matchId)) {
        match = {
          'matchId': matchId,
          'round': totalRound,
          'phase': 'knockout',
          'player1': await _getDisplayName(player1['id']),
          'player1Id': player1['id'],
          'player2': 'Bye',
          'player2Id': 'bye',
          'completed': true,
          'winner': 'player1',
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            startHour,
            startMinute,
          )),
          'qualifierInfo': {
            'player1': 'Group ${groupRankings.keys.firstWhere((k) => groupRankings[k]!.contains(player1))} #${groupRankings.values.firstWhere((v) => v.contains(player1)).indexOf(player1) + 1}',
            'player2': 'Bye',
          },
        };
        newMatches.add(match);
        matchCounter++;
        currentDate = currentDate.add(const Duration(days: 1));
      }
    } else {
      matchId = 'knockout_match_${matchCounter}_r$knockoutRound';
      if (!existingMatches.containsKey(matchId)) {
        match = {
          'matchId': matchId,
          'round': totalRound,
          'phase': 'knockout',
          'player1': await _getDisplayName(player1['id']),
          'player2': await _getDisplayName(player2['id']),
          'player1Id': player1['id'],
          'player2Id': player2['id'],
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            startHour,
            startMinute,
          )),
          'qualifierInfo': {
            'player1': 'Group ${groupRankings.keys.firstWhere((k) => groupRankings[k]!.contains(player1))} #${groupRankings.values.firstWhere((v) => v.contains(player1)).indexOf(player1) + 1}',
            'player2': 'Group ${groupRankings.keys.firstWhere((k) => groupRankings[k]!.contains(player2))} #${groupRankings.values.firstWhere((v) => v.contains(player2)).indexOf(player2) + 1}',
          },
        };
        newMatches.add(match);
        matchCounter++;
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
    totalRound++;
  }

  return newMatches;
}

Future<List<Map<String, dynamic>>> _generateTeamFormatMatches({
  required List<Map<String, dynamic>> competitors,
  required Map<String, Map<String, dynamic>> existingMatches,
  required DateTime startDate,
  required int startHour,
  required int startMinute,
  bool isDoubles = true,
}) async {
  final newMatches = <Map<String, dynamic>>[];
  final shuffledCompetitors = List<Map<String, dynamic>>.from(competitors)..shuffle();
  DateTime currentDate = startDate;
  int round = 1;

  // Generate team ties (e.g., 2 singles + 1 doubles per tie)
  for (int i = 0; i < shuffledCompetitors.length - 1; i += 2) {
    final team1 = shuffledCompetitors[i];
    final team2 = shuffledCompetitors[i + 1];

    // Create multiple matches per tie (e.g., 2 singles, 1 doubles)
    final tieMatches = <Map<String, dynamic>>[];
    final matchCount = isDoubles ? 1 : 3; // For simplicity, singles has 2 singles + 1 doubles; doubles has 1 match

    for (int m = 1; m <= matchCount; m++) {
      String matchId;
      Map<String, dynamic> match;

      if (isDoubles) {
        final team1Ids = team1['players'].map((p) => p['id']).toList();
        final team2Ids = team2['players'].map((p) => p['id']).toList();
        matchId = 'team_match_${team1Ids.join('_')}_vs_${team2Ids.join('_')}_r$round';
        if (!existingMatches.containsKey(matchId)) {
          match = {
            'matchId': matchId,
            'round': round,
            'tie': m,
            'team1': team1['players']
                .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                .toList(),
            'team2': team2['players']
                .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                .toList(),
            'team1Ids': team1Ids,
            'team2Ids': team2Ids,
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'team1': [0, 0, 0],
              'team2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'team1',
            },
            'startTime': Timestamp.fromDate(DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              startHour,
              startMinute,
            )),
          };
          tieMatches.add(match);
        }
      } else {
        // For singles, assume team format includes 2 singles + 1 doubles match
        if (m <= 2) {
          // Singles matches
          final player1Id = team1['id'];
          final player2Id = team2['id'];
          matchId = 'team_match_${player1Id}_vs_${player2Id}_r${round}_m$m';
          if (!existingMatches.containsKey(matchId)) {
            match = {
              'matchId': matchId,
              'round': round,
              'tie': m,
              'player1': await _getDisplayName(player1Id),
              'player2': await _getDisplayName(player2Id),
              'player1Id': player1Id,
              'player2Id': player2Id,
              'completed': false,
              'winner': null,
              'umpire': {'name': '', 'email': '', 'phone': ''},
              'liveScores': {
                'player1': [0, 0, 0],
                'player2': [0, 0, 0],
                'currentGame': 1,
                'isLive': false,
                'currentServer': 'player1',
              },
              'startTime': Timestamp.fromDate(DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
                startHour,
                startMinute,
              )),
            };
            tieMatches.add(match);
          }
        } else {
          // Doubles match (simplified: same players)
          matchId = 'team_doubles_${team1['id']}_vs_${team2['id']}_r${round}_m$m';
          if (!existingMatches.containsKey(matchId)) {
            match = {
              'matchId': matchId,
              'round': round,
              'tie': m,
              'team1': [await _getDisplayName(team1['id'])],
              'team2': [await _getDisplayName(team2['id'])],
              'team1Ids': [team1['id']],
              'team2Ids': [team2['id']],
              'completed': false,
              'winner': null,
              'umpire': {'name': '', 'email': '', 'phone': ''},
              'liveScores': {
                'team1': [0, 0, 0],
                'team2': [0, 0, 0],
                'currentGame': 1,
                'isLive': false,
                'currentServer': 'team1',
              },
              'startTime': Timestamp.fromDate(DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
                startHour,
                startMinute,
              )),
            };
            tieMatches.add(match);
          }
        }
      }
    }

    final playerLastPlayDate = <String, DateTime>{};
    for (var match in tieMatches) {
      final competitor1Ids = isDoubles ? List<String>.from(match['team1Ids']) : [match['player1Id']];
      final competitor2Ids = isDoubles ? List<String>.from(match['team2Ids']) : [match['player2Id']];
      final allPlayerIds = [...competitor1Ids, ...competitor2Ids];
      DateTime candidateDate = currentDate;
      bool conflict;
      do {
        conflict = false;
        for (var playerId in allPlayerIds) {
          final lastPlayDate = playerLastPlayDate[playerId];
          if (lastPlayDate != null && candidateDate.difference(lastPlayDate).inDays.abs() < 1) {
            conflict = true;
            candidateDate = candidateDate.add(const Duration(days: 1));
            break;
          }
        }
      } while (conflict);
      match['startTime'] = Timestamp.fromDate(DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
        startHour,
        startMinute,
      ));
      for (var playerId in allPlayerIds) {
        playerLastPlayDate[playerId] = candidateDate;
      }
      newMatches.add(match);
      currentDate = candidateDate.add(const Duration(hours: 2)); // Matches within a tie are closer
    }
    currentDate = currentDate.add(const Duration(days: 1));
    round++;
  }

  return newMatches;
}

Future<List<Map<String, dynamic>>> _generateLadderMatches({
  required List<Map<String, dynamic>> competitors,
  required Map<String, Map<String, dynamic>> existingMatches,
  required DateTime startDate,
  required int startHour,
  required int startMinute,
  bool isDoubles = false,
}) async {
  final newMatches = <Map<String, dynamic>>[];
  final rankedCompetitors = List<Map<String, dynamic>>.from(competitors)
    ..sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0)); // Rank by score or initial order
  final n = rankedCompetitors.length;
  if (n < 2) {
    throw Exception('Need at least 2 competitors for ladder tournament.');
  }

  final playerLastPlayDate = <String, DateTime>{};
  DateTime currentDate = startDate;
  int round = 1;

  // Generate one round of challenge matches
  final pairedCompetitors = <String>{};
  for (int i = n - 1; i >= 1; i--) {
    final competitor = rankedCompetitors[i]; // Lower-ranked challenger
    final opponentIndex = i - 1; // Challenge the player/team above
    if (opponentIndex < 0) continue;
    final opponent = rankedCompetitors[opponentIndex];

    if (pairedCompetitors.contains(competitor['id']) || pairedCompetitors.contains(opponent['id'])) {
      continue;
    }

    if (competitor['id'] == null || opponent['id'] == null) {
      print('Warning: Skipping match due to missing competitor ID at index $i');
      continue;
    }

    String matchId;
    Map<String, dynamic> match;

    if (isDoubles) {
      final team1Ids = (competitor['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
      final team2Ids = (opponent['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
      if (team1Ids.contains(null) || team2Ids.contains(null)) {
        print('Warning: Skipping match due to invalid team data at index $i');
        continue;
      }
      matchId = 'ladder_match_${team1Ids.join('_')}_vs_${team2Ids.join('_')}_r$round';
      if (!existingMatches.containsKey(matchId)) {
        bool conflict;
        do {
          conflict = false;
          for (var playerId in [...team1Ids, ...team2Ids]) {
            if (playerId == null) continue;
            final lastPlayDate = playerLastPlayDate[playerId];
            if (lastPlayDate != null && currentDate.difference(lastPlayDate).inDays.abs() < 1) {
              conflict = true;
              currentDate = currentDate.add(const Duration(days: 1));
              break;
            }
          }
        } while (conflict);

        match = {
          'matchId': matchId,
          'round': round,
          'team1': (competitor['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? [],
          'team2': (opponent['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? [],
          'team1Ids': team1Ids,
          'team2Ids': team2Ids,
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'team1': [0, 0, 0],
            'team2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'team1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            startHour,
            startMinute,
          )),
        };
        newMatches.add(match);
        for (var playerId in [...team1Ids, ...team2Ids]) {
          if (playerId != null) playerLastPlayDate[playerId] = currentDate;
        }
        pairedCompetitors.add(competitor['id']);
        pairedCompetitors.add(opponent['id']);
        currentDate = currentDate.add(const Duration(days: 1));
      }
    } else {
      final compId = competitor['id'] as String? ?? '';
      final oppId = opponent['id'] as String? ?? '';
      if (compId.isEmpty || oppId.isEmpty) {
        print('Warning: Skipping match due to missing competitor ID at index $i');
        continue;
      }
      matchId = 'ladder_match_${compId}_vs_${oppId}_r$round';
      if (!existingMatches.containsKey(matchId)) {
        bool conflict;
        do {
          conflict = false;
          for (var playerId in [compId, oppId]) {
            final lastPlayDate = playerLastPlayDate[playerId];
            if (lastPlayDate != null && currentDate.difference(lastPlayDate).inDays.abs() < 1) {
              conflict = true;
              currentDate = currentDate.add(const Duration(days: 1));
              break;
            }
          }
        } while (conflict);

        match = {
          'matchId': matchId,
          'round': round,
          'player1': await _getDisplayName(compId),
          'player2': await _getDisplayName(oppId),
          'player1Id': compId,
          'player2Id': oppId,
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(DateTime(
            currentDate.year,
            currentDate.month,
            currentDate.day,
            startHour,
            startMinute,
          )),
        };
        newMatches.add(match);
        playerLastPlayDate[compId] = currentDate;
        playerLastPlayDate[oppId] = currentDate;
        pairedCompetitors.add(compId);
        pairedCompetitors.add(oppId);
        currentDate = currentDate.add(const Duration(days: 1));
      }
    }
  }

  
  return newMatches;
}



Future<List<Map<String, dynamic>>> _generateSwissMatches({
  required List<Map<String, dynamic>> competitors,
  required Map<String, Map<String, dynamic>> existingMatches,
  required DateTime startDate,
  required int startHour,
  required int startMinute,
  bool isDoubles = false,
}) async {
  final newMatches = <Map<String, dynamic>>[];
  final shuffledCompetitors = List<Map<String, dynamic>>.from(competitors)..shuffle();
  final n = shuffledCompetitors.length;
  if (n < 2) {
    throw Exception('Need at least 2 competitors for Swiss tournament.');
  }

  final playerLastPlayDate = <String, DateTime>{};
  DateTime currentDate = startDate;
  final numRounds = (math.log(n.toDouble()) / math.log(2)).ceil(); // Approx log2(n) rounds
  int round = 1;

  // Track played matchups to avoid repeats
  final playedMatchups = <String, Set<String>>{};
  for (var competitor in shuffledCompetitors) {
    final id = isDoubles
        ? (competitor['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList().join('_') ?? ''
        : competitor['id'] as String? ?? '';
    if (id.isNotEmpty) {
      playedMatchups[id] = {};
    }
  }

  // Generate matches for each round
  for (round = 1; round <= numRounds; round++) {
    List<Map<String, dynamic>> availableCompetitors = List.from(
      round == 1 ? shuffledCompetitors : shuffledCompetitors..sort((a, b) => (b['score'] ?? 0).compareTo(a['score'] ?? 0)),
    );
    final pairedCompetitors = <String>{};
    final roundMatches = <Map<String, dynamic>>[];

    for (int i = 0; i < availableCompetitors.length; i++) {
      if (pairedCompetitors.contains(availableCompetitors[i]['id'])) continue;
      final competitor1 = availableCompetitors[i];
      Map<String, dynamic>? competitor2;
      int j = i + 1;

      // Find a compatible opponent with similar score and no prior matchup
      while (j < availableCompetitors.length) {
        final candidate = availableCompetitors[j];
        final comp1Id = isDoubles
            ? (competitor1['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList().join('_') ?? ''
            : competitor1['id'] as String? ?? '';
        final comp2Id = isDoubles
            ? (candidate['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList().join('_') ?? ''
            : candidate['id'] as String? ?? '';
        if (!pairedCompetitors.contains(comp2Id) && !playedMatchups[comp1Id]!.contains(comp2Id)) {
          competitor2 = candidate;
          break;
        }
        j++;
      }

      if (competitor2 == null && availableCompetitors.length % 2 == 1 && !pairedCompetitors.contains(competitor1['id'])) {
        // Assign bye to unpaired competitor
        final byeId = 'bye_${competitor1['id']}_r$round';
        if (!existingMatches.containsKey(byeId)) {
          final match = {
            'matchId': byeId,
            'round': round,
            'player1': isDoubles
                ? (competitor1['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? []
                : await _getDisplayName(competitor1['id'] ?? ''),
            'player2': 'Bye',
            'player1Id': competitor1['id'],
            'player2Id': 'bye',
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'player1': [0, 0, 0],
              'player2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'player1',
            },
            'startTime': Timestamp.fromDate(DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              startHour,
              startMinute,
            )),
          };
          if (isDoubles) {
            match['team1'] = (competitor1['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? [];
            match['team1Ids'] = (competitor1['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
            match['team2'] = ['Bye'];
            match['team2Ids'] = ['bye'];
          }
          roundMatches.add(match);
          pairedCompetitors.add(competitor1['id'] as String);
          if (isDoubles) {
            for (var playerId in (competitor1['players'] as List<dynamic>?)?.map((p) => p['id'] as String?) ?? []) {
              if (playerId is String && playerId.isNotEmpty) playerLastPlayDate[playerId] = currentDate;
            }
          } else {
            final playerId = competitor1['id'] as String?;
            if (playerId != null) playerLastPlayDate[playerId] = currentDate;
          }
          currentDate = currentDate.add(const Duration(days: 1));
        }
        continue;
      }

      if (competitor2 == null) continue;

      String matchId;
      Map<String, dynamic> match;

      if (isDoubles) {
        final team1Ids = (competitor1['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
        final team2Ids = (competitor2['players'] as List<dynamic>?)?.map((p) => p['id'] as String?).toList() ?? [];
        if (team1Ids.contains(null) || team2Ids.contains(null)) {
          print('Warning: Skipping match due to invalid team data at index $i');
          continue;
        }
        matchId = 'swiss_match_${team1Ids.join('_')}_vs_${team2Ids.join('_')}_r$round';
        if (!existingMatches.containsKey(matchId)) {
          bool conflict;
          do {
            conflict = false;
            for (var playerId in [...team1Ids, ...team2Ids]) {
              if (playerId == null) continue;
              final lastPlayDate = playerLastPlayDate[playerId];
              if (lastPlayDate != null && currentDate.difference(lastPlayDate).inDays.abs() < 1) {
                conflict = true;
                currentDate = currentDate.add(const Duration(days: 1));
                break;
              }
            }
          } while (conflict);

          match = {
            'matchId': matchId,
            'round': round,
            'team1': (competitor1['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? [],
            'team2': (competitor2['players'] as List<dynamic>?)?.map((p) => '${p['firstName'] ?? ''} ${p['lastName'] ?? ''}'.trim()).toList() ?? [],
            'team1Ids': team1Ids,
            'team2Ids': team2Ids,
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'team1': [0, 0, 0],
              'team2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'team1',
            },
            'startTime': Timestamp.fromDate(DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              startHour,
              startMinute,
            )),
          };
          newMatches.add(match);
          for (var playerId in [...team1Ids, ...team2Ids]) {
            if (playerId != null) playerLastPlayDate[playerId] = currentDate;
          }
          pairedCompetitors.add(competitor1['id'] as String);
          pairedCompetitors.add(competitor2['id'] as String);
          playedMatchups[team1Ids.join('_')]!.add(team2Ids.join('_'));
          playedMatchups[team2Ids.join('_')]!.add(team1Ids.join('_'));
          currentDate = currentDate.add(const Duration(days: 1));
        }
      } else {
        final comp1Id = competitor1['id'] as String? ?? '';
        final comp2Id = competitor2['id'] as String? ?? '';
        if (comp1Id.isEmpty || comp2Id.isEmpty) {
          print('Warning: Skipping match due to missing competitor ID at index $i');
          continue;
        }
        matchId = 'swiss_match_${comp1Id}_vs_${comp2Id}_r$round';
        if (!existingMatches.containsKey(matchId)) {
          bool conflict;
          do {
            conflict = false;
            for (var playerId in [comp1Id, comp2Id]) {
              final lastPlayDate = playerLastPlayDate[playerId];
              if (lastPlayDate != null && currentDate.difference(lastPlayDate).inDays.abs() < 1) {
                conflict = true;
                currentDate = currentDate.add(const Duration(days: 1));
                break;
              }
            }
          } while (conflict);

          match = {
            'matchId': matchId,
            'round': round,
            'player1': await _getDisplayName(comp1Id),
            'player2': await _getDisplayName(comp2Id),
            'player1Id': comp1Id,
            'player2Id': comp2Id,
            'completed': false,
            'winner': null,
            'umpire': {'name': '', 'email': '', 'phone': ''},
            'liveScores': {
              'player1': [0, 0, 0],
              'player2': [0, 0, 0],
              'currentGame': 1,
              'isLive': false,
              'currentServer': 'player1',
            },
            'startTime': Timestamp.fromDate(DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              startHour,
              startMinute,
            )),
          };
          newMatches.add(match);
          playerLastPlayDate[comp1Id] = currentDate;
          playerLastPlayDate[comp2Id] = currentDate;
          pairedCompetitors.add(comp1Id);
          pairedCompetitors.add(comp2Id);
          playedMatchups[comp1Id]!.add(comp2Id);
          playedMatchups[comp2Id]!.add(comp1Id);
          currentDate = currentDate.add(const Duration(days: 1));
        }
      }
    }
  }

  return newMatches;
}

  Future<void> _createManualMatch(
    dynamic competitor1,
    dynamic competitor2,
    DateTime matchDateTime,
  ) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final existingMatches = {
        for (var match in _matches) match['matchId'] as String: match
      };

      final isDoubles = _isDoublesTournament();
      String matchId;
      Map<String, dynamic> newMatch;

      if (isDoubles) {
        final team1Ids = competitor1['players'].map((p) => p['id']).toList();
        final team2Ids = competitor2['players'].map((p) => p['id']).toList();
        matchId = 'match_${team1Ids.join('_')}_vs_${team2Ids.join('_')}';

        if (existingMatches.containsKey(matchId)) {
          throw 'Match between these teams already exists.';
        }

        final team1Names = competitor1['players']
            .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
            .toList();
        final team2Names = competitor2['players']
            .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
            .toList();

        newMatch = {
          'matchId': matchId,
          'round': _matches.isNotEmpty ? (_matches.last['round'] ?? 1) : 1,
          'team1': team1Names,
          'team2': team2Names,
          'team1Ids': team1Ids,
          'team2Ids': team2Ids,
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'team1': [0, 0, 0],
            'team2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'team1',
          },
          'startTime': Timestamp.fromDate(matchDateTime),
        };
      } else {
        matchId = 'match_${competitor1['id']}_vs_${competitor2['id']}';

        if (existingMatches.containsKey(matchId)) {
          throw 'Match between these players already exists.';
        }

        newMatch = {
          'matchId': matchId,
          'round': _matches.isNotEmpty ? (_matches.last['round'] ?? 1) : 1,
          'player1': await _getDisplayName(competitor1['id']),
          'player2': await _getDisplayName(competitor2['id']),
          'player1Id': competitor1['id'],
          'player2Id': competitor2['id'],
          'completed': false,
          'winner': null,
          'umpire': {'name': '', 'email': '', 'phone': ''},
          'liveScores': {
            'player1': [0, 0, 0],
            'player2': [0, 0, 0],
            'currentGame': 1,
            'isLive': false,
            'currentServer': 'player1',
          },
          'startTime': Timestamp.fromDate(matchDateTime),
        };
      }

      final updatedMatches = List<Map<String, dynamic>>.from(_matches)..add(newMatch);

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .update({'matches': updatedMatches});

      if (mounted) {
        setState(() {
          _matches = updatedMatches;
          _showMatchGenerationOptions = false;
        });
        await _generateLeaderboardData();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Match Created'),
          description: const Text('Manual match has been successfully created!'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _successColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to create match: $e'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showManualMatchDialog(bool isCreator) {
    if (!isCreator) return;

    final competitors = _isDoublesTournament() ? _teams : _participants;
    if (competitors.length < 2) {
       if (!_canCreateMatches) {
         toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Insufficient Competitors'),
        description: const Text('At least two teams or players are required to create a match.'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
       }
      return;
    }

    dynamic selectedCompetitor1;
    dynamic selectedCompetitor2;
    DateTime selectedDate = widget.tournament.startDate;
    TimeOfDay selectedTime = TimeOfDay(
  hour: widget.tournament.startDate.hour,
  minute: widget.tournament.startDate.minute,
);
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: _cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Create Manual Match',
            style: GoogleFonts.poppins(
              color: _textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
                minWidth: 200.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 10),
                  Flexible(
                    child: DropdownButtonFormField<dynamic>(
                      decoration: InputDecoration(
                        labelText: _isDoublesTournament() ? 'Select Team 1' : 'Select Player 1',
                        labelStyle: GoogleFonts.poppins(color: _textColor.withOpacity(0.7)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentColor.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                        filled: true,
                        fillColor: _cardBackground.withOpacity(0.9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      dropdownColor: _cardBackground,
                      isExpanded: true,
                      items: competitors.map((competitor) {
                        return DropdownMenuItem(
                          value: competitor,
                          child: FutureBuilder<String>(
                            future: _isDoublesTournament()
                                ? Future.value(
                                    competitor['players']
                                        .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                                        .join(' & '),
                                  )
                                : _getDisplayName(competitor['id']),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.connectionState == ConnectionState.waiting
                                    ? 'Loading...'
                                    : snapshot.data ?? competitor['id'],
                                style: GoogleFonts.poppins(
                                  color: _textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedCompetitor1 = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: DropdownButtonFormField<dynamic>(
                      decoration: InputDecoration(
                        labelText: _isDoublesTournament() ? 'Select Team 2' : 'Select Player 2',
                        labelStyle: GoogleFonts.poppins(color: _textColor.withOpacity(0.7)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentColor.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: _accentColor, width: 2),
                        ),
                        filled: true,
                        fillColor: _cardBackground.withOpacity(0.9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      dropdownColor: _cardBackground,
                      isExpanded: true,
                      items: competitors.map((competitor) {
                        return DropdownMenuItem(
                          value: competitor,
                          child: FutureBuilder<String>(
                            future: _isDoublesTournament()
                                ? Future.value(
                                    competitor['players']
                                        .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                                        .join(' & '),
                                  )
                                : _getDisplayName(competitor['id']),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.connectionState == ConnectionState.waiting
                                    ? 'Loading...'
                                    : snapshot.data ?? competitor['id'],
                                style: GoogleFonts.poppins(
                                  color: _textColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedCompetitor2 = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      'Match Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                      style: GoogleFonts.poppins(color: _textColor),
                    ),
                    trailing: Icon(Icons.calendar_today, color: _accentColor),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: widget.tournament.startDate,
                        lastDate: widget.tournament.endDate ?? DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      'Match Time: ${selectedTime.format(context)}',
                      style: GoogleFonts.poppins(color: _textColor),
                    ),
                    trailing: Icon(Icons.access_time, color: _accentColor),
                    onTap: () async {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (pickedTime != null) {
                        setStateDialog(() {
                          selectedTime = pickedTime;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: _secondaryText),
              ),
            ),
            TextButton(
              onPressed: () {
                if (selectedCompetitor1 == null || selectedCompetitor2 == null) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    title: const Text('Selection Required'),
                    description: const Text('Please select both competitors.'),
                    autoCloseDuration: const Duration(seconds: 2),
                    backgroundColor: _errorColor,
                    foregroundColor: _textColor,
                    alignment: Alignment.bottomCenter,
                  );
                  return;
                }
                if (selectedCompetitor1 == selectedCompetitor2) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    title: const Text('Invalid Selection'),
                    description: const Text('Cannot create a match with the same competitor.'),
                    autoCloseDuration: const Duration(seconds: 2),
                    backgroundColor: _errorColor,
                    foregroundColor: _textColor,
                    alignment: Alignment.bottomCenter,
                  );
                  return;
                }
                Navigator.pop(context);
                final matchDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                _createManualMatch(selectedCompetitor1, selectedCompetitor2, matchDateTime);
              },
              child: Text(
                'Create',
                style: GoogleFonts.poppins(
                  color: _successColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMatch(int matchIndex) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedMatches = List<Map<String, dynamic>>.from(_matches)..removeAt(matchIndex);
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .update({'matches': updatedMatches});

      if (mounted) {
        setState(() {
          _matches = updatedMatches;
        });
        await _generateLeaderboardData();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Match Deleted'),
          description: const Text('The match has been successfully deleted.'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _successColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Delete Failed'),
          description: Text('Failed to delete match: $e'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, int matchIndex) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Confirm Delete',
          style: GoogleFonts.poppins(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this match?',
          style: GoogleFonts.poppins(
            color: _secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: _secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMatch(matchIndex);
            },
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: _errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _getUserGender(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return userDoc.data()?['gender'] as String?;
    } catch (e) {
      return null;
    }
  }

  Future<void> _joinTournament(BuildContext context) async {
    if (_isLoading) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Authentication Required'),
        description: const Text('Please sign in to join the tournament.'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    final userId = authState.user.uid;
    if (widget.tournament.createdBy == userId) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Creator Cannot Join'),
        description: const Text('As the tournament creator, you cannot join as a participant.'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    if (_hasJoined) {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        title: const Text('Already Joined'),
        description: const Text('You have already joined this tournament!'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _warningColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    final requiredGender = _getRequiredGender();
    final userGender = await _getUserGender(userId);
    if (userGender == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Gender Not Set'),
        description: const Text('Please set your gender in your profile to join a tournament.'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    if (requiredGender != null && userGender.toLowerCase() != requiredGender) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Gender Mismatch'),
        description: Text(
          'This tournament (${widget.tournament.gameFormat}) is restricted to ${StringExtension(requiredGender).capitalize()} participants only.',
        ),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
      return;
    }

    if (_isDoublesTournament() && requiredGender == null) {
      final genderCounts = <String, int>{};
      for (var participant in _participants) {
        final gender = (participant['gender'] as String? ?? 'unknown').toLowerCase();
        genderCounts[gender] = (genderCounts[gender] ?? 0) + 1;
      }
      final maleCount = genderCounts['male'] ?? 0;
      final femaleCount = genderCounts['female'] ?? 0;
      final userGenderLower = userGender.toLowerCase();

      if (userGenderLower == 'other') {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Invalid Gender for Doubles'),
          description: const Text(
            'Doubles tournaments require Male or Female participants for pairing.',
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
        return;
      }

      if (userGenderLower == 'male' && maleCount >= femaleCount + 1) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Gender Balance Required'),
          description: const Text(
            'Doubles tournament requires equal Male and Female participants. Please wait for a Female participant to join.',
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
        return;
      }

      if (userGenderLower == 'female' && femaleCount >= maleCount + 1) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Gender Balance Required'),
          description: const Text(
            'Doubles tournament requires equal Male and Female participants. Please wait for a Male participant to join.',
          ),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_participants.length >= widget.tournament.maxParticipants) {
        throw 'This tournament has reached its maximum participants.';
      }

      final newParticipant = {'id': userId, 'gender': userGender, 'score': 0};
      final updatedParticipants = List<Map<String, dynamic>>.from(_participants)..add(newParticipant);

      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .update({'participants': updatedParticipants});

      if (mounted) {
        setState(() {
          _participants = updatedParticipants;
          _hasJoined = true;
        });
        await _generateTeams();
        await _generateLeaderboardData();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Joined Tournament'),
          description: Text('Successfully joined ${widget.tournament.name}!'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _successColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Join Failed'),
          description: Text('Failed to join tournament: $e'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _withdrawFromTournament(BuildContext context) async {
    if (_isLoading) return;
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    final userId = authState.user.uid;

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedParticipants = _participants.where((p) => p['id'] != userId).toList();
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournament.id)
          .update({'participants': updatedParticipants});

      if (mounted) {
        setState(() {
          _participants = updatedParticipants;
          _hasJoined = false;
        });
        await _generateTeams();
        await _generateLeaderboardData();
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Withdrawn'),
          description: Text('You have successfully withdrawn from ${widget.tournament.name}.'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _successColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } catch (e) {
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Withdrawal Failed'),
          description: Text('Failed to withdraw from tournament: $e'),
          autoCloseDuration: const Duration(seconds: 2),
          backgroundColor: _errorColor,
          foregroundColor: _textColor,
          alignment: Alignment.bottomCenter,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
DateTime get _withdrawDeadline {
  return widget.tournament.startDate.subtract(const Duration(days: 3));
}

bool get _canCreateMatches {
  final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  return now.isAfter(_withdrawDeadline);
}


  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final isClosed = widget.tournament.endDate != null && widget.tournament.endDate!.isBefore(now);
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : null;
    final isCreator = userId != null && widget.tournament.createdBy == userId;
    final withdrawDeadline = widget.tournament.startDate.subtract(const Duration(days: 3));
    final canWithdraw = now.isBefore(withdrawDeadline) && !isClosed;

    return Scaffold(
      backgroundColor: _primaryColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.tournament.name,
                  style: GoogleFonts.poppins(
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    _tournamentProfileImage != null && _tournamentProfileImage!.isNotEmpty
                        ? Image.network(
                            widget.tournament.profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/tournament_placholder.jpg',
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/tournament_placholder.jpg',
                            fit: BoxFit.cover,
                          ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _secondaryColor.withOpacity(0.7),
                            _primaryColor.withOpacity(0.7),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              backgroundColor: _secondaryColor,
              elevation: 10,
            ),
          ];
        },
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                _buildTournamentOverviewCard(isCreator, isClosed),
                const SizedBox(height: 5),
                if (!isCreator && !_hasJoined && !isClosed)
                  _buildActionButton(
                    text: 'REGISTER NOW',
                    onPressed: _isLoading ? null : () => _joinTournament(context),
                  ),
                if (!isCreator && _hasJoined)
                  _buildWithdrawSection(canWithdraw, withdrawDeadline, context),
                const SizedBox(height: 5),
    
               
               
                  const SizedBox(height: 10),
                  _buildTournamentTabs(isCreator),
                
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTournamentOverviewCard(bool isCreator, bool isClosed) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    color: _cardBackground,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showImageOptionsDialog(isCreator),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accentColor,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: widget.tournament.profileImage != null &&
                            widget.tournament.profileImage!.isNotEmpty
                        ? Image.network(
                            widget.tournament.profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              'assets/tournament_placholder.jpg',
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            'assets/tournament_placholder.jpg',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.tournament.name.isNotEmpty ? widget.tournament.name : 'Unnamed',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _textColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCreator)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _accentColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Created by You',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _textColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          widget.tournament.gameFormat.toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _accentColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isClosed ? _errorColor.withOpacity(0.7) : _successColor.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isClosed ? 'Closed' : 'Open',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_participants.length} / ${widget.tournament.maxParticipants} participants',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  

  Widget _buildWithdrawSection(bool canWithdraw, DateTime withdrawDeadline, BuildContext context) {
    return Column(
      children: [
        _buildActionButton(
          text: 'WITHDRAW REGISTRATION',
          onPressed: canWithdraw && !_isLoading ? () => _withdrawFromTournament(context) : null,
        ),
        if (!canWithdraw)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Withdrawal deadline: ${DateFormat('MMM dd, yyyy').format(withdrawDeadline)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _secondaryText,
              ),
            ),
          ),
      ],
    );
  }

 
  Widget _buildTournamentTabs(bool isCreator) {
  return Column(
    children: [
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: TabBar(
            dragStartBehavior: DragStartBehavior.down,
            controller: _tabController,
            isScrollable: true,
            splashFactory: NoSplash.splashFactory,
            overlayColor: MaterialStateProperty.resolveWith<Color?>(
              (states) => states.contains(MaterialState.pressed) 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1) 
                : null,
            ),
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.primary,
            ),
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: Theme.of(context).textTheme.labelLarge,
            tabs: const [
             Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Overview'))),
              Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Matches'))),
              Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Participants'))),
              Tab(child: Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('Leaderboard'))),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(),
            _buildMatchesTab(isCreator),
            _buildPlayersTab(),
            _buildLeaderboardTab(),
          ],
        ),
      ),
    ],
  );
}

tz.Location _getLocation(String timezoneName) {
  try {
    return tz.getLocation(timezoneName);
  } catch (e) {
    // Fallback to UTC if the timezone is not found
    return tz.getLocation('UTC');
  }
}


Widget _buildInfoTab() {
  final tournament = widget.tournament;
  final timeFormat = DateFormat('h:mm a');
  final dateFormat = DateFormat('MMM d, yyyy');
  
  // Get the timezone from tournament data or default to local timezone
  final timezone = tournament.timezone;
  final tzLocation = timezone.isNotEmpty 
      ? timezone 
      : 'UTC';

  // Helper function to format datetime with timezone
  String formatTimeWithTimezone(DateTime dateTime) {
    try {
      final localTime = tz.TZDateTime.from(dateTime, _getLocation(tzLocation));
      return '${timeFormat.format(localTime)} ($tzLocation)';
    } catch (e) {
      // Fallback if timezone conversion fails
      return '${timeFormat.format(dateTime)} (Local Time)';
    }
  }

  String formatDateRange(DateTime start, DateTime end) {
    try {
      final startLocal = TZDateTime.from(start, _getLocation(tzLocation));
      final endLocal = TZDateTime.from(end, _getLocation(tzLocation));
      
      if (startLocal.year == endLocal.year && 
          startLocal.month == endLocal.month && 
          startLocal.day == endLocal.day) {
        return dateFormat.format(startLocal);
      }
      return '${dateFormat.format(startLocal)} - ${dateFormat.format(endLocal)}';
    } catch (e) {
      // Fallback if timezone conversion fails
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return dateFormat.format(start);
      }
      return '${dateFormat.format(start)} - ${dateFormat.format(end)}';
    }
  }

  const String defaultBadmintonRules = '''
1. Matches follow BWF regulations - best of 3 games to 21 points (rally point scoring)
2. Players must report 15 minutes before scheduled match time
3. Proper sports attire and non-marking shoes required
4. Tournament director reserves the right to modify rules as needed
5. Any disputes will be resolved by the tournament committee
''';

  return SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tournament Details'.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.emoji_events_outlined,
                  title: 'Name',
                  value: tournament.name.isNotEmpty ? tournament.name : 'Not specified',
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.calendar_today_outlined,
                  title: 'Dates',
                  value: formatDateRange(tournament.startDate, tournament.endDate!),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.access_time_outlined,
                  title: 'Start Time',
                  value: formatTimeWithTimezone(tournament.startDate),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.location_on_outlined,
                  title: 'Venue',
                  value: (tournament.venue.isNotEmpty && tournament.city.isNotEmpty)
                      ? '${tournament.venue}, ${tournament.city}'
                      : 'Location not specified',
                  // ignore: unnecessary_null_comparison
                  trailing: tournament.timezone != null 
                      ? Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                          label: Text(
                            tournament.timezone,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  icon: Icons.sports_outlined,
                  title: 'Format',
                  value: tournament.gameFormat.isNotEmpty 
                    ? tournament.gameFormat 
                    : 'Not specified',
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.tour_outlined,
                  title: 'Type',
                  value: tournament.gameType.isNotEmpty 
                    ? tournament.gameType 
                    : 'Not specified',
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.people_outline,
                  title: 'Participants',
                  value: '${_participants.length} of ${tournament.maxParticipants}',
                  trailing: Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    label: Text(
                      '${(_participants.length/tournament.maxParticipants*100).round()}% full',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 24),
                _buildDetailRow(
                  icon: Icons.attach_money_outlined,
                  title: 'Entry Fee',
                  value: tournament.entryFee == 0 
                    ? 'Free entry' 
                    : '₹${tournament.entryFee.toStringAsFixed(0)}',
                ),
                if (tournament.bringOwnEquipment) ...[
                  const Divider(height: 24),
                  _buildDetailRow(
                    icon: Icons.sports_tennis_outlined,
                    title: 'Equipment',
                    value: 'Players must bring their own equipment',
                  ),
                ],
                if (tournament.costShared) ...[
                  const Divider(height: 24),
                  _buildDetailRow(
                    icon: Icons.attach_money_outlined,
                    title: 'Cost Sharing',
                    value: 'Court costs shared among participants',
                  ),
                ],
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rules & Regulations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tournament.rules != null && tournament.rules!.isNotEmpty
                      ? tournament.rules!
                      : defaultBadmintonRules,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
      ],
    ),
  );
}
Widget _buildDetailRow({
  required IconData icon,
  required String title,
  required String value,
  Widget? trailing,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,       
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
      if (trailing != null) trailing,
    ],
  );
}


Widget _buildMatchesTab(bool isCreator) {
  final tournament = widget.tournament;
  final timezoneLocation = tz.getLocation(tournament.timezone);
  final now = tz.TZDateTime.now(timezoneLocation);
  final isClosed = tournament.endDate != null &&
      tz.TZDateTime.from(tournament.endDate!, timezoneLocation).isBefore(now);

  // Group matches by round
  final matchesByRound = <int, List<Map<String, dynamic>>>{};
  for (var match in _matches) {
    final round = match['round'] as int? ?? 1;
    matchesByRound.putIfAbsent(round, () => []).add(match);
  }

  // Sort rounds to ensure consistent order (e.g., [1, 2] for Round 1 and Final)
  final sortedRounds = matchesByRound.keys.toList()..sort();

  // Initialize currentRound as state variable
  int currentRound = sortedRounds.isNotEmpty ? sortedRounds.first : 1;
  if (matchesByRound.isNotEmpty) {
    for (var round in sortedRounds) {
      final roundMatches = matchesByRound[round]!;
      final hasUpcoming = roundMatches.any((match) {
        final startTime = match['startTime'] as Timestamp?;
        if (startTime == null) return false;
        final matchTime = tz.TZDateTime.from(startTime.toDate(), timezoneLocation);
        return matchTime.isAfter(now) || 
               (matchTime.isBefore(now) && match['completed'] != true);
      });
      if (hasUpcoming) {
        currentRound = round;
        break;
      }
    }
    // If no upcoming matches, show the first round (not last)
    if (currentRound == sortedRounds.first && sortedRounds.length > 1) {
      currentRound = sortedRounds.first; // Ensure Round 1 is selected if no upcoming matches
    }
  }

  // Debug print to verify initial values
  debugPrint('sortedRounds: $sortedRounds, currentRound: $currentRound, initialPage: ${sortedRounds.indexOf(currentRound)}');

  // Create a PageController that jumps to the current round
  final pageController = PageController(
    initialPage: sortedRounds.indexOf(currentRound),
    viewportFraction: 0.95,
  );

  // Track selected match generation method
  String? selectedGenerationMethod;

  return StatefulBuilder(
    builder: (context, setState) {
      return Column(
        children: [
          if (isCreator && !isClosed)
            Column(
              children: [
                if (_matches.isNotEmpty && !_showMatchGenerationOptions && _canCreateMatches)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(Icons.restart_alt, color: _errorColor),
                      onPressed: _isLoading ? null : _resetMatches,
                      tooltip: 'Reset Matches',
                    ),
                  ),
                if ((_matches.isEmpty || _showMatchGenerationOptions) && _canCreateMatches)
                  Column(
                    children: [
                      Text(
                        'Select Match Generation Method',
                        style: GoogleFonts.poppins(
                          color: _textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              text: 'AUTO SCHEDULE',
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedGenerationMethod = 'AUTO';
                                      });
                                      _generateMatches();
                                    },
                              isSelected: selectedGenerationMethod == 'AUTO',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              text: 'MANUAL MATCH',
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() {
                                        selectedGenerationMethod = 'MANUAL';
                                      });
                                      _showManualMatchDialog(isCreator);
                                    },
                              isSelected: selectedGenerationMethod == 'MANUAL',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          if (!_canCreateMatches)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Match creation will be available after ${DateFormat('MMM dd, yyyy').format(_withdrawDeadline)}',
                style: GoogleFonts.poppins(
                  color: _secondaryText,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Expanded(
            child: _matches.isEmpty && (!isCreator || !_canCreateMatches)
                ? _buildEmptyState(
                    icon: Icons.schedule,
                    title: 'No Matches Scheduled',
                    description: isCreator && _canCreateMatches
                        ? 'Reset or select a match generation method'
                        : isCreator
                            ? 'Match creation will be available after ${DateFormat('MMM dd, yyyy').format(_withdrawDeadline)}'
                            : 'Waiting for organizer to schedule matches',
                  )
                : Column(
                    children: [
                      // Round indicator tabs
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: sortedRounds.length,
                          itemBuilder: (context, index) {
                            final round = sortedRounds[index];
                            final isCurrent = round == currentRound;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: ChoiceChip(
                                label: Row(
                                  children: [
                                    Text(
                                      round == sortedRounds.last && sortedRounds.length > 1
                                          ? 'Final'
                                          : 'Round $round',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                        color: isCurrent ? Colors.white : _textColor,
                                      ),
                                    ),
                                   
                                  ],
                                ),
                                selected: isCurrent,
                                selectedColor: _accentColor, // Orange color for selected round
                                backgroundColor: _secondaryColor.withOpacity(0.3),
                                onSelected: (_) {
                                  pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Matches pages
                      Expanded(
                        child: PageView.builder(
                          controller: pageController,
                          itemCount: sortedRounds.length,
                          onPageChanged: (index) {
                            setState(() {
                              currentRound = sortedRounds[index];
                              debugPrint('Page changed to index: $index, currentRound: $currentRound');
                            });
                          },
                          itemBuilder: (context, index) {
                            final round = sortedRounds[index];
                            final roundMatches = matchesByRound[round]!;
                            final isFinalRound = round == sortedRounds.last && sortedRounds.length > 1;
                            
                            return _buildRoundMatchesPage(
                              round: round,
                              matches: roundMatches,
                              isFinalRound: isFinalRound,
                              isCreator: isCreator,
                              timezoneLocation: timezoneLocation,
                            );
                          },
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

Widget _buildRoundMatchesPage({
  required int round,
  required List<Map<String, dynamic>> matches,
  required bool isFinalRound,
  required bool isCreator,
  required tz.Location timezoneLocation,
}) {
  final now = tz.TZDateTime.now(timezoneLocation);
  final timeFormat = DateFormat('h:mm a');
  final dateFormat = DateFormat('MMM d, yyyy');
  final isDoubles = _isDoublesTournament();
  

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: _cardBackground,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              isFinalRound ? 'FINAL ROUND' : 'ROUND $round',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _accentColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...matches.asMap().entries.map((entry) {
            final matchIndex = entry.key;
            final match = entry.value;
            final isCompleted = match['completed'] == true;
            final isLive = match['liveScores']?['isLive'] == true;
            final currentGame = match['liveScores']?['currentGame'] ?? 1;

            final team1Score = isDoubles
                ? (match['liveScores']?['team1'] as List<dynamic>?)?.isNotEmpty == true
                    ? match['liveScores']['team1'][currentGame - 1] ?? 0
                    : 0
                : (match['liveScores']?['player1'] as List<dynamic>?)?.isNotEmpty == true
                    ? match['liveScores']['player1'][currentGame - 1] ?? 0
                    : 0;
            final team2Score = isDoubles
                ? (match['liveScores']?['team2'] as List<dynamic>?)?.isNotEmpty == true
                    ? match['liveScores']['team2'][currentGame - 1] ?? 0
                    : 0
                : (match['liveScores']?['player2'] as List<dynamic>?)?.isNotEmpty == true
                    ? match['liveScores']['player2'][currentGame - 1] ?? 0
                    : 0;

            // Format match time with timezone
            String dateString = 'Date not available';
            String? countdownString;
            final Timestamp? startTime = match['startTime'];
            if (startTime != null) {
              final matchTime = tz.TZDateTime.from(startTime.toDate(), timezoneLocation);
              dateString = '${dateFormat.format(matchTime)} at ${timeFormat.format(matchTime)} ';

              if (!isLive && !isCompleted) {
                final difference = matchTime.difference(now);
                if (difference.isNegative) {
                  countdownString = 'Should have started';
                } else if (difference.inHours >= 24) {
                  final days = difference.inDays;
                  final hours = difference.inHours % 24;
                  countdownString = 'Starts in ${days}d ${hours}h';
                } else {
                  final hours = difference.inHours;
                  final minutes = difference.inMinutes % 60;
                  countdownString = 'Starts in ${hours}h ${minutes}m';
                }
              }
            }

            return AnimationConfiguration.staggeredList(
              position: matchIndex,
              duration: const Duration(milliseconds: 400),
              child: SlideAnimation(
                verticalOffset: 30.0,
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MatchDetailsPage(
                            tournamentId: widget.tournament.id,
                            match: match,
                            matchIndex: _matches.indexOf(match),
                            isCreator: isCreator,
                            isDoubles: isDoubles,
                            isUmpire: _isUmpire,
                            onDeleteMatch: () => _deleteMatch(_matches.indexOf(match)),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isLive 
                              ? _successColor 
                              : isCompleted 
                                  ? _accentColor.withOpacity(0.3) 
                                  : _secondaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isDoubles
                                            ? match['team1'].join(' & ')
                                            : match['player1'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        isDoubles
                                            ? match['team2'].join(' & ')
                                            : match['player2'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '$team1Score',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isLive && team1Score > team2Score
                                            ? _successColor
                                            : _textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$team2Score',
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isLive && team2Score > team1Score
                                            ? _successColor
                                            : _textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _secondaryColor.withOpacity(0.2),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isLive
                                          ? Icons.videocam
                                          : isCompleted
                                              ? Icons.check_circle
                                              : Icons.schedule,
                                      color: isLive
                                          ? _successColor
                                          : isCompleted
                                              ? _successColor
                                              : _secondaryText,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dateString,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: _secondaryText,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (countdownString != null)
                                          Text(
                                            countdownString,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: _secondaryText,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (isCreator && !isCompleted)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: _errorColor,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _showDeleteConfirmation(context, _matches.indexOf(match)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}

Widget _buildActionButton({
  required String text,
  required VoidCallback? onPressed,
  bool isSelected = false,
}) {
  return GestureDetector(
    onTap: onPressed,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSelected ? _accentColor : _secondaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _accentColor : _secondaryColor,
          width: 1.5,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : _textColor,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}
 Widget _buildPlayersTab() {
  final isDoubles = widget.tournament.gameFormat == 'Doubles';
  final competitors = isDoubles ? widget.tournament.teams : widget.tournament.participants;
  final matches = widget.tournament.matches;
  final authState = context.read<AuthBloc>().state;
  final isCreator = authState is AuthAuthenticated && widget.tournament.createdBy == authState.user.uid;
  final groups = _computeGroups(
    competitors: competitors,
    matches: matches,
    isDoubles: isDoubles,
  );

  if (competitors.isEmpty) {
    return _buildEmptyState(
      icon: Icons.people,
      title: 'No Players Registered',
      description: 'Waiting for participants to join the tournament.',
    );
  }

  return ListView.builder(
    physics: const BouncingScrollPhysics(),
    itemCount: groups.length,
    itemBuilder: (context, groupIndex) {
      final groupCompetitors = groups[groupIndex];
      final groupLabel = String.fromCharCode(65 + groupIndex); // A, B, C, etc.

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              'Group $groupLabel',
              style: GoogleFonts.poppins(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: groupCompetitors.length,
            itemBuilder: (context, index) {
              final competitor = groupCompetitors[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(isDoubles ? competitor['players'][0]['id'] : competitor['id'])
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 400),
                      child: SlideAnimation(
                        verticalOffset: 30.0,
                        child: FadeInAnimation(
                          child: _buildPlayerTile(
                            name: 'Loading...',
                            email: null,
                            score: isDoubles ? null : competitor['score'] ?? 0,
                            isCreator: isCreator,
                            competitorId: isDoubles ? competitor['teamId'] : competitor['id'],
                            onDelete: () => _deleteParticipant(
                                isDoubles ? competitor['teamId'] : competitor['id']),
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 400),
                      child: SlideAnimation(
                        verticalOffset: 30.0,
                        child: FadeInAnimation(
                          child: _buildPlayerTile(
                            name: 'Unknown Player',
                            email: null,
                            score: isDoubles ? null : competitor['score'] ?? 0,
                            isCreator: isCreator,
                            competitorId: isDoubles ? competitor['teamId'] : competitor['id'],
                            onDelete: () => _deleteParticipant(
                                isDoubles ? competitor['teamId'] : competitor['id']),
                          ),
                        ),
                      ),
                    );
                  }

                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  final firstName = userData['firstName'] ?? 'Unknown';
                  final lastName = userData['lastName'] ?? '';
                  final email = userData['email'] ?? '';
                  final name = '$firstName $lastName'.trim();

                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 400),
                    child: SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(
                        child: _buildPlayerTile(
                          name: isDoubles
                              ? competitor['players']
                                  .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                                  .join(' & ')
                              : name,
                          email: isCreator ? email : null,
                          score: isDoubles ? null : competitor['score'] ?? 0,
                          isCreator: isCreator,
                          competitorId: isDoubles ? competitor['teamId'] : competitor['id'],
                          onDelete: () => _deleteParticipant(
                              isDoubles ? competitor['teamId'] : competitor['id']),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
    },
  );
}

Widget _buildPlayerTile({
  required String name,
  String? email,
  int? score,
  required bool isCreator,
  required String competitorId,
  VoidCallback? onDelete,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: _cardBackground,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: _accentColor.withOpacity(0.2),
        child: Icon(Icons.person, color: _accentColor),
      ),
      title: Text(
        name,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (score != null)
            Text(
              'Score: $score',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _secondaryText,
              ),
            ),
          if (isCreator && email != null && email.isNotEmpty)
            Text(
              email,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _secondaryText,
              ),
            ),
        ],
      ),
      trailing: isCreator
          ? IconButton(
              icon: Icon(Icons.delete, color: _errorColor),
              onPressed: onDelete,
            )
          : null,
    ),
  );
}

Future<void> _deleteParticipant(int competitorId) async {
  if (_isLoading) return;
  final authState = context.read<AuthBloc>().state;
  if (authState is! AuthAuthenticated) return;
  final userId = authState.user.uid;

  // Check if the current user is the creator
  if (widget.tournament.createdBy != userId) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      title: const Text('Permission Denied'),
      description: const Text('Only the tournament creator can remove participants.'),
      autoCloseDuration: const Duration(seconds: 2),
      backgroundColor: _errorColor,
      foregroundColor: _textColor,
      alignment: Alignment.bottomCenter,
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final isDoubles = widget.tournament.gameFormat == 'Doubles';
    final updatedCompetitors = isDoubles
        ? List<Map<String, dynamic>>.from(widget.tournament.teams)
        : List<Map<String, dynamic>>.from(widget.tournament.participants);
    updatedCompetitors.removeWhere(
        (c) => (isDoubles ? c['teamId'] : c['id']) == competitorId);

    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournament.id)
        .update({
      isDoubles ? 'teams' : 'participants': updatedCompetitors,
    });

    if (mounted) {
      setState(() {
        if (isDoubles) {
          _teams = updatedCompetitors;
        } else {
          _participants = updatedCompetitors;
          _hasJoined = updatedCompetitors.any((p) => p['id'] == authState.user.uid);
        }
      });
      await _generateTeams();
      await _generateLeaderboardData();
      toastification.show(
        context: context,
        type: ToastificationType.success,
        title: const Text('Participant Removed'),
        description: const Text('The participant has been successfully removed.'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _successColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
    }
  } catch (e) {
    if (mounted) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Removal Failed'),
        description: Text('Failed to remove participant: $e'),
        autoCloseDuration: const Duration(seconds: 2),
        backgroundColor: _errorColor,
        foregroundColor: _textColor,
        alignment: Alignment.bottomCenter,
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

Widget _buildLeaderboardTab() {
  final isDoubles = _isDoublesTournament();
  final competitors = isDoubles ? _teams : _participants;
  final matches = _matches;
  final groups = _computeGroups(
    competitors: competitors,
    matches: matches,
    isDoubles: isDoubles,
  );

  if (competitors.isEmpty) {
    return _buildEmptyState(
      icon: Icons.leaderboard,
      title: 'No Standings Available',
      description: 'No participants or teams registered yet.',
    );
  }

  return ListView.builder(
    physics: const BouncingScrollPhysics(),
    itemCount: groups.length,
    itemBuilder: (context, groupIndex) {
      final groupLabel = String.fromCharCode(65 + groupIndex); // A, B, C, etc.
      final groupCompetitors = groups[groupIndex];

      // Compute leaderboard data for this group
      final groupLeaderboard = groupCompetitors
          .asMap()
          .entries
          .map((entry) {
            final competitor = entry.value;
            return MapEntry(
              isDoubles ? competitor['teamId'] : competitor['id'],
              {
                'name': isDoubles
                    ? competitor['players']
                        .map((p) => '${p['firstName']} ${p['lastName']}'.trim())
                        .join(' & ')
                    : competitor['name'],
                'score': competitor['score'] ?? 0,
                'group': groupIndex,
              },
            );
          })
          .toList()
        ..sort((a, b) {
          final scoreCompare = b.value['score'].compareTo(a.value['score']);
          if (scoreCompare != 0) return scoreCompare;
          return a.value['name'].compareTo(b.value['name']);
        });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              'Group $groupLabel',
              style: GoogleFonts.poppins(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: _textColor,
              ),
            ),
          ),
          if (groupLeaderboard.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('No leaderboard data available for this group.'),
            ),
          if (groupLeaderboard.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _cardBackground,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (groupLeaderboard.length >= 2)
                    _buildPodiumItem(
                      rank: 2,
                      name: groupLeaderboard[1].value['name'],
                      score: groupLeaderboard[1].value['score'],
                      color: _silverColor,
                      height: 120,
                    ),
                  if (groupLeaderboard.isNotEmpty)
                    _buildPodiumItem(
                      rank: 1,
                      name: groupLeaderboard[0].value['name'],
                      score: groupLeaderboard[0].value['score'],
                      color: _goldColor,
                      height: 160,
                    ),
                  if (groupLeaderboard.length >= 3)
                    _buildPodiumItem(
                      rank: 3,
                      name: groupLeaderboard[2].value['name'],
                      score: groupLeaderboard[2].value['score'],
                      color: _bronzeColor,
                      height: 100,
                    ),
                ],
              ),
            ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: groupLeaderboard.length,
            itemBuilder: (context, index) {
              final entry = groupLeaderboard[index];
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 400),
                child: SlideAnimation(
                  verticalOffset: 30.0,
                  child: FadeInAnimation(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: _accentColor.withOpacity(0.2),
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _accentColor,
                            ),
                          ),
                        ),
                        title: Text(
                          entry.value['name'],
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                        trailing: Text(
                          'Score: ${entry.value['score']}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

  Widget _buildPodiumItem({
    required int rank,
    required String name,
    required int score,
    required Color color,
    required double height,
  }) {
    return Column(
      children: [
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$rank',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Score: $score',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: _secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: _secondaryText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: _secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}