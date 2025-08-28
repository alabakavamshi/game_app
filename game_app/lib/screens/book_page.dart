// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:game_app/models/court.dart';
// import 'package:game_app/screens/court_creation_page.dart';
// import 'package:game_app/widgets/court_card.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:toastification/toastification.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:intl/intl.dart';
// import 'package:shimmer/shimmer.dart';
// import 'package:game_app/screens/home_page.dart';

// class BookPage extends StatefulWidget {
//   final String userCity;

//   const BookPage({super.key, required this.userCity});

//   @override
//   State<BookPage> createState() => _BookPageState();
// }

// class _BookPageState extends State<BookPage> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = '';
//   final FocusNode _searchFocusNode = FocusNode();
//   bool _isCityValid = false;
//   bool _isCheckingCity = true;
//   bool _isRefreshing = false;
//   String? _selectedCourtType;
//   DateTime? _filterStartDate;
//   DateTime? _filterEndDate;
//   String _sortBy = 'name';
//   bool _isSearchExpanded = false;

//   final List<String> _validCities = [
//     'hyderabad',
//     'mumbai',
//     'delhi',
//     'bengaluru',
//     'chennai',
//     'kolkata',
//     'pune',
//     'ahmedabad',
//     'jaipur',
//     'lucknow',
//     'karimnagar',
//   ];

//   @override
//   void initState() {
//     super.initState();
//     _searchFocusNode.addListener(() {
//       setState(() {});
//     });
//     print('BookPage initialized with userCity: "${widget.userCity}"');
//     _validateUserCity();
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     _searchFocusNode.dispose();
//     super.dispose();
//   }

//   Future<void> _validateUserCity() async {
//     setState(() {
//       _isCheckingCity = true;
//     });
//     final isValid = await _validateCity(widget.userCity);
//     setState(() {
//       _isCityValid = isValid;
//       _isCheckingCity = false;
//     });
//     print('User city validation result: $_isCityValid');
//     if (!isValid && widget.userCity.isNotEmpty && widget.userCity.toLowerCase() != 'unknown') {
//       toastification.show(
//         context: context,
//         type: ToastificationType.warning,
//         title: const Text('Invalid City'),
//         description: Text(
//             'The city "${widget.userCity}" is invalid. Please select a valid city like Hyderabad, Mumbai, etc.'),
//         autoCloseDuration: const Duration(seconds: 5),
//         backgroundColor: Colors.grey[300],
//         foregroundColor: Colors.black,
//         alignment: Alignment.bottomCenter,
//       );
//     }
//   }

//   Future<bool> _validateCity(String city) async {
//     final trimmedCity = city.trim().toLowerCase();

//     if (trimmedCity.isEmpty) return false;
//     if (trimmedCity.length < 5) return false;

//     if (_validCities.contains(trimmedCity)) {
//       return true;
//     }

//     try {
//       List<Location> locations = await locationFromAddress(city).timeout(
//         const Duration(seconds: 5),
//         onTimeout: () {
//           throw Exception('Timed out while validating city');
//         },
//       );
//       if (locations.isEmpty) return false;

//       List<Placemark> placemarks = await placemarkFromCoordinates(
//         locations.first.latitude,
//         locations.first.longitude,
//       ).timeout(const Duration(seconds: 5), onTimeout: () {
//         throw Exception('Timed out while geocoding');
//       });

//       if (placemarks.isEmpty) return false;

//       Placemark place = placemarks[0];
//       final geocodedLocality = place.locality?.toLowerCase() ?? '';

//       if (geocodedLocality != trimmedCity) {
//         print('Geocoded locality "$geocodedLocality" does not exactly match input "$trimmedCity"');
//         return false;
//       }

//       if (place.locality == null || place.country == null) return false;

//       return true;
//     } catch (e) {
//       print('City validation error: $e');
//       return false;
//     }
//   }

//   void _showErrorToast(String errorMessage) {
//     toastification.show(
//       context: context,
//       type: ToastificationType.error,
//       title: const Text('Failed to Load Courts'),
//       description: Text(errorMessage),
//       autoCloseDuration: const Duration(seconds: 3),
//       backgroundColor: Colors.grey[300],
//       foregroundColor: Colors.black,
//       alignment: Alignment.bottomCenter,
//     );
//   }

