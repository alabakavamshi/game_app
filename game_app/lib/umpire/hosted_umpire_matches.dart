import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class UmpiredMatchesPage extends StatefulWidget {
  final String userId;

  const UmpiredMatchesPage({super.key, required this.userId});

  @override
  State<UmpiredMatchesPage> createState() => _UmpiredMatchesPageState();
}

class _UmpiredMatchesPageState extends State<UmpiredMatchesPage> {
  late Stream<QuerySnapshot> _tournamentsStream;
  final currentUserEmail = FirebaseAuth.instance.currentUser?.email?.toLowerCase();

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones(); // Initialize timezone data
    _tournamentsStream = FirebaseFirestore.instance
        .collection('tournaments')
        .where('matches', isNotEqualTo: [])
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Umpired Matches',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tournamentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading matches',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel, size: 48, color: Colors.white70),
                  const SizedBox(height: 16),
                  Text(
                    'No umpired matches',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have not been assigned as umpire for any matches',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final umpiredMatches = <Map<String, dynamic>>[];
          for (var tournamentDoc in snapshot.data!.docs) {
            final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
            final matches = List<Map<String, dynamic>>.from(tournamentData['matches'] ?? []);
            final tournamentTimezone = tournamentData['timezone']?.toString() ?? 'Asia/Kolkata';
            tz.Location tzLocation;
            try {
              tzLocation = tz.getLocation(tournamentTimezone);
            } catch (e) {
              debugPrint('Invalid timezone for tournament ${tournamentDoc.id}: $tournamentTimezone, defaulting to Asia/Kolkata');
              tzLocation = tz.getLocation('Asia/Kolkata');
            }

            for (var i = 0; i < matches.length; i++) {
              final match = matches[i];
              if (match.containsKey('umpire')) {
                final umpireData = match['umpire'] as Map<String, dynamic>?;
                final umpireEmail = umpireData?['email'] as String?;

                if (umpireEmail != null && umpireEmail.isNotEmpty && umpireEmail.toLowerCase() == currentUserEmail) {
                  final startTime = (match['startDate'] as Timestamp?)?.toDate() ??
                      (tournamentData['startDate'] as Timestamp).toDate();
                  final startTimeInTz = tz.TZDateTime.from(startTime, tzLocation);

                  umpiredMatches.add({
                    ...match,
                    'tournamentId': tournamentDoc.id,
                    'matchIndex': i,
                    'tournamentName': tournamentData['name'] ?? 'Unnamed Tournament',
                    'gameFormat': tournamentData['gameFormat'] ?? 'Unknown Format',
                    'startTime': startTime, // Keep for compatibility
                    'startTimeInTz': startTimeInTz,
                    'timezone': tournamentTimezone,
                  });
                }
              }
            }
          }

          if (umpiredMatches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel, size: 48, color: Colors.white70),
                  const SizedBox(height: 16),
                  Text(
                    'No umpired matches',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have not been assigned as umpire for any matches',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          umpiredMatches.sort(
            (a, b) => (b['startTimeInTz'] as tz.TZDateTime).compareTo(a['startTimeInTz'] as tz.TZDateTime),
          );

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: umpiredMatches.length,
            itemBuilder: (context, index) {
              final match = umpiredMatches[index];
              final isDoubles = match['gameFormat']?.toString().toLowerCase().contains('doubles') ?? false;
              final team1 = isDoubles
                  ? (match['team1'] as List<dynamic>?)?.join(' & ') ?? 'Team 1'
                  : match['player1'] ?? 'Player 1';
              final team2 = isDoubles
                  ? (match['team2'] as List<dynamic>?)?.join(' & ') ?? 'Team 2'
                  : match['player2'] ?? 'Player 2';
              final isCompleted = match['completed'] ?? false;
              final isLive = match['liveScores']?['isLive'] ?? false;
              final currentGame = match['liveScores']?['currentGame'] ?? 1;
              final team1Scores = List<int>.from(
                  match['liveScores']?[isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
              final team2Scores = List<int>.from(
                  match['liveScores']?[isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
              final startTime = match['startTimeInTz'] as tz.TZDateTime;
              final tournamentName = match['tournamentName'];
              final gameFormat = match['gameFormat'];
              final round = match['round'] ?? 1;
              final timezoneDisplay = match['timezone'] == 'Asia/Kolkata'
                  ? 'IST'
                  : match['timezone'];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              tournamentName,
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Round $round',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$team1 vs $team2',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$gameFormat • Time in $timezoneDisplay',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? Colors.greenAccent.withOpacity(0.2)
                                  : isLive
                                      ? Colors.amberAccent.withOpacity(0.2)
                                      : Colors.cyanAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isCompleted
                                    ? Colors.greenAccent
                                    : isLive
                                        ? Colors.amberAccent
                                        : Colors.cyanAccent,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              isCompleted
                                  ? 'Completed'
                                  : isLive
                                      ? 'In Progress'
                                      : 'Scheduled',
                              style: GoogleFonts.poppins(
                                color: isCompleted
                                    ? Colors.greenAccent
                                    : isLive
                                        ? Colors.amberAccent
                                        : Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.gavel, size: 20, color: Colors.white70),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 16, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('MMM d, y • h:mm a').format(startTime) + ' $timezoneDisplay',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (isLive) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.scoreboard, size: 16, color: Colors.amberAccent),
                            const SizedBox(width: 8),
                            Text(
                              'Score: ${team1Scores[currentGame - 1]} - ${team2Scores[currentGame - 1]}',
                              style: GoogleFonts.poppins(
                                color: Colors.amberAccent,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isCompleted && match['winner'] != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.emoji_events, size: 16, color: Colors.greenAccent),
                            const SizedBox(width: 8),
                            Text(
                              'Winner: ${match['winner'] == (isDoubles ? 'team1' : 'player1') ? team1 : team2}',
                              style: GoogleFonts.poppins(
                                color: Colors.greenAccent,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}