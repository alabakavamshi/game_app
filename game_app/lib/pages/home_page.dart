// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:game/pages/profile_page.dart';
// import 'package:game/widgets/tournament_card.dart';
// import 'package:game/pages/tournaments_page.dart';
// import 'package:game/widgets/authmodal.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
// import 'package:shimmer/shimmer.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({super.key});

//   @override
//   State<HomePage> createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   int _selectedIndex = 0;

//   void _onItemTapped(int index) {
//     setState(() => _selectedIndex = index);
//     debugPrint('Selected index: $_selectedIndex');
//   }

//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           debugPrint('Auth state: Waiting');
//           return const Center(
//             child: CircularProgressIndicator(
//               color: Color(0xFF4361EE),
//             ),
//           );
//         }

//         final user = snapshot.data;
//         debugPrint('Auth state changed: User ${user?.uid ?? "null"}');

//         final pages = [
//           HomeContent(user: user),
//           const TournamentsPage(),
//           ProfilePage(user: user),
//         ];

//         return Scaffold(
//           body: CustomScrollView(
//             slivers: [
//               _buildAppBar(user),
//               SliverFillRemaining(
//                 child: pages[_selectedIndex],
//               ),
//             ],
//           ),
//           bottomNavigationBar: _buildBottomNavBar(),
//         );
//       },
//     );
//   }

