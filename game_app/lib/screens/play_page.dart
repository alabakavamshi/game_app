import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_app/models/tournament.dart';
import 'package:game_app/player_pages/playerhomepage.dart';
import 'package:game_app/widgets/tournament_card.dart' as card;
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import 'package:game_app/tournaments/tournament_details_page.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_state.dart';

enum DisplayMode { list, grid, compact }

class PlayPage extends StatefulWidget {
  final String userCity;

  const PlayPage({super.key, required this.userCity});

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  bool _isCityValid = false;
  bool _isCheckingCity = true;
  bool _isRefreshing = false;
  String? _selectedGameFormat;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String _sortBy = 'date';
  bool _isSearchExpanded = false;
  DisplayMode _displayMode = DisplayMode.list;

  final List<String> _validCities = [
    'hyderabad',
    'mumbai',
    'delhi',
    'bengaluru',
    'chennai',
    'kolkata',
    'pune',
    'ahmedabad',
    'jaipur',
    'lucknow',
  ];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {});
    });
    print('PlayPage initialized with userCity: "${widget.userCity}"');
    _validateUserCity();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _validateUserCity() async {
    setState(() => _isCheckingCity = true);
    final isValid = await _validateCity(widget.userCity);
    setState(() {
      _isCityValid = isValid;
      _isCheckingCity = false;
    });
    print('User city validation result: $_isCityValid');
    if (!isValid && widget.userCity.isNotEmpty && widget.userCity.toLowerCase() != 'unknown') {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        title: const Text('Invalid City'),
        description: Text('The city "${widget.userCity}" is invalid. Please select a valid city.'),
        autoCloseDuration: const Duration(seconds: 5),
        backgroundColor: Colors.grey[200],
        foregroundColor: Colors.black,
        alignment: Alignment.bottomCenter,
      );
    }
  }

  Future<bool> _validateCity(String city) async {
    final trimmedCity = city.trim().toLowerCase();
    if (trimmedCity.isEmpty || trimmedCity == 'unknown') return false;
    if (trimmedCity.length < 5) return false;
    if (_validCities.contains(trimmedCity)) return true;

    try {
      List<Location> locations = await locationFromAddress(city).timeout(const Duration(seconds: 5));
      if (locations.isEmpty) return false;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks.isEmpty) return false;
      return placemarks[0].locality?.toLowerCase() == trimmedCity;
    } catch (e) {
      print('City validation error: $e');
      return false;
    }
  }

  void _showErrorToast(String errorMessage) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      title: const Text('Failed to Load Tournaments'),
      description: Text(errorMessage),
      autoCloseDuration: const Duration(seconds: 3),
      backgroundColor: Colors.grey[200],
      foregroundColor: Colors.black,
      alignment: Alignment.bottomCenter,
    );
  }

  void _showParsingErrorToast(int failedCount, int totalCount) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      title: const Text('Some Events Failed to Load'),
      description: Text('$failedCount out of $totalCount events could not be loaded.'),
      autoCloseDuration: const Duration(seconds: 5),
      backgroundColor: Colors.grey[200],
      foregroundColor: Colors.black,
      alignment: Alignment.bottomCenter,
    );
  }

  Future<Map<String, String>> _fetchCreatorNames(List<Tournament> tournaments) async {
    final creatorUids = tournaments.map((t) => t.createdBy).toSet().toList();
    final Map<String, String> creatorNames = {};

    try {
      final List<Future<DocumentSnapshot>> userFutures = creatorUids
          .map((uid) => FirebaseFirestore.instance.collection('users').doc(uid).get())
          .toList();
      final userDocs = await Future.wait(userFutures);

      for (var doc in userDocs) {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          creatorNames[doc.id] = data['firstName'] + ' ' + (data['lastName'] ?? '');
        } else {
          creatorNames[doc.id] = 'Unknown User';
        }
      }
    } catch (e) {
      print('Error fetching creator names: $e');
      for (var uid in creatorUids) {
        creatorNames[uid] = 'Unknown User';
      }
    }

    return creatorNames;
  }

  void _showFilterDialog() {
    final formKey = GlobalKey<FormState>();
    String? tempGameFormat = _selectedGameFormat;
    DateTime? tempStartDate = _filterStartDate;
    DateTime? tempEndDate = _filterEndDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.grey, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filter Events',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.grey),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Match Type',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          'All',
                          'Men\'s Singles',
                          'Women\'s Singles',
                          'Men\'s Doubles',
                          'Women\'s Doubles',
                          'Mixed Doubles'
                        ]
                            .map((format) => ChoiceChip(
                                  label: Text(
                                    format,
                                    style: GoogleFonts.poppins(
                                      color: tempGameFormat == (format == 'All' ? null : format)
                                          ? Colors.black
                                          : Colors.grey[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  selected: tempGameFormat == (format == 'All' ? null : format),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setDialogState(() {
                                        tempGameFormat = format == 'All' ? null : format;
                                      });
                                    }
                                  },
                                  selectedColor: Colors.blueGrey[200],
                                  backgroundColor: Colors.grey[100],
                                  side: const BorderSide(color: Colors.grey),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Date Range',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Colors.blueGrey,
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Colors.black,
                                        ),
                                        dialogBackgroundColor: Colors.white,
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    tempStartDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Text(
                                  tempStartDate == null
                                      ? 'Start Date'
                                      : DateFormat('MMM dd, yyyy').format(tempStartDate!),
                                  style: GoogleFonts.poppins(
                                    color: tempStartDate == null ? Colors.grey[700] : Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: tempStartDate ?? DateTime.now(),
                                  firstDate: tempStartDate ?? DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.light().copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Colors.blueGrey,
                                          onPrimary: Colors.white,
                                          surface: Colors.white,
                                          onSurface: Colors.black,
                                        ),
                                        dialogBackgroundColor: Colors.white,
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    tempEndDate = picked;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey),
                                ),
                                child: Text(
                                  tempEndDate == null
                                      ? 'End Date'
                                      : DateFormat('MMM dd, yyyy').format(tempEndDate!),
                                  style: GoogleFonts.poppins(
                                    color: tempEndDate == null ? Colors.grey[700] : Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  tempGameFormat = null;
                                  tempStartDate = null;
                                  tempEndDate = null;
                                });
                              },
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.grey[200],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Clear Filters',
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _selectedGameFormat = tempGameFormat;
                                  _filterStartDate = tempStartDate;
                                  _filterEndDate = tempEndDate;
                                });
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey[700],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Apply',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[200]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: _displayMode == DisplayMode.grid ? 200 : 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        childCount: 3,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Error loading events',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'No events found.',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationWidget() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_off,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Please set your location to view events.',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PlayerHomePage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[700],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Set Location',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCityValid = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: Text(
                        'Use Default (Hyderabad)',
                        style: GoogleFonts.poppins(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off,
                color: Colors.grey,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'No events found in ${widget.userCity}.',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedGameFormat = null;
                        _filterStartDate = null;
                        _filterEndDate = null;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blueGrey[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Clear Filters',
                      style: GoogleFonts.poppins(
                        color: Colors.blueGrey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayModeButton() {
    return PopupMenuButton<DisplayMode>(
      icon: Icon(
        _displayMode == DisplayMode.list
            ? Icons.view_agenda
            : _displayMode == DisplayMode.grid
                ? Icons.grid_view
                : Icons.view_compact,
        color: Colors.grey,
      ),
      onSelected: (mode) => setState(() => _displayMode = mode),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: DisplayMode.list,
          child: Row(
            children: [
              const Icon(Icons.view_agenda, size: 20),
              const SizedBox(width: 8),
              Text('List View', style: GoogleFonts.poppins()),
            ],
          ),
        ),
        PopupMenuItem(
          value: DisplayMode.grid,
          child: Row(
            children: [
              const Icon(Icons.grid_view, size: 20),
              const SizedBox(width: 8),
              Text('Grid View', style: GoogleFonts.poppins()),
            ],
          ),
        ),
        PopupMenuItem(
          value: DisplayMode.compact,
          child: Row(
            children: [
              const Icon(Icons.view_compact, size: 20),
              const SizedBox(width: 8),
              Text('Compact View', style: GoogleFonts.poppins()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTournamentCard({
    required BuildContext context,
    required Tournament tournament,
    required Map<String, String> creatorNames,
    required String? userId,
  }) {
    final creatorName = creatorNames[tournament.createdBy] ?? 'Unknown User';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TournamentDetailsPage(
            tournament: tournament,
            creatorName: creatorName,
          ),
        ),
      ),
      child: card.TournamentCard(
        tournament: tournament,
        creatorName: creatorName,
        isCreator: userId != null && tournament.createdBy == userId,
      ),
    );
  }

  Widget _buildGridTournamentCard({
    required BuildContext context,
    required Tournament tournament,
    required Map<String, String> creatorNames,
    required String? userId,
  }) {
    final creatorName = creatorNames[tournament.createdBy] ?? 'Unknown User';
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TournamentDetailsPage(
              tournament: tournament,
              creatorName: creatorName,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: Image.asset(
                    tournament.profileImage ?? "assets/tournament_placholder.jpg",
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      print('Image load error for ${tournament.profileImage}: $error');
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tournament.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('MMM d').format(tournament.startDate)} • ${tournament.city}',
                    style: GoogleFonts.poppins(
                      color: const Color.fromARGB(255, 68, 67, 67),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTournamentCard({
    required BuildContext context,
    required Tournament tournament,
    required Map<String, String> creatorNames,
    required String? userId,
  }) {
    final creatorName = creatorNames[tournament.createdBy] ?? 'Unknown User';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 50,
          height: 50,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              tournament.profileImage ?? "assets/tournament_placholder.jpg",
              fit: BoxFit.cover,
              width: 50,
              height: 50,
              errorBuilder: (context, error, stackTrace) {
                print('Image load error for ${tournament.profileImage}: $error');
                return Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        title: Text(
          tournament.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${DateFormat('MMM d').format(tournament.startDate)} • ${tournament.city}',
          style: GoogleFonts.poppins(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TournamentDetailsPage(
              tournament: tournament,
              creatorName: creatorName,
            ),
          ),
        ),
      ),
    );
  }

  String _capitalizeSortOption(String sortBy) {
    return sortBy[0].toUpperCase() + sortBy.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : null;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isRefreshing = true);
          await Future.delayed(const Duration(seconds: 1));
          setState(() => _isRefreshing = false);
        },
        color: Colors.black,
        backgroundColor: Colors.blueGrey[200],
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.grey[50],
              pinned: true,
              title: Text(
                'Discover Events',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.grey),
                  onPressed: _showFilterDialog,
                ),
                _buildDisplayModeButton(),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _isSearchExpanded ? MediaQuery.of(context).size.width - 150 : 52,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _searchFocusNode.hasFocus ? Colors.grey[400]! : Colors.grey[300]!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isSearchExpanded ? Icons.arrow_back : Icons.search,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_isSearchExpanded) {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }
                                  _isSearchExpanded = !_isSearchExpanded;
                                  if (!_isSearchExpanded) {
                                    _searchFocusNode.unfocus();
                                  } else {
                                    FocusScope.of(context).requestFocus(_searchFocusNode);
                                  }
                                });
                              },
                            ),
                            if (_isSearchExpanded)
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  cursorColor: Colors.black,
                                  decoration: InputDecoration(
                                    hintText: 'Search events...',
                                    hintStyle: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _searchQuery = value.toLowerCase().trim();
                                      print('Search: $_searchQuery');
                                    });
                                  },
                                ),
                              ),
                            if (_isSearchExpanded && _searchQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      print('Search cleared');
                                    });
                                  },
                                  child: const Icon(Icons.clear, color: Colors.grey, size: 20),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        width: 115,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: PopupMenuButton<String>(
                          onSelected: (value) {
                            setState(() {
                              _sortBy = value;
                            });
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'date',
                              child: Text(
                                'Date',
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'name',
                              child: Text(
                                'Name',
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'participants',
                              child: Text(
                                'Participants',
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                          tooltip: 'Sort By',
                          color: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _capitalizeSortOption(_sortBy),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Icon(
                                  Icons.sort,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tournaments')
                    .where('status', isEqualTo: 'open')
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  print('StreamBuilder state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
                  if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing || _isCheckingCity) {
                    return _buildShimmerLoading();
                  }
                  if (snapshot.hasError) {
                    print('Firestore error: ${snapshot.error}');
                    final errorMessage = snapshot.error.toString();
                    _showErrorToast(errorMessage);
                    return _buildErrorWidget();
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    print('No events found in Firestore');
                    return _buildEmptyWidget();
                  }

                  if (!_isCityValid || widget.userCity.isEmpty || widget.userCity.toLowerCase() == 'unknown') {
                    print('User city is invalid, empty, or unknown, prompting user to set location');
                    return _buildLocationWidget();
                  }

                  final totalDocs = snapshot.data!.docs.length;
                  int failedCount = 0;
                  final tournaments = snapshot.data!.docs
                      .map((doc) {
                        try {
                          final tournament = Tournament.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
                          print('Parsed tournament: ${tournament.name}, id: ${tournament.id}, status: ${tournament.status}, startDate: ${tournament.startDate}, endDate: ${tournament.endDate}');
                          if (tournament.status != 'open') {
                            print('Skipping tournament ${tournament.id} with status ${tournament.status}');
                            return null;
                          }
                          return tournament;
                        } catch (e) {
                          print('Error parsing event ${doc.id}: $e');
                          failedCount++;
                          return null;
                        }
                      })
                      .where((t) => t != null)
                      .cast<Tournament>()
                      .toList();

                  if (failedCount > 0) {
                    _showParsingErrorToast(failedCount, totalDocs);
                  }

                  final now = DateTime.now();
                  print('Current time: $now');
                  final filteredTournaments = tournaments.where((tournament) {
                    final name = tournament.name.toLowerCase();
                    final venue = tournament.venue.toLowerCase();
                    final city = tournament.city.toLowerCase();
                    final matchesCity = city == widget.userCity.toLowerCase();

                    final isNotCompleted = tournament.endDate == null || tournament.endDate!.isAfter(now);

                    bool matchesGameFormat = _selectedGameFormat == null || tournament.gameFormat == _selectedGameFormat;

                    bool matchesDateRange = true;
                    if (_filterStartDate != null) {
                      matchesDateRange = tournament.startDate.isAfter(_filterStartDate!);
                    }
                    if (_filterEndDate != null) {
                      matchesDateRange = matchesDateRange && tournament.startDate.isBefore(_filterEndDate!.add(const Duration(days: 1)));
                    }

                    print('Filtering event: ${tournament.name}, id: ${tournament.id}, city: $city, userCity: ${widget.userCity}, matchesCity: $matchesCity, isNotCompleted: $isNotCompleted, matchesGameFormat: $matchesGameFormat, matchesDateRange: $matchesDateRange');
                    return matchesCity &&
                        (name.contains(_searchQuery) || venue.contains(_searchQuery) || city.contains(_searchQuery)) &&
                        isNotCompleted &&
                        matchesGameFormat &&
                        matchesDateRange;
                  }).toList();

                  if (_sortBy == 'date') {
                    filteredTournaments.sort((a, b) => a.startDate.compareTo(b.startDate));
                  } else if (_sortBy == 'name') {
                    filteredTournaments.sort((a, b) => a.name.compareTo(b.name));
                  } else if (_sortBy == 'participants') {
                    filteredTournaments.sort((a, b) => b.participants.length.compareTo(a.participants.length));
                  }

                  if (filteredTournaments.isEmpty) {
                    print('No matching events after filtering');
                    return _buildNoResultsWidget();
                  }

                  print('Displaying ${filteredTournaments.length} events');
                  return FutureBuilder<Map<String, String>>(
                    future: _fetchCreatorNames(filteredTournaments),
                    builder: (context, creatorSnapshot) {
                      if (creatorSnapshot.connectionState == ConnectionState.waiting) {
                        return _buildShimmerLoading();
                      }
                      if (creatorSnapshot.hasError) {
                        print('Error fetching creator names: ${creatorSnapshot.error}');
                        return SliverToBoxAdapter(
                          child: SizedBox(
                            height: 200,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error loading creator names',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final creatorNames = creatorSnapshot.data ?? {};
                      switch (_displayMode) {
                        case DisplayMode.list:
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTournamentCard(
                                  context: context,
                                  tournament: filteredTournaments[index],
                                  creatorNames: creatorNames,
                                  userId: userId,
                                ),
                              ),
                              childCount: filteredTournaments.length,
                            ),
                          );
                        case DisplayMode.grid:
                          return SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.8,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildGridTournamentCard(
                                context: context,
                                tournament: filteredTournaments[index],
                                creatorNames: creatorNames,
                                userId: userId,
                              ),
                              childCount: filteredTournaments.length,
                            ),
                          );
                        case DisplayMode.compact:
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildCompactTournamentCard(
                                context: context,
                                tournament: filteredTournaments[index],
                                creatorNames: creatorNames,
                                userId: userId,
                              ),
                              childCount: filteredTournaments.length,
                            ),
                          );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}