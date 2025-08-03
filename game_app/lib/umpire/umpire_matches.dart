import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/screens/countdown_text.dart';
import 'package:game_app/umpire/matchcontrolpage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class UmpireMatchesPage extends StatefulWidget {
  const UmpireMatchesPage({super.key});

  @override
  State<UmpireMatchesPage> createState() => _UmpireMatchesPageState();
}

class _UmpireMatchesPageState extends State<UmpireMatchesPage> {
  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones(); // Initialize timezone data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFDFCFB),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
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
              ),
              Expanded(
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFFF4A261)),
                      );
                    } else if (state is AuthAuthenticated) {
                      final umpireEmail = state.user.email;
                      if (umpireEmail == null) {
                        return Center(
                          child: Text(
                            'No email associated with this account',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF757575),
                              fontSize: 16,
                            ),
                          ),
                        );
                      }
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tournaments')
                            .where('matches', isNotEqualTo: [])
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: Color(0xFFF4A261)),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading schedule',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFFE76F51),
                                  fontSize: 16,
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'No tournaments available',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF757575),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Logged in as: $umpireEmail',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF757575),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final matchesList = <Map<String, dynamic>>[];
                          for (var doc in snapshot.data!.docs) {
                            final tournamentId = doc.id;
                            final tournamentData = doc.data() as Map<String, dynamic>;
                            final matches = List<Map<String, dynamic>>.from(tournamentData['matches'] ?? []);
                            final isDoubles = (tournamentData['gameFormat'] ?? '').toLowerCase().contains('doubles');
                            final tournamentStartDate = tournamentData['startDate'] as Timestamp?;
                            final tournamentStartTime = tournamentData['startTime'] as Map<String, dynamic>?;
                            final timezoneName = tournamentData['timezone'] as String? ?? 'UTC';
                            final timezone = tz.getLocation(timezoneName);

                            tz.TZDateTime? tournamentDateTime;
                            if (tournamentStartDate != null && tournamentStartTime != null) {
                              final startDate = tournamentStartDate.toDate();
                              final hour = tournamentStartTime['hour'] as int? ?? 0;
                              final minute = tournamentStartTime['minute'] as int? ?? 0;
                              tournamentDateTime = tz.TZDateTime(
                                timezone,
                                startDate.year,
                                startDate.month,
                                startDate.day,
                                hour,
                                minute,
                              );
                            }

                            for (var i = 0; i < matches.length; i++) {
                              final match = matches[i];
                              final matchUmpireEmail = match['umpire']?['email'] as String?;
                              if (matchUmpireEmail != null && matchUmpireEmail.toLowerCase() == umpireEmail.toLowerCase()) {
                                matchesList.add({
                                  ...match,
                                  'tournamentId': tournamentId,
                                  'matchIndex': i,
                                  'isDoubles': isDoubles,
                                  'tournamentName': tournamentData['name'] ?? 'Tournament',
                                  'tournamentDateTime': tournamentDateTime,
                                  'timezone': timezoneName,
                                });
                              }
                            }
                          }

                          final now = tz.TZDateTime.now(tz.getLocation('Asia/Kolkata')); // Current time in IST
                          matchesList.sort((a, b) {
                            final timeA = (a['startTime'] as Timestamp?)?.toDate() ??
                                a['tournamentDateTime'] ?? tz.TZDateTime(tz.getLocation(a['timezone'] ?? 'UTC'), 2100);
                            final timeB = (b['startTime'] as Timestamp?)?.toDate() ??
                                b['tournamentDateTime'] ?? tz.TZDateTime(tz.getLocation(b['timezone'] ?? 'UTC'), 2100);
                            final aIsLive = a['liveScores']?['isLive'] == true;
                            final aIsCompleted = a['completed'] == true;
                            final bIsLive = b['liveScores']?['isLive'] == true;
                            final bIsCompleted = b['completed'] == true;
                            final aIsReady = !aIsLive && !aIsCompleted && timeA.isBefore(now);
                            final bIsReady = !bIsLive && !bIsCompleted && timeB.isBefore(now);

                            if (aIsLive && !bIsLive) return -1;
                            if (!aIsLive && bIsLive) return 1;
                            if (aIsReady && !bIsReady && !bIsLive) return -1;
                            if (!aIsReady && bIsReady && !aIsLive) return 1;
                            if (!aIsLive && !aIsReady && !bIsLive && !bIsReady && !aIsCompleted && bIsCompleted) {
                              return -1;
                            }
                            if (!aIsLive && !aIsReady && !bIsLive && !bIsReady && aIsCompleted && !bIsCompleted) {
                              return 1;
                            }
                            if (aIsCompleted && bIsCompleted) {
                              return timeB.compareTo(timeA);
                            }
                            return timeA.compareTo(timeB);
                          });

                          if (matchesList.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.schedule, size: 48, color: Color(0xFF757575)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No matches assigned',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF757575),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'You currently have no officiating assignments',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xFF757575),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return AnimationLimiter(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: matchesList.length,
                              itemBuilder: (context, index) {
                                final matchData = matchesList[index];
                                final match = Map<String, dynamic>.from(matchData);
                                final tournamentId = match['tournamentId'];
                                final matchIndex = match['matchIndex'];
                                final isDoubles = match['isDoubles'];
                                final team1 = isDoubles
                                    ? (match['team1'] as List<dynamic>?)?.join(' & ') ?? 'Team 1'
                                    : match['player1'] ?? 'Player 1';
                                final team2 = isDoubles
                                    ? (match['team2'] as List<dynamic>?)?.join(' & ') ?? 'Team 2'
                                    : match['player2'] ?? 'Player 2';
                                final isLive = match['liveScores']?['isLive'] ?? false;
                                final isCompleted = match['completed'] ?? false;
                                final matchStartTime = match['startTime'] as Timestamp?;
                                final tournamentDateTime = match['tournamentDateTime'] as tz.TZDateTime?;
                                final timezoneName = match['timezone'] as String? ?? 'UTC';
                                final timezone = tz.getLocation(timezoneName);

                                final displayTime = matchStartTime != null
                                    ? tz.TZDateTime.from(matchStartTime.toDate(), timezone)
                                    : tournamentDateTime;
                                final countdownTime = matchStartTime ??
                                    (tournamentDateTime != null ? Timestamp.fromDate(tournamentDateTime) : null);

                                String status;
                                Color statusColor;
                                if (isCompleted) {
                                  status = 'Completed';
                                  statusColor = const Color(0xFF2A9D8F);
                                } else if (isLive) {
                                  status = 'In Progress';
                                  statusColor = const Color(0xFFE9C46A);
                                } else if (countdownTime != null &&
                                    tz.TZDateTime.from(countdownTime.toDate(), timezone).isBefore(now)) {
                                  status = 'Ready to Start';
                                  statusColor = const Color(0xFFF4A261);
                                } else {
                                  status = 'Scheduled';
                                  statusColor = const Color(0xFF757575);
                                }

                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: 500),
                                  child: SlideAnimation(
                                    verticalOffset: 50.0,
                                    child: FadeInAnimation(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          color: status == 'Ready to Start'
                                              ? const Color(0xFFF4A261).withOpacity(0.1)
                                              : const Color(0xFFFFFFFF),
                                          border: Border.all(
                                            color: const Color(0xFF6C9A8B).withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(16),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => MatchControlPage(
                                                  tournamentId: tournamentId,
                                                  match: match,
                                                  matchIndex: matchIndex,
                                                  isDoubles: isDoubles,
                                                ),
                                              ),
                                            );
                                          },
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
                                                        '$team1 vs $team2',
                                                        style: GoogleFonts.poppins(
                                                          color: const Color(0xFF333333),
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(color: statusColor.withOpacity(0.5)),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: GoogleFonts.poppins(
                                                          color: statusColor,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  match['tournamentName'],
                                                  style: GoogleFonts.poppins(
                                                    color: const Color(0xFF757575),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                if (displayTime != null)
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.schedule, size: 16, color: Color(0xFF757575)),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${DateFormat('MMM d, y • h:mm a').format(displayTime)} ($timezoneName)',
                                                        style: GoogleFonts.poppins(
                                                          color: const Color(0xFF757575),
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                const SizedBox(height: 8),
                                                if (!isLive && !isCompleted && countdownTime != null)
                                                  CountdownText(
                                                    matchTime: matchStartTime,
                                                    tournamentTime: countdownTime,
                                                  ),
                                                if (isLive && match['liveScores'] != null)
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.scoreboard, size: 16, color: Color(0xFFE9C46A)),
                                                      const SizedBox(width: 8),
                                                      Builder(
                                                        builder: (context) {
                                                          final currentGame = match['liveScores']['currentGame'] ?? 1;
                                                          final team1Scores = List<int>.from(
                                                              match['liveScores'][isDoubles ? 'team1' : 'player1'] ?? [0, 0, 0]);
                                                          final team2Scores = List<int>.from(
                                                              match['liveScores'][isDoubles ? 'team2' : 'player2'] ?? [0, 0, 0]);
                                                          return Text(
                                                            'Current: ${team1Scores[currentGame - 1]} - ${team2Scores[currentGame - 1]}',
                                                            style: GoogleFonts.poppins(
                                                              color: const Color(0xFFE9C46A),
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                if (isCompleted && match['winner'] != null)
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.emoji_events, size: 16, color: Color(0xFF2A9D8F)),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Winner: ${match['winner'] == (isDoubles ? 'team1' : 'player1') ? team1 : team2}',
                                                        style: GoogleFonts.poppins(
                                                          color: const Color(0xFF2A9D8F),
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w500,
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
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    } else {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Color(0xFFE76F51)),
                            const SizedBox(height: 16),
                            Text(
                              'Authentication required',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF757575),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please log in as an official',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF757575),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}