//   SliverAppBar _buildAppBar(User? user) {
//     debugPrint('Building AppBar, user: ${user?.uid ?? "null"}');
//     return SliverAppBar(
//       expandedHeight: MediaQuery.of(context).size.height * 0.25,
//       floating: false,
//       pinned: true,
//       backgroundColor: const Color(0xFF4361EE),
//       flexibleSpace: FlexibleSpaceBar(
//         title: Text(
//           'Badminton Blitz',
//           style: GoogleFonts.roboto(
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//             fontSize: 22,
//           ),
//         ),
//         centerTitle: true,
//         background: Image.asset(
//           'assets/images.png',
//           fit: BoxFit.cover,
//           color: Colors.black.withOpacity(0.3),
//           colorBlendMode: BlendMode.darken,
//           errorBuilder: (context, error, stackTrace) => Container(
//             color: Colors.grey.shade300,
//           ),
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () {
//             debugPrint('Sign In/Logout button pressed, user: ${user?.uid ?? "null"}');
//             user == null ? _showAuthModal(false) : _signOut();
//           },
//           child: Text(
//             user == null ? 'Sign In' : 'Logout',
//             style: GoogleFonts.roboto(
//               color: Colors.white,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//       ],
//     );
//   }

//   Widget _buildBottomNavBar() {
//     return Container(
//       decoration: BoxDecoration(
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 10,
//             spreadRadius: 2,
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//         child: BottomNavigationBar(
//           items: const [
//             BottomNavigationBarItem(
//               icon: Icon(Icons.home_outlined),
//               activeIcon: Icon(Icons.home),
//               label: 'Home',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.event_outlined),
//               activeIcon: Icon(Icons.event),
//               label: 'Tournaments',
//             ),
//             BottomNavigationBarItem(
//               icon: Icon(Icons.person_outlined),
//               activeIcon: Icon(Icons.person),
//               label: 'Profile',
//             ),
//           ],
//           currentIndex: _selectedIndex,
//           selectedItemColor: const Color(0xFF4361EE),
//           unselectedItemColor: Colors.grey.shade600,
//           onTap: _onItemTapped,
//           type: BottomNavigationBarType.fixed,
//           backgroundColor: Colors.white,
//           elevation: 0,
//           showSelectedLabels: true,
//           showUnselectedLabels: true,
//           selectedLabelStyle: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w500),
//           unselectedLabelStyle: GoogleFonts.roboto(fontSize: 12),
//         ),
//       ),
//     );
//   }

//   void _showAuthModal(bool isSignup) {
//     debugPrint('Showing auth modal, isSignup: $isSignup');
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

//   Future<void> _signOut() async {
//     try {
//       debugPrint('Attempting sign out');
//       await FirebaseAuth.instance.signOut();
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Logged out successfully'),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//       setState(() {});
//     } catch (e) {
//       debugPrint('Sign out error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error logging out: $e'),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );
//     }
//   }
// }

// class HomeContent extends StatefulWidget {
//   final User? user;

//   const HomeContent({super.key, this.user});

//   @override
//   State<HomeContent> createState() => _HomeContentState();
// }

// class _HomeContentState extends State<HomeContent> {
//   final _formKey = GlobalKey<FormState>();
//   String _tournamentName = '';
//   String _location = '';
//   DateTime? _eventDate;
//   String _entryFee = '';
//   bool _isLoading = false;
//   String _error = '';
//   final _firestore = FirebaseFirestore.instance;
//   DocumentSnapshot? _lastDocument;
//   bool _hasMore = true;
//   final List<DocumentSnapshot> _tournaments = [];
//   bool _initialLoad = true;
//   final ScrollController _scrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     _scrollController.addListener(() {
//       if (_scrollController.position.extentAfter < 500 && !_isLoading && _hasMore) {
//         _loadTournaments();
//       }
//     });
//     _loadTournaments();
//   }

//   @override
//   void dispose() {
//     _scrollController.dispose();
//     super.dispose();
//   }

//   Future<void> _loadTournaments() async {
//     if (!_hasMore || _isLoading || !mounted) return;

//     setState(() => _isLoading = true);

//     try {
//       final startTime = DateTime.now();

//       _firestore.settings = const Settings(
//         persistenceEnabled: true,
//         cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
//       );

//       Query<Map<String, dynamic>> query = _firestore
//           .collection('tournaments')
//           .where('status', isEqualTo: 'open')
//           .orderBy('eventDate')
//           .limit(5);

//       if (_lastDocument != null) {
//         query = query.startAfterDocument(_lastDocument!);
//       }

//       var snapshot = await query.get(const GetOptions(source: Source.cache));
//       if (snapshot.docs.isEmpty && mounted) {
//         snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
//       }

//       final endTime = DateTime.now();
//       debugPrint('Home tournament query took: ${endTime.difference(startTime).inMilliseconds}ms');

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
//       String errorMessage = 'Failed to load tournaments';
//       if (e.toString().contains('PERMISSION_DENIED')) {
//         errorMessage = 'Firestore access denied. Please enable Firestore API.';
//       }
//       setState(() => _error = errorMessage);
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _createTournament() async {
//     if (!_formKey.currentState!.validate()) return;
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       await _firestore.collection('tournaments').add({
//         'name': _tournamentName,
//         'location': _location,
//         'eventDate': Timestamp.fromDate(_eventDate!),
//         'entryFee': _entryFee,
//         'createdBy': widget.user!.uid,
//         'participants': [widget.user!.uid],
//         'status': 'open',
//         'createdAt': FieldValue.serverTimestamp(),
//       });
//       if (mounted) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Tournament created successfully'),
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(10),
//             ),
//           ),
//         );
//         setState(() {
//           _tournaments.clear();
//           _lastDocument = null;
//           _hasMore = true;
//           _initialLoad = true;
//         });
//         _loadTournaments();
//       }
//     } catch (e) {
//       debugPrint('Error creating tournament: $e');
//       setState(() => _error = 'Error creating tournament: $e');
//     } finally {
//       if (mounted) setState(() => _isLoading = false);
//     }
//   }

//   void _showCreateTournamentDialog() {
//     if (widget.user == null) {
//       _showAuthModal(false);
//       return;
//     }
//     showDialog(
//       context: context,
//       builder: (context) => Dialog(
//         insetPadding: const EdgeInsets.all(20),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         elevation: 0,
//         backgroundColor: Colors.transparent,
//         child: Container(
//           padding: const EdgeInsets.all(24),
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.1),
//                 blurRadius: 10,
//                 spreadRadius: 2,
//               ),
//             ],
//           ),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   'Create Tournament',
//                   style: GoogleFonts.roboto(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: const Color(0xFF4361EE),
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//                 TextFormField(
//                   decoration: InputDecoration(
//                     labelText: 'Tournament Name',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     filled: true,
//                     fillColor: Colors.grey.shade50,
//                     prefixIcon: Icon(Icons.event, color: Colors.grey.shade600),
//                   ),
//                   validator: (value) => value!.isEmpty ? 'Required' : null,
//                   onChanged: (value) => _tournamentName = value,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   decoration: InputDecoration(
//                     labelText: 'Location',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     filled: true,
//                     fillColor: Colors.grey.shade50,
//                     prefixIcon: Icon(Icons.location_on, color: Colors.grey.shade600),
//                   ),
//                   validator: (value) => value!.isEmpty ? 'Required' : null,
//                   onChanged: (value) => _location = value,
//                 ),
//                 const SizedBox(height: 16),
//                 TextFormField(
//                   decoration: InputDecoration(
//                     labelText: 'Entry Fee',
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     filled: true,
//                     fillColor: Colors.grey.shade50,
//                     prefixText: '₹ ',
//                     prefixIcon: Icon(Icons.attach_money, color: Colors.grey.shade600),
//                   ),
//                   keyboardType: TextInputType.number,
//                   validator: (value) => value!.isEmpty ? 'Required' : null,
//                   onChanged: (value) => _entryFee = value,
//                 ),
//                 const SizedBox(height: 16),
//                 InkWell(
//                   onTap: () async {
//                     final date = await showDatePicker(
//                       context: context,
//                       initialDate: DateTime.now().add(const Duration(days: 1)),
//                       firstDate: DateTime.now(),
//                       lastDate: DateTime(2026),
//                       builder: (context, child) => Theme(
//                         data: Theme.of(context).copyWith(
//                           colorScheme: const ColorScheme.light(
//                             primary: Color(0xFF4361EE),
//                           ),
//                         ),
//                         child: child!,
//                       ),
//                     );
//                     if (date != null) setState(() => _eventDate = date);
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(16),
//                     decoration: BoxDecoration(
//                       border: Border.all(color: Colors.grey.shade300),
//                       borderRadius: BorderRadius.circular(12),
//                       color: Colors.grey.shade50,
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(Icons.calendar_today, color: Colors.grey.shade600),
//                         const SizedBox(width: 16),
//                         Text(
//                           _eventDate == null
//                               ? 'Select Date'
//                               : DateFormat('MMM dd, yyyy').format(_eventDate!),
//                           style: GoogleFonts.roboto(color: Colors.grey.shade800),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//                 if (_error.isNotEmpty)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 16),
//                     child: Text(
//                       _error,
//                       style: GoogleFonts.roboto(color: Colors.red, fontSize: 14),
//                     ),
//                   ),
//                 const SizedBox(height: 24),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     TextButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: Text(
//                         'Cancel',
//                         style: GoogleFonts.roboto(
//                           color: Colors.grey.shade600,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     ElevatedButton(
//                       onPressed: _isLoading ? null : _createTournament,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF4361EE),
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                       ),
//                       child: _isLoading
//                           ? const SizedBox(
//                               width: 20,
//                               height: 20,
//                               child: CircularProgressIndicator(
//                                 strokeWidth: 2,
//                                 color: Colors.white,
//                               ),
//                             )
//                           : Text(
//                               'Create',
//                               style: GoogleFonts.roboto(
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
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

//   void _navigateToTournaments() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (context) => const TournamentsPage(),
//       ),
//     );
//   }

//   Widget _buildActionCard({
//     required IconData icon,
//     required String label,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return InkWell(
//       onTap: onTap,
//       borderRadius: BorderRadius.circular(16),
//       child: Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.1),
//           borderRadius: BorderRadius.circular(16),
//           border: Border.all(
//             color: color.withOpacity(0.2),
//             width: 1,
//           ),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.2),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(
//                 icon,
//                 color: color,
//                 size: 24,
//               ),
//             ),
//             const SizedBox(height: 16),
//             Text(
//               label,
//               style: GoogleFonts.roboto(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: color,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return CustomScrollView(
//       controller: _scrollController,
//       physics: const BouncingScrollPhysics(),
//       slivers: [
//         SliverToBoxAdapter(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
//                 child: Text(
//                   'Quick Actions',
//                   style: GoogleFonts.roboto(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.grey.shade800,
//                   ),
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: _buildActionCard(
//                         icon: Icons.search,
//                         label: 'Find Tournaments',
//                         color: const Color(0xFF4361EE),
//                         onTap: _navigateToTournaments,
//                       ),
//                     ),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: _buildActionCard(
//                         icon: Icons.add_circle_outline,
//                         label: 'Create New',
//                         color: const Color(0xFF3A0CA3),
//                         onTap: _showCreateTournamentDialog,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Flexible(
//                       child: Text(
//                         'Upcoming Tournaments',
//                         style: GoogleFonts.roboto(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.grey.shade800,
//                         ),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     TextButton(
//                       onPressed: _navigateToTournaments,
//                       child: Text(
//                         'View All',
//                         style: GoogleFonts.roboto(
//                           color: const Color(0xFF4361EE),
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//         if (_error.isNotEmpty)
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.all(24),
//               child: Text(
//                 _error,
//                 style: GoogleFonts.roboto(color: Colors.red, fontSize: 16),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           ),
//         if (_initialLoad && _tournaments.isEmpty && _error.isEmpty)
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Column(
//                 children: List.generate(
//                   3,
//                   (index) => Padding(
//                     padding: const EdgeInsets.only(bottom: 16),
//                     child: Shimmer.fromColors(
//                       baseColor: Colors.grey.shade200,
//                       highlightColor: Colors.grey.shade100,
//                       child: Container(
//                         height: 120,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         if (_tournaments.isNotEmpty)
//           SliverPadding(
//             padding: const EdgeInsets.symmetric(horizontal: 24),
//             sliver: SliverList(
//               delegate: SliverChildBuilderDelegate(
//                 (context, index) {
//                   if (index == _tournaments.length) {
//                     if (_hasMore) {
//                       return const Padding(
//                         padding: EdgeInsets.symmetric(vertical: 16),
//                         child: Center(
//                           child: CircularProgressIndicator(
//                             color: Color(0xFF4361EE),
//                           ),
//                         ),
//                       );
//                     }
//                     return const SizedBox.shrink();
//                   }

//                   final tournament = _tournaments[index];
//                   final data = tournament.data() as Map<String, dynamic>;
//                   final name = data['name'] as String? ?? 'Tournament';
//                   final location = data['location'] as String? ?? 'Unknown';
//                   final date = (data['eventDate'] as Timestamp?)?.toDate();
//                   final entryFee = data['entryFee'] as String? ?? 'Free';

//                   return Padding(
//                     padding: const EdgeInsets.only(bottom: 16),
//                     child: TournamentCard(
//                       name: name,
//                       location: location,
//                       date: date,
//                       entryFee: entryFee,
//                       onJoin: _navigateToTournaments,
//                     ),
//                   );
//                 },
//                 childCount: _tournaments.length + (_hasMore ? 1 : 0),
//               ),
//             ),
//           ),
//         if (!_initialLoad && _tournaments.isEmpty && _error.isEmpty)
//           SliverToBoxAdapter(
//             child: Padding(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 children: [
//                   Icon(
//                     Icons.event_busy,
//                     size: 60,
//                     color: Colors.grey.shade300,
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'No upcoming tournaments',
//                     style: GoogleFonts.roboto(
//                       fontSize: 16,
//                       color: Colors.grey.shade600,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   TextButton(
//                     onPressed: _showCreateTournamentDialog,
//                     child: Text(
//                       'Create one now',
//                       style: GoogleFonts.roboto(
//                         color: const Color(0xFF4361EE),
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// }