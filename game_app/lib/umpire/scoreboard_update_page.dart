// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:toastification/toastification.dart';

// class ScoreboardUpdatePage extends StatefulWidget {
//   final String tournamentId;
//   final String matchId;

//   const ScoreboardUpdatePage({
//     super.key,
//     required this.tournamentId,
//     required this.matchId,
//   });

//   @override
//   State<ScoreboardUpdatePage> createState() => _ScoreboardUpdatePageState();
// }

// class _ScoreboardUpdatePageState extends State<ScoreboardUpdatePage> {
//   int _team1Score = 0;
//   int _team2Score = 0;

//   Future<void> _updateScore() async {
//     try {
//       await FirebaseFirestore.instance
//           .collection('tournaments')
//           .doc(widget.tournamentId)
//           .collection('liveScores')
//           .doc('currentMatch')
//           .set({
//             'team1Score': _team1Score,
//             'team2Score': _team2Score,
//             'lastUpdated': FieldValue.serverTimestamp(),
//           });

//       toastification.show(
//         context: context,
//         type: ToastificationType.success,
//         title: const Text('Score Updated'),
//         description: const Text('The scoreboard has been updated.'),
//         autoCloseDuration: const Duration(seconds: 3),
//         backgroundColor: Colors.green,
//         foregroundColor: Colors.white,
//         alignment: Alignment.bottomCenter,
//       );
//     } catch (e) {
//       toastification.show(
//         context: context,
//         type: ToastificationType.error,
//         title: const Text('Update Failed'),
//         description: Text('Error updating score: $e'),
//         autoCloseDuration: const Duration(seconds: 5),
//         backgroundColor: Colors.red,
//         foregroundColor: Colors.white,
//         alignment: Alignment.bottomCenter,
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF1B263B),
//       appBar: AppBar(
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         title: Text(
//           'Update Scoreboard',
//           style: GoogleFonts.poppins(
//             fontSize: 20,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
//         child: Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Column(
//                   children: [
//                     Text(
//                       'Team 1',
//                       style: GoogleFonts.poppins(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w500,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       '$_team1Score',
//                       style: GoogleFonts.poppins(
//                         fontSize: 32,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     Row(
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.remove, color: Colors.white),
//                           onPressed: () {
//                             setState(() {
//                               if (_team1Score > 0) _team1Score--;
//                             });
//                           },
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.add, color: Colors.white),
//                           onPressed: () {
//                             setState(() {
//                               _team1Score++;
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 Column(
//                   children: [
//                     Text(
//                       'Team 2',
//                       style: GoogleFonts.poppins(
//                         fontSize: 18,
//                         fontWeight: FontWeight.w500,
//                         color: Colors.white,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       '$_team2Score',
//                       style: GoogleFonts.poppins(
//                         fontSize: 32,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.white,
//                       ),
//                     ),
//                     Row(
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.remove, color: Colors.white),
//                           onPressed: () {
//                             setState(() {
//                               if (_team2Score > 0) _team2Score--;
//                             });
//                           },
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.add, color: Colors.white),
//                           onPressed: () {
//                             setState(() {
//                               _team2Score++;
//                             });
//                           },
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//             const SizedBox(height: 40),
//             ElevatedButton(
//               onPressed: _updateScore,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blueGrey[700],
//                 padding: const EdgeInsets.symmetric(
//                   vertical: 16,
//                   horizontal: 32,
//                 ),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: Text(
//                 'Update Score',
//                 style: GoogleFonts.poppins(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
