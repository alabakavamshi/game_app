
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_app/tournaments/match_details_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class MatchHistoryPage extends StatefulWidget {
  final String playerId;

  const MatchHistoryPage({super.key, required this.playerId});

  @override
  State<MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> {
  List<Map<String, dynamic>> _matches = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showToast = false;
  String? _toastMessage;
  ToastificationType? _toastType;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones(); // Initialize timezone data
    _fetchPlayerMatches();
  }

  Future<void> _fetchPlayerMatches() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('Searching matches for player: ${widget.playerId}');

      final tournamentsQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .get();

      debugPrint('Found ${tournamentsQuery.docs.length} tournaments');

      final List<Map<String, dynamic>> playerMatches = [];

      for (var tournamentDoc in tournamentsQuery.docs) {
        final tournamentData = tournamentDoc.data();
        final matches = List<Map<String, dynamic>>.from(tournamentData['matches'] ?? []);
        final tournamentTimezone = tournamentData['timezone']?.toString() ?? 'Asia/Kolkata';
        tz.Location tzLocation;
        try {
          tzLocation = tz.getLocation(tournamentTimezone);
        } catch (e) {
          debugPrint('Invalid timezone for tournament ${tournamentDoc.id}: $tournamentTimezone, defaulting to Asia/Kolkata');
          tzLocation = tz.getLocation('Asia/Kolkata');
        }

        for (var match in matches) {
          debugPrint('Match: ${match['player1']} vs ${match['player2']}');
          debugPrint('Player IDs: ${match['player1Id']} | ${match['player2Id']}');
          debugPrint('Team IDs: ${match['team1Ids']} | ${match['team2Ids']}');

          if (_isPlayerInMatch(match) && match['completed'] == true) {
            debugPrint('MATCH FOUND FOR PLAYER ${widget.playerId}');
            final startTime = match['startTime'] != null
                ? (match['startTime'] as Timestamp).toDate()
                : (tournamentData['startDate'] as Timestamp).toDate();
            final startTimeInTz = tz.TZDateTime.from(startTime, tzLocation);
            playerMatches.add({
              ...match,
              'tournamentId': tournamentDoc.id,
              'tournamentName': tournamentData['name'] ?? 'Unnamed Tournament',
              'startTime': startTime, // Keep for compatibility
              'startTimeInTz': startTimeInTz,
              'timezone': tournamentTimezone,
              'endDate': tournamentData['endDate'],
              'venue': tournamentData['venue'],
              'city': tournamentData['city'],
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _matches = playerMatches..sort((a, b) => (b['startTimeInTz'] as tz.TZDateTime).compareTo(a['startTimeInTz'] as tz.TZDateTime));
          _isLoading = false;
          if (playerMatches.isEmpty) {
            _showToast = true;
            _toastMessage = 'No completed matches found for this player';
            _toastType = ToastificationType.info;
            debugPrint('NO MATCHES FOUND - Check player ID and match data');
          } else {
            debugPrint('Successfully found ${playerMatches.length} matches');
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching matches: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load matches: ${e.toString()}';
          _isLoading = false;
          _showToast = true;
          _toastMessage = 'Error loading matches';
          _toastType = ToastificationType.error;
        });
      }
    }
  }

  bool _isPlayerInMatch(Map<String, dynamic> match) {
    final player1Id = match['player1Id']?.toString() ?? '';
    final player2Id = match['player2Id']?.toString() ?? '';
    final team1Ids = (match['team1Ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final team2Ids = (match['team2Ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    debugPrint('Checking match for player ${widget.playerId} against:');
    debugPrint('Player1: $player1Id');
    debugPrint('Player2: $player2Id');
    debugPrint('Team1: $team1Ids');
    debugPrint('Team2: $team2Ids');

    return player1Id == widget.playerId ||
           player2Id == widget.playerId ||
           team1Ids.contains(widget.playerId) ||
           team2Ids.contains(widget.playerId);
  }

  String _getMatchResult(Map<String, dynamic> match) {
    final liveScores = match['liveScores'] as Map<String, dynamic>? ?? {};
    final player1Scores = liveScores['player1'] as List<dynamic>? ?? [];
    final player2Scores = liveScores['player2'] as List<dynamic>? ?? [];
    final winner = match['winner']?.toString();
    final player1Id = match['player1Id']?.toString() ?? '';
    final player2Id = match['player2Id']?.toString() ?? '';

    int player1Sets = 0;
    int player2Sets = 0;
    for (int i = 0; i < player1Scores.length && i < player2Scores.length; i++) {
      if (player1Scores[i] > player2Scores[i] && player1Scores[i] >= 21) {
        player1Sets++;
      } else if (player2Scores[i] > player1Scores[i] && player2Scores[i] >= 21) {
        player2Sets++;
      }
    }
    final setScore = '$player1Sets-$player2Sets';

    bool isPlayerWinner = (winner == 'player1' && player1Id == widget.playerId) ||
                         (winner == 'player2' && player2Id == widget.playerId);

    return isPlayerWinner ? 'Won: $setScore' : 'Lost: $setScore';
  }

  Color _getResultColor(Map<String, dynamic> match) {
    final winner = match['winner']?.toString();
    final player1Id = match['player1Id']?.toString() ?? '';
    final player2Id = match['player2Id']?.toString() ?? '';

    bool isPlayerWinner = (winner == 'player1' && player1Id == widget.playerId) ||
                         (winner == 'player2' && player2Id == widget.playerId);

    return isPlayerWinner ? const Color(0xFF2A9D8F) : const Color(0xFFE76F51); // Success or Error
  }

  void _navigateToMatchDetails(Map<String, dynamic> match) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchDetailsPage(
          tournamentId: match['tournamentId'],
          match: match,
          matchIndex: _matches.indexOf(match),
          isCreator: false,
          isDoubles: match['team1Ids'] != null && match['team2Ids'] != null,
          isUmpire: false,
          onDeleteMatch: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showToast && _toastMessage != null && _toastType != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        toastification.show(
          context: context,
          type: _toastType!,
          title: Text(
            _toastType == ToastificationType.error ? 'Error' : 'Info',
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
          ),
          description: Text(
            _toastMessage!,
            style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
          ),
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: _toastType == ToastificationType.error
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

    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), // Background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C9A8B), Color(0xFFC1DADB)], // Primary to Secondary
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF757575)), // Text Secondary
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  'Match History',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF333333), // Text Primary
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF757575), size: 28), // Text Secondary
                    onPressed: _fetchPlayerMatches,
                    tooltip: 'Refresh History',
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF4A261)))) // Accent
                      : _errorMessage != null
                          ? Center(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFE76F51), // Error
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _matches.isEmpty
                              ? Center(
                                  child: Text(
                                    'No completed matches found in your history',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF757575), // Text Secondary
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : AnimationConfiguration.synchronized(
                                  child: Column(
                                    children: AnimationConfiguration.toStaggeredList(
                                      duration: const Duration(milliseconds: 500),
                                      childAnimationBuilder: (child) => SlideAnimation(
                                        verticalOffset: 50.0,
                                        child: FadeInAnimation(child: child),
                                      ),
                                      children: _matches.map((match) {
                                        final startTimeInTz = match['startTimeInTz'] as tz.TZDateTime;
                                        final timezoneDisplay = match['timezone'] == 'Asia/Kolkata' ? 'IST' : match['timezone'];
                                        final formattedTime = DateFormat('MMM dd, yyyy, hh:mm a').format(startTimeInTz) + ' $timezoneDisplay';
                                        final isDoubles = match['team1Ids'] != null && match['team2Ids'] != null;
                                        final result = _getMatchResult(match);
                                        final resultColor = _getResultColor(match);

                                        return GestureDetector(
                                          onTap: () => _navigateToMatchDetails(match),
                                          child: Card(
                                            color: const Color(0xFFFFFFFF), // Surface
                                            margin: const EdgeInsets.only(bottom: 16),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                              side: BorderSide(color: const Color(0xFFA8DADC).withOpacity(0.5)), // Cool Blue Highlights
                                            ),
                                            elevation: 4,
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Icon(
                                                    Icons.check_circle,
                                                    color: const Color(0xFF2A9D8F), // Success
                                                    size: 24,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          isDoubles
                                                              ? '${match['team1']?.join(', ') ?? 'Team 1'} vs ${match['team2']?.join(', ') ?? 'Team 2'}'
                                                              : '${match['player1'] ?? 'Player 1'} vs ${match['player2'] ?? 'Player 2'}',
                                                          style: GoogleFonts.poppins(
                                                            color: const Color(0xFF333333), // Text Primary
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          'Tournament: ${match['tournamentName']}',
                                                          style: GoogleFonts.poppins(
                                                            color: const Color(0xFF757575), // Text Secondary
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Round: ${match['round'] ?? '1'}',
                                                          style: GoogleFonts.poppins(
                                                            color: const Color(0xFF757575), // Text Secondary
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          'Time: $formattedTime',
                                                          style: GoogleFonts.poppins(
                                                            color: const Color(0xFF757575), // Text Secondary
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                      ],
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: resultColor.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: resultColor),
                                                    ),
                                                    child: Text(
                                                      result,
                                                      style: GoogleFonts.poppins(
                                                        color: resultColor,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    Icons.arrow_forward_ios,
                                                    color: const Color(0xFF6C9A8B), // Primary
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
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