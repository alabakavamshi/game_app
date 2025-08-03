// import 'package:flutter/material.dart';
// import 'package:game_app/models/tournament.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';

// class TournamentInfoPage extends StatelessWidget {
//   final Tournament tournament;
//   final String creatorName;
//   final List<Map<String, dynamic>> participantDetails;

//   static const String _defaultBadmintonRules = '''
// 1. Matches are best of 3 games, each played to 21 points with a 2-point lead required to win.
// 2. A rally point system is used; a point is scored on every serve.
// 3. Players change sides after each game and at 11 points in the third game.
// 4. A 60-second break is allowed between games, and a 120-second break at 11 points in a game.
// 5. Service must be diagonal, below the waist, and the shuttle must land within the opponent's court.
// 6. Faults include: shuttle landing out of bounds, double hits, or player touching the net.
// 7. Respect the umpire's decisions and maintain sportsmanship at all times.
// ''';

//   const TournamentInfoPage({
//     super.key,
//     required this.tournament,
//     required this.creatorName,
//     required this.participantDetails,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.transparent,
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF0A1325), Color(0xFF1A2A44)],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         child: SafeArea(
//           child: CustomScrollView(
//             slivers: [
//               SliverAppBar(
//                 backgroundColor: Colors.transparent,
//                 elevation: 0,
//                 pinned: true,
//                 leading: IconButton(
//                   icon: const Icon(Icons.arrow_back, color: Colors.white70),
//                   onPressed: () => Navigator.pop(context),
//                 ),
//                 title: Text(
//                   'Tournament Info',
//                   style: GoogleFonts.poppins(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//               ),
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Tournament Info',
//                         style: GoogleFonts.poppins(
//                           fontSize: 24,
//                           fontWeight: FontWeight.w700,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       _buildDetailSection(
//                         title: 'Tournament Details',
//                         children: [
//                           _buildDetailRow(
//                             icon: Icons.sports_tennis,
//                             label: 'Play Style',
//                             value: tournament.gameFormat,
//                           ),
//                           _buildDetailRow(
//                             icon: Icons.location_on,
//                             label: 'Venue',
//                             value: (tournament.venue.isNotEmpty && tournament.city.isNotEmpty)
//                                 ? '${tournament.venue}, ${tournament.city}'
//                                 : 'No Location',
//                           ),
//                           _buildDetailRow(
//                             icon: Icons.calendar_today,
//                             label: 'Date',
//                             value: _formatDateRange(tournament.startDate, tournament.endDate),
//                           ),
//                           _buildDetailRow(
//                             icon: Icons.account_balance_wallet,
//                             label: 'Entry Fee',
//                             value: tournament.entryFee == 0.0
//                                 ? 'Free'
//                                 : '₹${tournament.entryFee.toStringAsFixed(0)}',
//                           ),
//                           _buildDetailRow(
//                             icon: Icons.people,
//                             label: 'Max Participants',
//                             value: '${tournament.maxParticipants}',
//                           ),
//                           _buildDetailRow(
//                             icon: Icons.person,
//                             label: 'Created By',
//                             value: creatorName,
//                           ),
//                           _buildDetailRow(
//                             icon: Icons.description,
//                             label: 'Game Type',
//                             value: tournament.gameType,
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 20),
//                       _buildDetailSection(
//                         title: 'Participants Details',
//                         children: [
//                           if (participantDetails.isEmpty)
//                             Text(
//                               'No participants yet.',
//                               style: GoogleFonts.poppins(
//                                 fontSize: 14,
//                                 color: Colors.white70,
//                               ),
//                             ),
//                           ...participantDetails.asMap().entries.map((entry) {
//                             final index = entry.key;
//                             final details = entry.value;
//                             final gender = details['gender']?.toString() ?? '';
//                             final capitalizedGender = gender.isNotEmpty
//                                 ? '${gender[0].toUpperCase()}${gender.substring(1).toLowerCase()}'
//                                 : '';
                            
//                             return Padding(
//                               padding: const EdgeInsets.symmetric(vertical: 8),
//                               child: Row(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     'Participant ${index + 1}: ',
//                                     style: GoogleFonts.poppins(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                       color: Colors.white70,
//                                     ),
//                                   ),
//                                   Expanded(
//                                     child: Column(
//                                       crossAxisAlignment: CrossAxisAlignment.start,
//                                       children: [
//                                         RichText(
//                                           text: TextSpan(
//                                             children: [
//                                               TextSpan(
//                                                 text: '${details['firstName']} ${details['lastName']}',
//                                                 style: GoogleFonts.poppins(
//                                                   fontSize: 14,
//                                                   color: Colors.white,
//                                                   fontWeight: FontWeight.w600,
//                                                 ),
//                                               ),
//                                               if (gender.isNotEmpty)
//                                                 TextSpan(
//                                                   text: ' ($capitalizedGender)',
//                                                   style: GoogleFonts.poppins(
//                                                     fontSize: 12,
//                                                     color: Colors.cyanAccent,
//                                                     fontStyle: FontStyle.italic,
//                                                   ),
//                                                 ),
//                                             ],
//                                           ),
//                                         ),
//                                         const SizedBox(height: 4),
//                                         Text(
//                                           'Phone: ${details['phone']}',
//                                           style: GoogleFonts.poppins(
//                                             fontSize: 14,
//                                             color: Colors.white70,
//                                           ),
//                                         ),
//                                         Text(
//                                           'Email: ${details['email']}',
//                                           style: GoogleFonts.poppins(
//                                             fontSize: 14,
//                                             color: Colors.white70,
//                                           ),
//                                         ),
//                                       ],
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           }),
//                         ],
//                       ),
//                       const SizedBox(height: 20),
//                       _buildDetailSection(
//                         title: 'Rules',
//                         children: [
//                           Text(
//                             tournament.rules ?? _defaultBadmintonRules,
//                             style: GoogleFonts.poppins(
//                               fontSize: 14,
//                               color: Colors.white70,
//                               height: 1.6,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 30),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailSection({
//     required String title,
//     required List<Widget> children,
//   }) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.white.withOpacity(0.1)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.2),
//             blurRadius: 3,
//             spreadRadius: 1,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: GoogleFonts.poppins(
//               fontSize: 18,
//               fontWeight: FontWeight.w600,
//               color: Colors.white,
//               letterSpacing: 0.5,
//             ),
//           ),
//           const SizedBox(height: 12),
//           ...children,
//         ],
//       ),
//     );
//   }

//   Widget _buildDetailRow({
//     required IconData icon,
//     required String label,
//     required String value,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         children: [
//           Icon(icon, color: Colors.cyanAccent, size: 18),
//           const SizedBox(width: 10),
//           Text(
//             '$label: ',
//             style: GoogleFonts.poppins(
//               fontSize: 14,
//               color: Colors.white70,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: GoogleFonts.poppins(
//                 fontSize: 14,
//                 color: Colors.white,
//                 fontWeight: FontWeight.w400,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _formatDateRange(DateTime startDate, DateTime? endDate) {
//     if (endDate == null) {
//       return DateFormat('MMM dd, yyyy').format(startDate);
//     }
//     final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
//     final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
//     if (startDateOnly == endDateOnly) {
//       return DateFormat('MMM dd, yyyy').format(startDate);
//     }
//     if (startDate.year == endDate.year) {
//       return '${DateFormat('MMM dd').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}';
//     }
//     return '${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}';
//   }
// }

// extension StringExtension on String {
//   String capitalize() {
//     if (isEmpty) return this;
//     return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
//   }
// }