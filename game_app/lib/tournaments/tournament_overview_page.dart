// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:game_app/models/tournament.dart';
// import 'package:game_app/organiser_pages/edit_tournament_page.dart'; // Ensure this import matches your file structure
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';

// class TournamentOverviewPage extends StatelessWidget {
//   final Tournament tournament;

//   const TournamentOverviewPage({super.key, required this.tournament});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0D1B2A),
//       appBar: AppBar(
//         title: Text(
//           tournament.name,
//           style: GoogleFonts.poppins(
//             color: Colors.white,
//             fontWeight: FontWeight.w600,
//             fontSize: 24,
//           ),
//         ),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         actions: [
         
//           IconButton(
//             icon: const Icon(Icons.delete, color: Colors.white),
//             onPressed: () => _showDeleteConfirmation(context),
//           ),
//         ],
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Color(0xFF1B263B), Color(0xFF0D1B2A)],
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Card(
//             color: const Color(0xFF2E4057).withOpacity(0.9),
//             elevation: 8,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             child: Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildDetailRow('Tournament Name', tournament.name),
//                   _buildDivider(),
//                   _buildDetailRow('Venue', tournament.venue),
//                   _buildDivider(),
//                   _buildDetailRow('City', tournament.city),
//                   _buildDivider(),
//                   _buildDetailRow(
//                     'Date',
//                     '${DateFormat('dd/MM/yyyy').format(tournament.startDate)} ${tournament.startTime.format(context)} IST',
//                   ),
//                   _buildDivider(),
//                   _buildDetailRow('End Date', tournament.endDate != null
//                       ? DateFormat('dd/MM/yyyy').format(tournament.endDate!)
//                       : 'Not set'),
//                   _buildDivider(),
//                   _buildDetailRow('Entry Fee', '\$${tournament.entryFee.toStringAsFixed(2)}'),
//                   _buildDivider(),
//                   _buildDetailRow('Game Format', tournament.gameFormat),
//                   _buildDivider(),
//                   _buildDetailRow('Game Type', tournament.gameType),
//                   _buildDivider(),
//                   _buildDetailRow('Max Participants', tournament.maxParticipants.toString()),
//                   _buildDivider(),
//                   _buildDetailRow('Participants', tournament.participants.length.toString()),
//                   _buildDivider(),
//                   _buildDetailRow('Bring Own Equipment', tournament.bringOwnEquipment ? 'Yes' : 'No'),
//                   _buildDivider(),
//                   _buildDetailRow('Cost Shared', tournament.costShared ? 'Yes' : 'No'),
//                   const SizedBox(height: 20),
//                   Center(
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF4E6BFF),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                       ),
//                       onPressed: () {
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(
//                             builder: (context) => EditTournamentPage(tournament: tournament),
//                           ),
//                         );
//                       },
//                       child: Text(
//                         'Edit Tournament',
//                         style: GoogleFonts.poppins(
//                           color: Colors.white,
//                           fontWeight: FontWeight.w500,
//                           fontSize: 16,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             label,
//             style: GoogleFonts.poppins(
//               color: Colors.white70,
//               fontWeight: FontWeight.w500,
//               fontSize: 16,
//             ),
//           ),
//           Text(
//             value,
//             style: GoogleFonts.poppins(
//               color: Colors.white,
//               fontWeight: FontWeight.w400,
//               fontSize: 16,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildDivider() {
//     return Divider(
//       color: Colors.white24,
//       thickness: 0.5,
//       height: 1,
//     );
//   }

//   void _showDeleteConfirmation(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: const Color(0xFF2E4057),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         title: Text(
//           'Confirm Delete',
//           style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
//         ),
//         content: Text(
//           'Are you sure you want to delete "${tournament.name}"?',
//           style: GoogleFonts.poppins(color: Colors.white70),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text(
//               'Cancel',
//               style: GoogleFonts.poppins(color: const Color(0xFF4E6BFF)),
//             ),
//           ),
//           TextButton(
//             onPressed: () async {
//               try {
//                 await FirebaseFirestore.instance
//                     .collection('tournaments')
//                     .doc(tournament.id)
//                     .delete();
//                 Navigator.pop(context); // Close dialog
//                 Navigator.pop(context); // Return to previous screen
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       '"${tournament.name}" has been deleted.',
//                       style: GoogleFonts.poppins(color: Colors.white),
//                     ),
//                     backgroundColor: Colors.redAccent,
//                   ),
//                 );
//               } catch (e) {
//                 Navigator.pop(context); // Close dialog
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text(
//                       'Failed to delete "${tournament.name}": $e',
//                       style: GoogleFonts.poppins(color: Colors.white),
//                     ),
//                     backgroundColor: Colors.redAccent,
//                   ),
//                 );
//               }
//             },
//             child: Text(
//               'Delete',
//               style: GoogleFonts.poppins(color: Colors.redAccent),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }