import 'package:flutter/material.dart';
import 'package:game_app/models/tournament.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class TournamentCard extends StatelessWidget {
  final Tournament tournament;
  final String creatorName;
  final bool isCreator;
  final VoidCallback? onImageTap;

  const TournamentCard({
    super.key,
    required this.tournament,
    required this.creatorName,
    required this.isCreator,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = tournament.getStartTime();
    final participantsText = '${tournament.participants.length}/${tournament.maxParticipants}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator section at the top
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Created by $creatorName',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                if (isCreator)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Your Event',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Divider
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: Color(0xFFEEEEEE)),
          ),

          // Tournament image and details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onImageTap,
                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[100],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 12),
                Text(
                  tournament.name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  icon: Icons.sports_tennis,
                  text: 'Badminton • ${tournament.gameFormat}',
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  icon: Icons.location_on,
                  text: '${tournament.venue}, ${tournament.city}',
                ),
                const SizedBox(height: 6),
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  text: tournament.endDate != null
                      ? '${DateFormat('MMM dd, yyyy').format(tz.TZDateTime.from(tournament.startDate, tz.getLocation(tournament.timezone)))} - ${DateFormat('MMM dd, yyyy').format(tz.TZDateTime.from(tournament.endDate!, tz.getLocation(tournament.timezone)))} • ${startTime.format(context)} (${tournament.timezone})'
                      : '${DateFormat('MMM dd, yyyy').format(tz.TZDateTime.from(tournament.startDate, tz.getLocation(tournament.timezone)))} • ${startTime.format(context)} (${tournament.timezone})',
                ),
              ],
            ),
          ),

          // Participants section with accent color
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 178, 177, 177),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF757575)),
                    const SizedBox(width: 6),
                    Text(
                      'Participants',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    participantsText,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF616161),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}