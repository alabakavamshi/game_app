import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:game_app/umpire/matchcontrolpage.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class UmpireSchedulePage extends StatefulWidget {
  final String userId;
  final String userEmail;

  const UmpireSchedulePage({super.key, required this.userId, required this.userEmail});

  @override
  State<UmpireSchedulePage> createState() => _UmpireSchedulePageState();
}

class _UmpireSchedulePageState extends State<UmpireSchedulePage> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _matches = [];
  Set<DateTime> _matchDates = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _filterMatchesOnly = false;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones(); // Initialize timezone data
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _fetchMatches();
  }

  Future<void> _fetchMatches() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _matches = [];
      _matchDates = {};
    });

    try {
      final tournamentsSnapshot = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('status', whereIn: ['open', 'ongoing'])
          .orderBy('startDate', descending: false)
          .get();

      final List<Map<String, dynamic>> allMatches = [];
      final Set<DateTime> matchDates = {};

      for (var tournamentDoc in tournamentsSnapshot.docs) {
        final tournamentData = tournamentDoc.data();
        final matches = List<Map<String, dynamic>>.from(tournamentData['matches'] ?? []);
        final tournamentTimezone = tournamentData['timezone']?.toString() ?? 'Asia/Kolkata';
        tz.Location tzLocation;
        try {
          tzLocation = tz.getLocation(tournamentTimezone);
        } catch (e) {
          debugPrint('Invalid timezone for tournament ${tournamentDoc.id}: $tournamentTimezone, defaulting to Asia/Kolkata');
          tzLocation = tz.getLocation('Asia/Kolkata');
        }

        for (var match in matches) {
          try {
            final matchUmpire = match['umpire'] as Map<String, dynamic>?;
            if (matchUmpire == null) continue;

            final matchUmpireEmail = (matchUmpire['email'] as String?)?.toLowerCase().trim();
            if (matchUmpireEmail != widget.userEmail.toLowerCase().trim()) continue;

            final matchStartTime = match['startTime'] as Timestamp?;
            if (matchStartTime == null) continue;

            final matchTime = matchStartTime.toDate();
            final matchTimeInTz = tz.TZDateTime.from(matchTime, tzLocation);
            final matchDateOnly = DateTime(matchTimeInTz.year, matchTimeInTz.month, matchTimeInTz.day);

            matchDates.add(matchDateOnly);

            if (matchDateOnly.isAtSameMomentAs(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day))) {
              allMatches.add({
                'matchId': match['matchId']?.toString() ?? '',
                'tournamentId': tournamentDoc.id,
                'tournamentName': tournamentData['name']?.toString() ?? 'Unnamed Tournament',
                'player1': match['player1']?.toString() ?? 'TBD',
                'player2': match['player2']?.toString() ?? 'TBD',
                'startTime': matchTime, // Keep for compatibility
                'startTimeInTz': matchTimeInTz,
                'timezone': tournamentTimezone,
                'status': match['completed'] == true
                    ? 'completed'
                    : (match['liveScores']?['isLive'] == true ? 'ongoing' : 'scheduled'),
                'location': (tournamentData['venue']?.isNotEmpty == true && tournamentData['city']?.isNotEmpty == true)
                    ? '${tournamentData['venue']}, ${tournamentData['city']}'
                    : tournamentData['city']?.isNotEmpty == true
                        ? tournamentData['city']
                        : 'Unknown',
                'match': match,
                'isDoubles': (tournamentData['gameFormat'] ?? '').toLowerCase().contains('doubles'),
                'matchIndex': matches.indexOf(match),
              });
            }
          } catch (e) {
            debugPrint('Error processing match: $e');
          }
        }
      }

      if (mounted) {
        setState(() {
          _matches = allMatches..sort((a, b) => (a['startTimeInTz'] as tz.TZDateTime).compareTo(b['startTimeInTz'] as tz.TZDateTime));
          _matchDates = matchDates;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching matches: $e\nStack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load matches: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      selectableDayPredicate: _filterMatchesOnly
          ? (day) => _matchDates.any((d) => d.isAtSameMomentAs(DateTime(day.year, day.month, day.day)))
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFF4A261), // Accent
              onPrimary: Color(0xFFFDFCFB), // Background
              surface: Color(0xFFFFFFFF), // Surface
              onSurface: Color(0xFF333333), // Text Primary
            ),
            dialogBackgroundColor: const Color(0xFFFDFCFB), // Background
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
        await _fetchMatches();
      }
    }
  }

  Widget _buildCalendarRow() {
    return Column(
      children: [
        Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 60,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index));
              final dateOnly = DateTime(date.year, date.month, date.day);
              final isSelected = dateOnly.isAtSameMomentAs(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));
              final hasMatches = _matchDates.any((d) => d.isAtSameMomentAs(dateOnly));

              if (_filterMatchesOnly && !hasMatches) {
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _selectedDate = dateOnly;
                      _fetchMatches();
                    });
                  }
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF4A261) // Accent
                        : hasMatches
                            ? const Color(0xFF2A9D8F) // Success
                            : const Color(0xFFFFFFFF), // Surface
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF4A261) // Accent
                          : hasMatches
                              ? const Color(0xFF2A9D8F) // Success
                              : const Color(0xFFA8DADC), // Cool Blue Highlights
                      width: hasMatches ? 2 : 1,
                    ),
                    boxShadow: hasMatches
                        ? [
                            BoxShadow(
                              color: const Color(0xFF2A9D8F).withOpacity(0.3), // Success
                              blurRadius: 4,
                              spreadRadius: 1,
                            )
                          ]
                        : [
                            BoxShadow(
                              color: const Color(0xFF1D3557).withOpacity(0.2), // Deep Indigo
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('MMM').format(date).toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: isSelected ? const Color(0xFFFDFCFB) : const Color(0xFF757575), // Background or Text Secondary
                          fontSize: 10,
                          fontWeight: hasMatches ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEE').format(date),
                        style: GoogleFonts.poppins(
                          color: isSelected ? const Color(0xFFFDFCFB) : const Color(0xFF757575), // Background or Text Secondary
                          fontSize: 12,
                          fontWeight: hasMatches ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd').format(date),
                        style: GoogleFonts.poppins(
                          color: isSelected ? const Color(0xFFFDFCFB) : const Color(0xFF333333), // Background or Text Primary
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasMatches)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A9D8F), // Success
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildLegendItem(const Color(0xFF2A9D8F), 'Match Days'), // Success
                  const SizedBox(width: 16),
                  _buildLegendItem(const Color(0xFFF4A261), 'Selected'), // Accent
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.filter_alt,
                      color: _filterMatchesOnly ? const Color(0xFFF4A261) : const Color(0xFF757575), // Accent or Text Secondary
                    ),
                    onPressed: () {
                      setState(() {
                        _filterMatchesOnly = !_filterMatchesOnly;
                      });
                    },
                    tooltip: 'Show only days with matches',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
        ),
      ],
    );
  }

  Widget _buildMatchStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = const Color(0xFF2A9D8F); // Success
        textColor = const Color(0xFFFDFCFB); // Background
        break;
      case 'ongoing':
        backgroundColor = const Color(0xFFE9C46A); // Mood Booster
        textColor = const Color(0xFF333333); // Text Primary
        break;
      case 'cancelled':
        backgroundColor = const Color(0xFFE76F51); // Error
        textColor = const Color(0xFFFDFCFB); // Background
        break;
      default: // scheduled
        backgroundColor = const Color(0xFFA8DADC); // Cool Blue Highlights
        textColor = const Color(0xFF333333); // Text Primary
    }

    return Chip(
      label: Text(
        status.capitalize(),
        style: GoogleFonts.poppins(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB), // Background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Umpire Schedule',
          style: GoogleFonts.poppins(
            color: const Color(0xFF333333), // Text Primary
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF757575)), // Text Secondary
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFF757575)), // Text Secondary
            onPressed: () => _selectDate(context),
            tooltip: 'Open calendar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF757575)), // Text Secondary
            onPressed: _fetchMatches,
            tooltip: 'Refresh schedule',
          ),
        ],
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
      body: Column(
        children: [
          _buildCalendarRow(),
          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFFF4A261), // Accent
            ),
          Expanded(
            child: _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(color: const Color(0xFFE76F51), fontSize: 16), // Error
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchMatches,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C9A8B), // Primary
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _matches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy, size: 48, color: Color(0xFF757575)), // Text Secondary
                            const SizedBox(height: 16),
                            Text(
                              'No matches scheduled for',
                              style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 18), // Text Secondary
                            ),
                            Text(
                              DateFormat('MMMM dd, yyyy').format(_selectedDate),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF333333), // Text Primary
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchMatches,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6C9A8B), // Primary
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Refresh Data',
                                style: GoogleFonts.poppins(color: const Color(0xFFFDFCFB)), // Background
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _matches.length,
                        itemBuilder: (context, index) {
                          final match = _matches[index];
                          final startTimeInTz = match['startTimeInTz'] as tz.TZDateTime;
                          final timezoneDisplay = match['timezone'] == 'Asia/Kolkata' ? 'IST' : match['timezone'];
                          final formattedTime = DateFormat('hh:mm a').format(startTimeInTz) + ' $timezoneDisplay';
                          return Card(
                            color: const Color(0xFFFFFFFF), // Surface
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                            shadowColor: const Color(0xFF1D3557).withOpacity(0.2), // Deep Indigo
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${match['player1']} vs ${match['player2']}',
                                          style: GoogleFonts.poppins(
                                            color: const Color(0xFF333333), // Text Primary
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      _buildMatchStatusChip(match['status']),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.event, color: Color(0xFF757575), size: 16), // Text Secondary
                                      const SizedBox(width: 4),
                                      Text(
                                        match['tournamentName'],
                                        style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Color(0xFF757575), size: 16), // Text Secondary
                                      const SizedBox(width: 4),
                                      Text(
                                        formattedTime,
                                        style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.info_outline, color: Color(0xFFF4A261), size: 20), // Accent
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => MatchControlPage(
                                                tournamentId: match['tournamentId'],
                                                match: match['match'],
                                                matchIndex: match['matchIndex'],
                                                isDoubles: match['isDoubles'],
                                              ),
                                            ),
                                          );
                                        },
                                        tooltip: 'View match details',
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, color: Color(0xFF757575), size: 16), // Text Secondary
                                      const SizedBox(width: 4),
                                      Text(
                                        match['location'],
                                        style: GoogleFonts.poppins(color: const Color(0xFF757575), fontSize: 12), // Text Secondary
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}