//   void _showParsingErrorToast(int failedCount, int totalCount) {
//     toastification.show(
//       context: context,
//       type: ToastificationType.warning,
//       title: const Text('Some Courts Failed to Load'),
//       description: Text('$failedCount out of $totalCount courts could not be loaded.'),
//       autoCloseDuration: const Duration(seconds: 5),
//       backgroundColor: Colors.grey[300],
//       foregroundColor: Colors.black,
//       alignment: Alignment.bottomCenter,
//     );
//   }

//   Future<Map<String, String>> _fetchCreatorNames(List<Court> courts) async {
//     final creatorUids = courts.map((c) => c.createdBy).toSet().toList();
//     final Map<String, String> creatorNames = {};

//     try {
//       final List<Future<DocumentSnapshot>> userFutures = creatorUids
//           .map((uid) => FirebaseFirestore.instance.collection('users').doc(uid).get())
//           .toList();
//       final userDocs = await Future.wait(userFutures);

//       for (var doc in userDocs) {
//         if (doc.exists) {
//           final data = doc.data() as Map<String, dynamic>;
//           creatorNames[doc.id] = data['displayName'] ?? 'Unknown User';
//         } else {
//           creatorNames[doc.id] = 'Unknown User';
//         }
//       }
//     } catch (e) {
//       print('Error fetching creator names: $e');
//       for (var uid in creatorUids) {
//         creatorNames[uid] = 'Unknown User';
//       }
//     }

//     return creatorNames;
//   }

//   void _showFilterDialog() {
//     final formKey = GlobalKey<FormState>();
//     String? tempCourtType = _selectedCourtType;
//     DateTime? tempStartDate = _filterStartDate;
//     DateTime? tempEndDate = _filterEndDate;

