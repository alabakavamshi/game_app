// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:game/widgets/tournament_card.dart';
// import 'package:game/widgets/authmodal.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shimmer/shimmer.dart';

// class TournamentsPage extends StatefulWidget {
//   const TournamentsPage({super.key});

//   @override
//   State<TournamentsPage> createState() => _TournamentsPageState();
// }

// class _TournamentsPageState extends State<TournamentsPage> {
//   String _error = '';
//   bool _isLoading = false;
//   final TextEditingController _searchController = TextEditingController();
//   final _firestore = FirebaseFirestore.instance;
//   DocumentSnapshot? _lastDocument;
//   bool _hasMore = true;
//   final List<DocumentSnapshot> _tournaments = [];
//   bool _initialLoad = true;

//   @override
//   void initState() {
//     super.initState();
//     _firestore.settings = const Settings(
//       persistenceEnabled: true,
//       cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
//     );
//     _loadTournaments();
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadTournaments() async {
//     if (!_hasMore || _isLoading) return;

//     setState(() => _isLoading = true);

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       final startTime = DateTime.now();

//       Query<Map<String, dynamic>> query = _firestore
//           .collection('tournaments')
//           .where('status', isEqualTo: 'open')
//           .where('createdBy', isNotEqualTo: user?.uid ?? '')
//           .orderBy('createdBy') // Required for isNotEqualTo
//           .orderBy('eventDate')
//           .limit(10);

//       if (_lastDocument != null) {
//         query = query.startAfterDocument(_lastDocument!);
//       }

//       final snapshot = await query.get(const GetOptions(source: Source.cache));
//       final endTime = DateTime.now();
//       debugPrint('Tournaments query took: ${endTime.difference(startTime).inMilliseconds}ms');

//       if (snapshot.docs.isEmpty) {
//         setState(() => _hasMore = false);
//       } else {
//         _lastDocument = snapshot.docs.last;
//         setState(() {
//           _tournaments.addAll(snapshot.docs);
//           _initialLoad = false;
//         });
//       }
//     } catch (e) {
//       debugPrint('Error loading tournaments: $e');
//       setState(() => _error = 'Failed to load tournaments');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _joinTournament(String tournamentId, String tournamentName) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) {
//       _showAuthModal(false);
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       final tournamentRef = _firestore.collection('tournaments').doc(tournamentId);
//       final tournamentDoc = await tournamentRef.get();
//       if (!tournamentDoc.exists || tournamentDoc.data()!['status'] != 'open') {
//         throw Exception('Tournament is closed or does not exist');
//       }
//       if ((tournamentDoc.data()!['participants'] as List).contains(user.uid)) {
//         throw Exception('Already joined this tournament');
//       }
//       await tournamentRef.update({
//         'participants': FieldValue.arrayUnion([user.uid]),
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Successfully joined $tournamentName'),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       );
//     } catch (e) {
//       setState(() => _error = 'Error joining tournament: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _showAuthModal(bool isSignup) {
//     showDialog(
//       context: context,
//       builder: (context) => AuthModal(
//         isSignup: isSignup,
//         onAuthSuccess: () {
//           Navigator.pop(context);
//           setState(() {});
//         },
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Tournaments',
//           style: GoogleFonts.roboto(
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF4361EE),
//       ),
//       body: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: TextFormField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 hintText: 'Search tournaments...',
//                 prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 filled: true,
//                 fillColor: Colors.grey.shade50,
//               ),
//               style: GoogleFonts.roboto(),
//               onChanged: (value) => setState(() {}),
//             ),
//           ),
//           if (_error.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Text(
//                 _error,
//                 style: GoogleFonts.roboto(color: Colors.red, fontSize: 14),
//               ),
//             ),
//           Expanded(
//             child: _buildTournamentList(),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTournamentList() {
//     if (_initialLoad && _tournaments.isEmpty) {
//       return ListView(
//         padding: const EdgeInsets.symmetric(horizontal: 24),
//         children: List.generate(
//           3,
//           (index) => Padding(
//             padding: const EdgeInsets.only(bottom: 16),
//             child: Shimmer.fromColors(
//               baseColor: Colors.grey.shade200,
//               highlightColor: Colors.grey.shade100,
//               child: Container(
//                 height: 120,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//     }

//     final filteredTournaments = _tournaments.where((doc) {
//       final data = doc.data() as Map<String, dynamic>;
//       final name = data['name']?.toString().toLowerCase() ?? '';
//       final searchQuery = _searchController.text.toLowerCase();
//       return name.contains(searchQuery);
//     }).toList();

//     if (filteredTournaments.isEmpty && !_initialLoad) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(
//               Icons.event_busy,
//               size: 60,
//               color: Colors.grey.shade300,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'No tournaments found',
//               style: GoogleFonts.roboto(
//                 fontSize: 16,
//                 color: Colors.grey.shade600,
//               ),
//             ),
//           ],
//         ),
//       );
//     }

//     return ListView.builder(
//       padding: const EdgeInsets.symmetric(horizontal: 24),
//       physics: const BouncingScrollPhysics(),
//       itemCount: filteredTournaments.length + (_hasMore ? 1 : 0),
//       itemBuilder: (context, index) {
//         if (index == filteredTournaments.length) {
//           if (_hasMore) {
//             _loadTournaments();
//             return const Padding(
//               padding: EdgeInsets.symmetric(vertical: 16),
//               child: Center(
//                 child: CircularProgressIndicator(
//                   color: Color(0xFF4361EE),
//                 ),
//               ),
//             );
//           }
//           return const SizedBox.shrink();
//         }

//         final tournament = filteredTournaments[index];
//         final data = tournament.data() as Map<String, dynamic>;
//         final date = data['eventDate']?.toDate() as DateTime?;
//         final isJoined = (data['participants'] as List?)?.contains(FirebaseAuth.instance.currentUser?.uid) ?? false;

//         return Padding(
//           padding: const EdgeInsets.only(bottom: 16),
//           child: TournamentCard(
//             name: data['name'] ?? 'Tournament',
//             location: data['location'] ?? 'Unknown',
//             date: date,
//             entryFee: data['entryFee'] ?? 'Free',
//             participants: (data['participants'] as List?)?.length ?? 0,
//             isJoined: isJoined,
//             isLoading: _isLoading,
//             onJoin: () => _joinTournament(tournament.id, data['name']),
//           ),
//         );
//       },
//     );
//   }
// }