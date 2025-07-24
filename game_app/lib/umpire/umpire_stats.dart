import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class UmpireStatsPage extends StatefulWidget {
  final String userId;
  final String userEmail;

  const UmpireStatsPage({super.key, required this.userId, required this.userEmail});

  @override
  State<UmpireStatsPage> createState() => _UmpireStatsPageState();
}

class _UmpireStatsPageState extends State<UmpireStatsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  int _totalMatches = 0;
  int _completedMatches = 0;
  int _ongoingMatches = 0;
  int _totalTournaments = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get all tournaments (we'll filter matches locally)
      final tournamentsQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .get();

      final Set<String> tournamentIds = {};
      int totalMatches = 0;
      int completedMatches = 0;
      int ongoingMatches = 0;

      for (var tournamentDoc in tournamentsQuery.docs) {
        final tournamentData = tournamentDoc.data();
        final matches = List<Map<String, dynamic>>.from(tournamentData['matches'] ?? []);

        bool umpireInThisTournament = false;

        for (var match in matches) {
          try {
            // Check umpire assignment at MATCH level
            final matchUmpire = match['umpire'] as Map<String, dynamic>?;
            if (matchUmpire == null) continue;

            final matchUmpireEmail = (matchUmpire['email'] as String?)?.toLowerCase().trim();
            if (matchUmpireEmail != widget.userEmail.toLowerCase().trim()) continue;

            // Count this match
            totalMatches++;
            umpireInThisTournament = true;

            // Check match status
            if (match['completed'] == true) {
              completedMatches++;
            } else if (match['liveScores']?['isLive'] == true) {
              ongoingMatches++;
            }
          } catch (e) {
            debugPrint('Error processing match: $e');
          }
        }

        if (umpireInThisTournament) {
          tournamentIds.add(tournamentDoc.id);
        }
      }

      if (mounted) {
        setState(() {
          _totalMatches = totalMatches;
          _completedMatches = completedMatches;
          _ongoingMatches = ongoingMatches;
          _totalTournaments = tournamentIds.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load stats';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), // Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Umpire Statistics',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333), // Text Primary
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF757575)), // Text Secondary
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF757575)), // Text Secondary
            onPressed: _fetchStats,
            tooltip: 'Refresh Stats',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C9A8B), Color(0xFFC1DADB)], // Primary to Secondary
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF4A261))) // Accent
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(color: const Color(0xFFE76F51), fontSize: 16), // Error
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchStats,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C9A8B), // Primary
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Try Again',
                          style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildStatCard(
                        title: 'Total Matches Officiated',
                        value: _totalMatches.toString(),
                        icon: Icons.sports_tennis,
                        color: const Color(0xFFF4A261), // Accent
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        title: 'Tournaments Umpired',
                        value: _totalTournaments.toString(),
                        icon: Icons.emoji_events,
                        color: const Color(0xFFE9C46A), // Mood Booster
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        title: 'Completed Matches',
                        value: _completedMatches.toString(),
                        icon: Icons.check_circle,
                        color: const Color(0xFF2A9D8F), // Success
                      ),
                      const SizedBox(height: 16),
                      _buildStatCard(
                        title: 'Ongoing Matches',
                        value: _ongoingMatches.toString(),
                        icon: Icons.timer,
                        color: const Color(0xFFA8DADC), // Cool Blue Highlights
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: const Color(0xFFFFFFFF), // Surface
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      shadowColor: const Color(0xFF1D3557).withOpacity(0.2), // Deep Indigo
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF757575), // Text Secondary
                    fontSize: 14,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF333333), // Text Primary
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}