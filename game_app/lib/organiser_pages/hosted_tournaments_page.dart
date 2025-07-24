import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:game_app/models/tournament.dart';
import 'package:game_app/organiser_pages/edit_tournament_page.dart';
import 'package:game_app/tournaments/tournament_overview_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';

class HostedTournamentsPage extends StatelessWidget {
  final String userId;

  const HostedTournamentsPage({super.key, required this.userId});

  Future<void> _deleteTournament(String tournamentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting tournament: $e');
      rethrow;
    }
  }

  String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'Date not set';
    
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('MMM dd').format(start)} - ${DateFormat('dd, yyyy').format(end)}';
    } else if (start.year == end.year) {
      return '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}';
    }
    return '${DateFormat('MMM dd, yyyy').format(start)} - ${DateFormat('MMM dd, yyyy').format(end)}';
  }

  String _getTournamentStatus(Tournament tournament) {
    final now = DateTime.now();
    if (tournament.endDate == null) {
      return 'Date not set';
    }
    
    if (now.isBefore(tournament.startDate)) {
      return 'Upcoming';
    } else if (now.isAfter(tournament.startDate) && now.isBefore(tournament.endDate!)) {
      return 'Live';
    } else {
      return 'Completed';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Upcoming':
        return const Color(0xFFF4A261); // Accent
      case 'Live':
        return const Color(0xFF2A9D8F); // Success
      case 'Completed':
        return const Color(0xFF757575); // Text Secondary
      case 'Date not set':
        return const Color(0xFFE9C46A); // Mood Booster
      default:
        return const Color(0xFFFDFCFB); // Background
    }
  }

  void _showFullImageDialog(BuildContext context, String? imageUrl) {
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
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
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
                  color: const Color(0xFFFDFCFB), // Background
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), // Background
      appBar: AppBar(
        title: Text(
          'Hosted Tournaments',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333), // Text Primary
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF757575), // Text Secondary
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tournaments')
            .where('createdBy', isEqualTo: userId)
            .orderBy('startDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF4A261), // Accent
                strokeWidth: 2.5,
              ),
            );
          }

          if (snapshot.hasError) {
            debugPrint('Firestore Error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFE76F51), // Error
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error Loading Tournaments',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF333333), // Text Primary
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _getErrorMessage(snapshot.error),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF757575), // Text Secondary
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // This will automatically refresh the stream
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C9A8B), // Primary
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Try Again',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFDFCFB), // Background
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    size: 64,
                    color: const Color(0xFF757575), // Text Secondary
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tournaments hosted yet',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF333333), // Text Primary
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first tournament to get started',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF757575), // Text Secondary
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          try {
            final tournaments = snapshot.data!.docs.map((doc) {
              try {
                return Tournament.fromFirestore(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                );
              } catch (e) {
                debugPrint('Error parsing tournament ${doc.id}: $e');
                return null;
              }
            }).whereType<Tournament>().toList();

            if (tournaments.isEmpty) {
              return Center(
                child: Text(
                  'No valid tournaments found',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF333333), // Text Primary
                    fontSize: 16,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: tournaments.length,
              itemBuilder: (context, index) {
                final tournament = tournaments[index];
                final status = _getTournamentStatus(tournament);
                final statusColor = _getStatusColor(status);

                return _buildTournamentCard(context, tournament, status, statusColor);
              },
            );
          } catch (e) {
            debugPrint('Error building tournament list: $e');
            return Center(
              child: Text(
                'Error displaying tournaments',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF333333), // Text Primary
                  fontSize: 16,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to access tournaments';
        case 'unavailable':
          return 'Network is unavailable. Please check your connection';
        default:
          return 'Failed to load tournaments. Error: ${error.message}';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Widget _buildTournamentCard(
    BuildContext context,
    Tournament tournament,
    String status,
    Color statusColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFFFFF), // Surface
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D3557).withOpacity(0.2), // Deep Indigo
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tournament Header with Status and Image
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _showFullImageDialog(context, tournament.profileImage),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: tournament.profileImage != null && tournament.profileImage!.isNotEmpty
                          ? Image.network(
                              tournament.profileImage!,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  'ID: ${tournament.id.substring(0, 6).toUpperCase()}',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF757575), // Text Secondary
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Tournament Content
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TournamentOverviewPage(tournament: tournament),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tournament Name
                  Text(
                    tournament.name.isNotEmpty 
                        ? tournament.name 
                        : 'Unnamed Tournament',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF333333), // Text Primary
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Date Range
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: const Color(0xFF757575), // Text Secondary
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDateRange(tournament.startDate, tournament.endDate),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF333333), // Text Primary
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Venue and City
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: const Color(0xFF757575), // Text Secondary
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tournament.venue.isNotEmpty 
                                  ? tournament.venue 
                                  : 'Venue not specified',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF333333), // Text Primary
                              ),
                            ),
                            if (tournament.city.isNotEmpty)
                              Text(
                                tournament.city,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF757575), // Text Secondary
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Divider
                  Divider(
                    height: 1,
                    color: const Color(0xFFA8DADC).withOpacity(0.5), // Cool Blue Highlights
                  ),
                  const SizedBox(height: 12),
                 
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Entry Fee
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9C46A).withOpacity(0.1), // Mood Booster
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFE9C46A).withOpacity(0.3), // Mood Booster
                            width: 1,
                          ),
                        ),
                        child: Text(
                          tournament.entryFee == 0.0 
                              ? 'Free Entry' 
                              : 'Entry Fee: ₹${tournament.entryFee.toStringAsFixed(0)}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFE9C46A), // Mood Booster
                          ),
                        ),
                      ),
                      // Action Buttons
                      Row(
                        children: [
                          // Edit Button
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 20,
                              color: const Color(0xFF6C9A8B).withOpacity(0.8), // Primary
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EditTournamentPage(tournament: tournament),
                                ),
                              );
                            },
                            tooltip: 'Edit Tournament',
                          ),
                          // Delete Button
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: 20,
                              color: const Color(0xFFE76F51).withOpacity(0.8), // Error
                            ),
                            onPressed: () => _confirmDeleteTournament(context, tournament),
                            tooltip: 'Delete Tournament',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTournament(BuildContext context, Tournament tournament) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFFFFF), // Surface
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Confirm Deletion',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333), // Text Primary
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${tournament.name}"? This action cannot be undone.',
          style: GoogleFonts.poppins(
            color: const Color(0xFF757575), // Text Secondary
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF757575), // Text Secondary
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE76F51), // Error
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _deleteTournament(tournament.id);
        if (context.mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.success,
            title: Text(
              'Tournament Deleted',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: const Color(0xFFFDFCFB), // Background
              ),
            ),
            description: Text(
              '${tournament.name} has been successfully deleted',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFDFCFB), // Background
              ),
            ),
            style: ToastificationStyle.fillColored,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF2A9D8F), // Success
          );
        }
      } catch (e) {
        if (context.mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: Text(
              'Deletion Failed',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: const Color(0xFFFDFCFB), // Background
              ),
            ),
            description: Text(
              'Error deleting tournament: ${e.toString()}',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFDFCFB), // Background
              ),
            ),
            style: ToastificationStyle.fillColored,
            alignment: Alignment.bottomCenter,
            autoCloseDuration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFFE76F51), // Error
          );
        }
      }
    }
  }
}