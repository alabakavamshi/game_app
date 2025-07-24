import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:game_app/models/tournament.dart';
import 'package:game_app/tournaments/tournament_details_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

class TournamentHistoryPage extends StatefulWidget {
  final String userId;

  const TournamentHistoryPage({super.key, required this.userId});

  @override
  State<TournamentHistoryPage> createState() => _TournamentHistoryPageState();
}

class _TournamentHistoryPageState extends State<TournamentHistoryPage> {
  late Stream<List<Map<String, dynamic>>> _concludedTournamentsStream;

  @override
  void initState() {
    super.initState();
    _concludedTournamentsStream = FirebaseFirestore.instance
        .collection('tournaments')
        .where('createdBy', isEqualTo: widget.userId)
        .where('endDate', isLessThan: Timestamp.now())
        .orderBy('endDate', descending: false)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name']?.toString() ?? 'Unnamed Tournament',
                'endDate': (data['endDate'] as Timestamp).toDate(),
                'startDate': (data['startDate'] as Timestamp).toDate(),
                'location': (data['venue']?.toString().isNotEmpty == true && data['city']?.toString().isNotEmpty == true)
                    ? '${data['venue']}, ${data['city']}'
                    : 'Unknown',
                'participantCount': (data['participants'] as List?)?.length ?? 0,
                'entryFee': (data['entryFee'] as num?)?.toDouble() ?? 0.0,
              };
            }).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A506B),
        title: Text(
          'Tournament History',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _concludedTournamentsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading history: ${snapshot.error}',
                style: GoogleFonts.poppins(color: Colors.red, fontSize: 16),
              ),
            );
          }

          final tournaments = snapshot.data ?? [];
          if (tournaments.isEmpty) {
            return Center(
              child: Text(
                'No concluded tournaments found.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              final tournament = tournaments[index];
              return GestureDetector(
                onTap: () async {
                  final tournamentDoc = await FirebaseFirestore.instance
                      .collection('tournaments')
                      .doc(tournament['id'])
                      .get();
                  if (tournamentDoc.exists) {
                    final tournamentData = tournamentDoc.data()!;
                    final tournament = Tournament.fromFirestore(tournamentData, tournamentDoc.id);
                    final creatorDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(tournament.createdBy)
                        .get();
                    final creatorName = creatorDoc.data()?['firstName']?.toString().isNotEmpty == true
                        ? '${creatorDoc.data()!['firstName'].toString().capitalize()} ${creatorDoc.data()!['lastName']?.toString().isNotEmpty == true ? creatorDoc.data()!['lastName'].toString().capitalize() : ''}'
                        : 'Organizer';
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TournamentDetailsPage(
                            tournament: tournament,
                            creatorName: creatorName,
                          ),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      toastification.show(
                        context: context,
                        type: ToastificationType.error,
                        title: const Text('Error'),
                        description: const Text('Tournament data not found.'),
                        autoCloseDuration: const Duration(seconds: 2),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        alignment: Alignment.bottomCenter,
                      );
                    }
                  }
                },
                child: Card(
                  color: const Color(0xFF1B263B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      tournament['name'],
                      style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date: ${DateFormat('MMM dd, yyyy').format(tournament['endDate'])}',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Location: ${tournament['location']}',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Participants: ${tournament['participantCount']}',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Entry Fee: ₹${tournament['entryFee'].toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white70),
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