//     showDialog(
//       context: context,
//       builder: (context) {
//         return StatefulBuilder(
//           builder: (context, setDialogState) {
//             return Dialog(
//               backgroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 side: BorderSide(color: Colors.grey[300]!, width: 1),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Form(
//                   key: formKey,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Filter Courts',
//                             style: GoogleFonts.poppins(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w600,
//                               color: Colors.black,
//                             ),
//                           ),
//                           IconButton(
//                             icon: Icon(Icons.close, color: Colors.grey[700]),
//                             onPressed: () => Navigator.pop(context),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         'Court Type',
//                         style: GoogleFonts.poppins(
//                           color: Colors.grey[700],
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Wrap(
//                         spacing: 8,
//                         children: ['All', 'Indoor', 'Outdoor', 'Synthetic']
//                             .map((type) => ChoiceChip(
//                                   label: Text(
//                                     type,
//                                     style: GoogleFonts.poppins(
//                                       color: tempCourtType == (type == 'All' ? null : type)
//                                           ? Colors.white
//                                           : Colors.black,
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w400,
//                                     ),
//                                   ),
//                                   selected: tempCourtType == (type == 'All' ? null : type),
//                                   onSelected: (selected) {
//                                     if (selected) {
//                                       setDialogState(() {
//                                         tempCourtType = type == 'All' ? null : type;
//                                       });
//                                     }
//                                   },
//                                   selectedColor: Colors.blueGrey[700],
//                                   backgroundColor: Colors.white,
//                                   side: BorderSide(color: Colors.grey[300]!),
//                                 ))
//                             .toList(),
//                       ),
//                       const SizedBox(height: 16),
//                       Text(
//                         'Date Range',
//                         style: GoogleFonts.poppins(
//                           color: Colors.grey[700],
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: GestureDetector(
//                               onTap: () async {
//                                 final picked = await showDatePicker(
//                                   context: context,
//                                   initialDate: DateTime.now(),
//                                   firstDate: DateTime.now(),
//                                   lastDate: DateTime(2100),
//                                   builder: (context, child) {
//                                     return Theme(
//                                       data: ThemeData.light().copyWith(
//                                         colorScheme: ColorScheme.light(
//                                           primary: Colors.blueGrey,
//                                           onPrimary: Colors.white,
//                                           surface: Colors.white,
//                                           onSurface: Colors.black,
//                                         ),
//                                         dialogBackgroundColor: Colors.white,
//                                       ),
//                                       child: child!,
//                                     );
//                                   },
//                                 );
//                                 if (picked != null) {
//                                   setDialogState(() {
//                                     tempStartDate = picked;
//                                   });
//                                 }
//                               },
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey[100],
//                                   borderRadius: BorderRadius.circular(8),
//                                   border: Border.all(color: Colors.grey[300]!),
//                                 ),
//                                 child: Text(
//                                   tempStartDate == null
//                                       ? 'Start Date'
//                                       : DateFormat('MMM dd, yyyy').format(tempStartDate!),
//                                   style: GoogleFonts.poppins(
//                                     color: tempStartDate == null ? Colors.grey[700] : Colors.black,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: GestureDetector(
//                               onTap: () async {
//                                 final picked = await showDatePicker(
//                                   context: context,
//                                   initialDate: tempStartDate ?? DateTime.now(),
//                                   firstDate: tempStartDate ?? DateTime.now(),
//                                   lastDate: DateTime(2100),
//                                   builder: (context, child) {
//                                     return Theme(
//                                       data: ThemeData.light().copyWith(
//                                         colorScheme: ColorScheme.light(
//                                           primary: Colors.blueGrey,
//                                           onPrimary: Colors.white,
//                                           surface: Colors.white,
//                                           onSurface: Colors.black,
//                                         ),
//                                         dialogBackgroundColor: Colors.white,
//                                       ),
//                                       child: child!,
//                                     );
//                                   },
//                                 );
//                                 if (picked != null) {
//                                   setDialogState(() {
//                                     tempEndDate = picked;
//                                   });
//                                 }
//                               },
//                               child: Container(
//                                 padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//                                 decoration: BoxDecoration(
//                                   color: Colors.grey[100],
//                                   borderRadius: BorderRadius.circular(8),
//                                   border: Border.all(color: Colors.grey[300]!),
//                                 ),
//                                 child: Text(
//                                   tempEndDate == null
//                                       ? 'End Date'
//                                       : DateFormat('MMM dd, yyyy').format(tempEndDate!),
//                                   style: GoogleFonts.poppins(
//                                     color: tempEndDate == null ? Colors.grey[700] : Colors.black,
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 16),
//                       Row(
//                         children: [
//                           Expanded(
//                             child: TextButton(
//                               onPressed: () {
//                                 setDialogState(() {
//                                   tempCourtType = null;
//                                   tempStartDate = null;
//                                   tempEndDate = null;
//                                 });
//                               },
//                               style: TextButton.styleFrom(
//                                 backgroundColor: Colors.grey[100],
//                                 padding: const EdgeInsets.symmetric(vertical: 12),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                               child: Text(
//                                 'Clear Filters',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.black,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 8),
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: () {
//                                 setState(() {
//                                   _selectedCourtType = tempCourtType;
//                                   _filterStartDate = tempStartDate;
//                                   _filterEndDate = tempEndDate;
//                                 });
//                                 Navigator.pop(context);
//                               },
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.blueGrey[700],
//                                 padding: const EdgeInsets.symmetric(vertical: 12),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                               ),
//                               child: Text(
//                                 'Apply',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.white,
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _buildShimmerLoading() {
//     return SliverList(
//       delegate: SliverChildBuilderDelegate(
//         (context, index) => Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: Shimmer.fromColors(
//             baseColor: Colors.grey[200]!,
//             highlightColor: Colors.grey[100]!,
//             child: Container(
//               height: 120,
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//           ),
//         ),
//         childCount: 3,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: RefreshIndicator(
//         onRefresh: () async {
//           setState(() {
//             _isRefreshing = true;
//           });
//           await Future.delayed(const Duration(seconds: 1));
//           setState(() {
//             _isRefreshing = false;
//           });
//         },
//         color: Colors.white,
//         backgroundColor: Colors.blueGrey[700],
//         child: CustomScrollView(
//           slivers: [
//             SliverAppBar(
//               backgroundColor: Colors.white,
//               elevation: 1,
//               pinned: true,
//               title: Text(
//                 'Discover Courts',
//                 style: GoogleFonts.poppins(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w600,
//                   color: Colors.black,
//                 ),
//               ),
//               actions: [
//                 IconButton(
//                   icon: Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: Colors.blueGrey[700],
//                       border: Border.all(
//                         color: Colors.blueGrey,
//                         width: 1,
//                       ),
//                     ),
//                     child: const Icon(
//                       Icons.add,
//                       color: Colors.white,
//                       size: 20,
//                     ),
//                   ),
//                   onPressed: () {
//                     if (!_isCityValid || widget.userCity.isEmpty || widget.userCity.toLowerCase() == 'unknown') {
//                       toastification.show(
//                         context: context,
//                         type: ToastificationType.warning,
//                         title: const Text('Location Required'),
//                         description: const Text('Please set your location before creating a court.'),
//                         autoCloseDuration: const Duration(seconds: 5),
//                         backgroundColor: Colors.grey[300],
//                         foregroundColor: Colors.black,
//                         alignment: Alignment.bottomCenter,
//                       );
//                       return;
//                     }
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (_) => CourtCreationPage(userCity: widget.userCity),
//                       ),
//                     ).then((_) {
//                       setState(() {}); // Refresh courts after creation
//                     });
//                   },
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.filter_list, color: Colors.grey[700]),
//                   onPressed: _showFilterDialog,
//                 ),
//               ],
//               bottom: PreferredSize(
//                 preferredSize: const Size.fromHeight(60),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       AnimatedContainer(
//                         duration: const Duration(milliseconds: 200),
//                         width: _isSearchExpanded ? MediaQuery.of(context).size.width - 104 : 50,
//                         height: 48,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                             color: _searchFocusNode.hasFocus
//                                 ? Colors.blueGrey[700]!
//                                 : Colors.grey[300]!,
//                             width: 1,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey.withOpacity(0.1),
//                               blurRadius: 4,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Row(
//                           children: [
//                             SizedBox(
//                               width: 48,
//                               child: IconButton(
//                                 icon: Icon(
//                                   _isSearchExpanded ? Icons.arrow_back : Icons.search,
//                                   color: Colors.grey[700],
//                                   size: 20,
//                                 ),
//                                 onPressed: () {
//                                   setState(() {
//                                     if (_isSearchExpanded) {
//                                       _searchController.clear();
//                                       _searchQuery = '';
//                                     }
//                                     _isSearchExpanded = !_isSearchExpanded;
//                                     if (!_isSearchExpanded) {
//                                       _searchFocusNode.unfocus();
//                                     } else {
//                                       FocusScope.of(context).requestFocus(_searchFocusNode);
//                                     }
//                                   });
//                                 },
//                               ),
//                             ),
//                             if (_isSearchExpanded)
//                               Expanded(
//                                 child: TextField(
//                                   controller: _searchController,
//                                   focusNode: _searchFocusNode,
//                                   style: GoogleFonts.poppins(
//                                     fontSize: 14,
//                                     color: Colors.black,
//                                     fontWeight: FontWeight.w400,
//                                   ),
//                                   cursorColor: Colors.blueGrey[700],
//                                   decoration: InputDecoration(
//                                     hintText: 'Search courts...',
//                                     hintStyle: GoogleFonts.poppins(
//                                       fontSize: 14,
//                                       color: Colors.grey[600],
//                                       fontWeight: FontWeight.w400,
//                                     ),
//                                     border: InputBorder.none,
//                                   ),
//                                   onChanged: (value) {
//                                     setState(() {
//                                       _searchQuery = value.toLowerCase().trim();
//                                       print('Search: $_searchQuery');
//                                     });
//                                   },
//                                 ),
//                               ),
//                             if (_isSearchExpanded && _searchQuery.isNotEmpty)
//                               SizedBox(
//                                 width: 48,
//                                 child: Padding(
//                                   padding: const EdgeInsets.symmetric(horizontal: 8),
//                                   child: GestureDetector(
//                                     onTap: () {
//                                       setState(() {
//                                         _searchController.clear();
//                                         _searchQuery = '';
//                                       });
//                                     },
//                                     child: Icon(Icons.clear, color: Colors.grey[700], size: 20),
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                       Container(
//                         width: 72,
//                         height: 48,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.grey[300]!),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.grey.withOpacity(0.1),
//                               blurRadius: 4,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: Row(
//                           children: [
//                             if (!_isSearchExpanded)
//                               Padding(
//                                 padding: const EdgeInsets.only(left: 6),
//                                 child: Text(
//                                   'Sort By',
//                                   style: GoogleFonts.poppins(
//                                     fontSize: 12,
//                                     fontWeight: FontWeight.w500,
//                                     color: Colors.grey[700],
//                                   ),
//                                 ),
//                               ),
//                             Expanded(
//                               child: DropdownButtonHideUnderline(
//                                 child: DropdownButton<String>(
//                                   value: _sortBy,
//                                   items: [
//                                     DropdownMenuItem(
//                                       value: 'name',
//                                       child: Text(
//                                         'Name',
//                                         style: GoogleFonts.poppins(
//                                           color: Colors.black,
//                                           fontWeight: FontWeight.w400,
//                                           fontSize: 12,
//                                         ),
//                                       ),
//                                     ),
//                                     DropdownMenuItem(
//                                       value: 'venue',
//                                       child: Text(
//                                         'Venue',
//                                         style: GoogleFonts.poppins(
//                                           color: Colors.black,
//                                           fontWeight: FontWeight.w400,
//                                           fontSize: 12,
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                   onChanged: (value) {
//                                     setState(() {
//                                       _sortBy = value!;
//                                     });
//                                   },
//                                   icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700], size: 20),
//                                   dropdownColor: Colors.white,
//                                   style: GoogleFonts.poppins(
//                                     color: Colors.black,
//                                     fontSize: 12,
//                                   ),
//                                   isDense: true,
//                                   isExpanded: true,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//             SliverPadding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               sliver: StreamBuilder<QuerySnapshot>(
//                 stream: FirebaseFirestore.instance.collection('courts').limit(50).snapshots(),
//                 builder: (context, snapshot) {
//                   print('StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
//                   if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing || _isCheckingCity) {
//                     return _buildShimmerLoading();
//                   }
//                   if (snapshot.hasError) {
//                     print('Firestore error: ${snapshot.error}');
//                     final errorMessage = snapshot.error.toString();
//                     _showErrorToast(errorMessage);
//                     return SliverToBoxAdapter(
//                       child: SizedBox(
//                         height: 200,
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 Icons.error_outline,
//                                 color: Colors.grey[700],
//                                 size: 40,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 'Error loading courts',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.grey[700],
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               GestureDetector(
//                                 onTap: () {
//                                   setState(() {});
//                                 },
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                                   decoration: BoxDecoration(
//                                     color: Colors.blueGrey[700],
//                                     borderRadius: BorderRadius.circular(8),
//                                     border: Border.all(color: Colors.blueGrey[700]!),
//                                   ),
//                                   child: Text(
//                                     'Retry',
//                                     style: GoogleFonts.poppins(
//                                       color: Colors.white,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   }
//                   if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                     print('No courts found in Firestore');
//                     return SliverToBoxAdapter(
//                       child: SizedBox(
//                         height: 200,
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 Icons.sports_basketball_outlined,
//                                 color: Colors.grey[700],
//                                 size: 40,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 'No courts found.',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.grey[700],
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   }

//                   final totalDocs = snapshot.data!.docs.length;
//                   int failedCount = 0;
//                   final courts = snapshot.data!.docs
//                       .map((doc) {
//                         try {
//                           final c = Court.fromFirestore(doc);
//                           print('Loaded court: ${c.name}');
//                           return c;
//                         } catch (e) {
//                           print('Error parsing court: $e');
//                           failedCount++;
//                           return null;
//                         }
//                       })
//                       .where((c) => c != null)
//                       .cast<Court>()
//                       .toList();

//                   if (failedCount > 0) {
//                     _showParsingErrorToast(failedCount, totalDocs);
//                   }

//                   if (!_isCityValid || widget.userCity.isEmpty || widget.userCity.toLowerCase() == 'unknown') {
//                     print('User city is invalid, empty, or unknown, prompting user to set location');
//                     return SliverToBoxAdapter(
//                       child: SizedBox(
//                         height: 200,
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 Icons.location_off,
//                                 color: Colors.grey[700],
//                                 size: 40,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 'Please set your location to view courts.',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.grey[700],
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                               ),
//                               const SizedBox(height: 8),
//                               Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   GestureDetector(
//                                     onTap: () {
//                                       Navigator.push(
//                                         context,
//                                         MaterialPageRoute(builder: (context) => const HomePage()),
//                                       );
//                                     },
//                                     child: Container(
//                                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                                       decoration: BoxDecoration(
//                                         color: Colors.blueGrey[700],
//                                         borderRadius: BorderRadius.circular(8),
//                                       ),
//                                       child: Text(
//                                         'Set Location',
//                                         style: GoogleFonts.poppins(
//                                           color: Colors.white,
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                   const SizedBox(width: 16),
//                                   GestureDetector(
//                                     onTap: () {
//                                       setState(() {
//                                         _isCityValid = true;
//                                       });
//                                     },
//                                     child: Container(
//                                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                                       decoration: BoxDecoration(
//                                         color: Colors.white,
//                                         borderRadius: BorderRadius.circular(8),
//                                         border: Border.all(color: Colors.grey[300]!),
//                                       ),
//                                       child: Text(
//                                         'Use Default (Hyderabad)',
//                                         style: GoogleFonts.poppins(
//                                           color: Colors.black,
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.w500,
//                                         ),
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   }

//                   final now = DateTime.now();
//                   final filteredCourts = courts.where((court) {
//                     final name = court.name.toLowerCase();
//                     final venue = court.venue.toLowerCase();
//                     final city = court.city.toLowerCase();
//                     final hasFutureSlots =
//                         court.availableSlots.any((slot) => slot.endTime.isAfter(now));
//                     final matchesCity = city == widget.userCity.toLowerCase();

//                     bool matchesCourtType =
//                         _selectedCourtType == null || court.type == _selectedCourtType;

//                     bool matchesDateRange = true;
//                     if (_filterStartDate != null || _filterEndDate != null) {
//                       matchesDateRange = court.availableSlots.any((slot) {
//                         bool afterStart = _filterStartDate == null ||
//                             slot.startTime.isAfter(_filterStartDate!);
//                         bool beforeEnd = _filterEndDate == null ||
//                             slot.endTime.isBefore(_filterEndDate!.add(const Duration(days: 1)));
//                         return afterStart && beforeEnd;
//                       });
//                     }

//                     print('Filtering court: ${court.name}, city: $city, userCity: ${widget.userCity}, matchesCity: $matchesCity');
//                     return matchesCity &&
//                         (name.contains(_searchQuery) ||
//                             venue.contains(_searchQuery) ||
//                             city.contains(_searchQuery)) &&
//                         hasFutureSlots &&
//                         matchesCourtType &&
//                         matchesDateRange;
//                   }).toList();

//                   if (_sortBy == 'name') {
//                     filteredCourts.sort((a, b) => a.name.compareTo(b.name));
//                   } else if (_sortBy == 'venue') {
//                     filteredCourts.sort((a, b) => a.venue.compareTo(b.venue));
//                   }

//                   if (filteredCourts.isEmpty) {
//                     print('No matching courts after filtering');
//                     return SliverToBoxAdapter(
//                       child: SizedBox(
//                         height: 200,
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                 Icons.search_off,
//                                 color: Colors.grey[700],
//                                 size: 40,
//                               ),
//                               const SizedBox(height: 8),
//                               Text(
//                                 'No courts found in ${widget.userCity}.',
//                                 style: GoogleFonts.poppins(
//                                   color: Colors.grey[700],
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w400,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     );
//                   }

//                   print('Displaying ${filteredCourts.length} courts');
//                   return FutureBuilder<Map<String, String>>(
//                     future: _fetchCreatorNames(filteredCourts),
//                     builder: (context, creatorSnapshot) {
//                       if (creatorSnapshot.connectionState == ConnectionState.waiting) {
//                         return _buildShimmerLoading();
//                       }
//                       if (creatorSnapshot.hasError) {
//                         print('Error fetching creator names: ${creatorSnapshot.error}');
//                         return SliverToBoxAdapter(
//                           child: SizedBox(
//                             height: 200,
//                             child: Center(
//                               child: Column(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   Icon(
//                                     Icons.error_outline,
//                                     color: Colors.grey[700],
//                                     size: 40,
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     'Error loading creator names',
//                                     style: GoogleFonts.poppins(
//                                       color: Colors.grey[700],
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w400,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         );
//                       }

//                       final creatorNames = creatorSnapshot.data ?? {};
//                       return SliverList(
//                         delegate: SliverChildBuilderDelegate(
//                           (context, index) {
//                             final court = filteredCourts[index];
//                             final creatorName = creatorNames[court.createdBy] ?? 'Unknown User';
//                             return Padding(
//                               padding: const EdgeInsets.only(bottom: 12),
//                               child: CourtCard(
//                                 court: court,
//                                 creatorName: creatorName,
//                               ),
//                             );
//                           },
//                           childCount: filteredCourts.length,
//                         ),
//                       );
//                     },
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }