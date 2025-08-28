// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:game/widgets/tournament_card.dart';
// import 'package:game/widgets/authmodal.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:shimmer/shimmer.dart';

// class ProfilePage extends StatefulWidget {
//   final User? user;

//   const ProfilePage({super.key, this.user});

//   @override
//   State<ProfilePage> createState() => _ProfilePageState();
// }

// class _ProfilePageState extends State<ProfilePage> {
//   bool _isLoading = false;
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

//   Future<void> _loadTournaments() async {
//     if (!_hasMore || _isLoading || widget.user == null) return;

//     setState(() => _isLoading = true);

//     try {
//       final startTime = DateTime.now();

//       Query<Map<String, dynamic>> query = _firestore
//           .collection('tournaments')
//           .where('createdBy', isEqualTo: widget.user!.uid)
//           .orderBy('eventDate')
//           .limit(10);

//       if (_lastDocument != null) {
//         query = query.startAfterDocument(_lastDocument!);
//       }

//       final snapshot = await query.get(const GetOptions(source: Source.cache));
//       final endTime = DateTime.now();
//       debugPrint('My tournaments query took: ${endTime.difference(startTime).inMilliseconds}ms');

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
//       debugPrint('Error loading my tournaments: $e');
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
//           setState(() {
//             _tournaments.clear();
//             _lastDocument = null;
//             _hasMore = true;
//             _initialLoad = true;
//             _loadTournaments();
//           });
//         },
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Profile',
//           style: GoogleFonts.roboto(
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF4361EE),
//       ),
//       body: CustomScrollView(
//         physics: const BouncingScrollPhysics(),
//         slivers: [
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.all(24.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'User Information',
//                     style: GoogleFonts.roboto(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.grey.shade800,
//                     ),
//                   ),
//                   const SizedBox(height: 16),
//                   Card(
//                     elevation: 2,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'Email',
//                             style: GoogleFonts.roboto(
//                               fontSize: 16,
//                               fontWeight: FontWeight.w600,
//                               color: Colors.grey.shade600,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             widget.user?.email ?? 'Guest',
//                             style: GoogleFonts.roboto(
//                               fontSize: 16,
//                               color: Colors.grey.shade800,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   if (widget.user == null)
//                     Padding(
//                       padding: const EdgeInsets.only(top: 16),
//                       child: ElevatedButton(
//                         onPressed: () => _showAuthModal(false),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFF4361EE),
//                           foregroundColor: Colors.white,
//                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                         child: Text(
//                           'Sign In to View Your Tournaments',
//                           style: GoogleFonts.roboto(
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ),
//                   if (widget.user != null) ...[
//                     const SizedBox(height: 32),
//                     Text(
//                       'My Tournaments',
//                       style: GoogleFonts.roboto(
//                         fontSize: 20,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.grey.shade800,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//           if (widget.user != null)
//             if (_initialLoad && _tournaments.isEmpty)
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 24),
//                   child: Column(
//                     children: List.generate(
//                       3,
//                       (index) => Padding(
//                         padding: const EdgeInsets.only(bottom: 16),
//                         child: Shimmer.fromColors(
//                           baseColor: Colors.grey.shade200,
//                           highlightColor: Colors.grey.shade100,
//                           child: Container(
//                             height: 120,
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//           if (widget.user != null && _tournaments.isNotEmpty)
//             SliverPadding(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               sliver: SliverList(
//                 delegate: SliverChildBuilderDelegate(
//                   (context, index) {
//                     if (index == _tournaments.length) {
//                       if (_hasMore) {
//                         _loadTournaments();
//                         return const Padding(
//                           padding: EdgeInsets.symmetric(vertical: 16),
//                           child: Center(
//                             child: CircularProgressIndicator(
//                               color: Color(0xFF4361EE),
//                             ),
//                           ),
//                         );
//                       }
//                       return const SizedBox.shrink();
//                     }

//                     final tournament = _tournaments[index];
//                     final data = tournament.data() as Map<String, dynamic>;
//                     final date = data['eventDate']?.toDate() as DateTime?;

//                     return Padding(
//                       padding: const EdgeInsets.only(bottom: 16),
//                       child: TournamentCard(
//                         name: data['name'] ?? 'Tournament',
//                         location: data['location'] ?? 'Unknown',
//                         date: date,
//                         entryFee: data['entryFee'] ?? 'Free',
//                         participants: (data['participants'] as List?)?.length ?? 0,
//                       ),
//                     );
//                   },
//                   childCount: _tournaments.length + (_hasMore ? 1 : 0),
//                 ),
//               ),
//             ),
//           if (widget.user != null && !_initialLoad && _tournaments.isEmpty)
//             SliverToBoxAdapter(
//               child: Padding(
//                 padding: const EdgeInsets.all(24),
//                 child: Column(
//                   children: [
//                     Icon(
//                       Icons.event_busy,
//                       size: 60,
//                       color: Colors.grey.shade300,
//                     ),
//                     const SizedBox(height: 16),
//                     Text(
//                       'No tournaments created',
//                       style: GoogleFonts.roboto(
//                         fontSize: 16,
//                         color: Colors.grey.shade600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }