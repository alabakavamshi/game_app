import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class SchedulePage extends StatefulWidget {
  final String userId;

  const SchedulePage({super.key, required this.userId});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _matches = [];
  Set<DateTime> _tournamentDates = {};
  Set<DateTime> _matchDates = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _filterMatchesOnly = false;

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones(); // Initialize timezone data
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    _fetchTournamentsAndMatches();
  }

  Future<void> _fetchTournamentsAndMatches() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final tournamentsQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('createdBy', isEqualTo: widget.userId)
          .where('status', whereIn: ['open', 'ongoing'])
          .orderBy('startDate', descending: false)
          .get();

      final List<Map<String, dynamic>> allMatches = [];
      final Set<DateTime> tournamentDates = {};
      final Set<DateTime> matchDates = {};

      for (var doc in tournamentsQuery.docs) {
        final data = doc.data();
        final tournamentTimezone = data['timezone']?.toString() ?? 'Asia/Kolkata';
        tz.Location tzLocation;
        try {
          tzLocation = tz.getLocation(tournamentTimezone);
        } catch (e) {
          debugPrint('Invalid timezone for tournament ${doc.id}: $tournamentTimezone, defaulting to Asia/Kolkata');
          tzLocation = tz.getLocation('Asia/Kolkata');
        }

        final startDate = (data['startDate'] as Timestamp).toDate();
        final startDateInTz = tz.TZDateTime.from(startDate, tzLocation);
        final endDate = (data['endDate'] as Timestamp?)?.toDate() ?? startDate;
        final endDateInTz = tz.TZDateTime.from(endDate, tzLocation);

        // Add tournament date range
        for (var date = startDateInTz;
            date.isBefore(endDateInTz.add(const Duration(days: 1)));
            date = date.add(const Duration(days: 1))) {
          tournamentDates.add(DateTime(date.year, date.month, date.day));
        }

        // Process matches
        final matches = List<Map<String, dynamic>>.from(data['matches'] ?? []);
        for (var match in matches) {
          if (match['startTime'] != null) {
            final matchTime = (match['startTime'] as Timestamp).toDate();
            final matchTimeInTz = tz.TZDateTime.from(matchTime, tzLocation);
            final matchDate = DateTime(matchTimeInTz.year, matchTimeInTz.month, matchTimeInTz.day);

            matchDates.add(matchDate);

            if (matchDate.day == _selectedDate.day &&
                matchDate.month == _selectedDate.month &&
                matchDate.year == _selectedDate.year) {
              allMatches.add({
                'matchId': match['matchId']?.toString() ?? '',
                'tournamentId': doc.id,
                'tournamentName': data['name']?.toString() ?? 'Unnamed Tournament',
                'player1': match['player1']?.toString() ?? 'TBD',
                'player2': match['player2']?.toString() ?? 'TBD',
                'startTime': matchTime, // Keep for compatibility
                'startTimeInTz': matchTimeInTz,
                'timezone': tournamentTimezone,
                'status': match['status']?.toString() ?? 'scheduled',
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _matches = allMatches..sort((a, b) => (a['startTimeInTz'] as tz.TZDateTime).compareTo(b['startTimeInTz'] as tz.TZDateTime));
          _tournamentDates = tournamentDates;
          _matchDates = matchDates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load matches: ${e.toString()}';
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
      setState(() {
        _selectedDate = picked;
      });
      await _fetchTournamentsAndMatches();
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
              final isSelected = dateOnly.day == _selectedDate.day &&
                  dateOnly.month == _selectedDate.month &&
                  dateOnly.year == _selectedDate.year;

              final hasTournament = _tournamentDates.any((d) =>
                  d.day == dateOnly.day && d.month == dateOnly.month && d.year == dateOnly.year);

              final hasMatches = _matchDates.any((d) =>
                  d.day == dateOnly.day && d.month == dateOnly.month && d.year == dateOnly.year);

              if (_filterMatchesOnly && !hasMatches) {
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = dateOnly;
                  });
                  _fetchTournamentsAndMatches();
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF4A261) // Accent
                        : hasMatches
                            ? const Color(0xFF2A9D8F) // Success
                            : hasTournament
                                ? const Color(0xFFE9C46A) // Mood Booster
                                : const Color(0xFFFFFFFF), // Surface
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFF4A261) // Accent
                          : hasMatches
                              ? const Color(0xFF2A9D8F) // Success
                              : hasTournament
                                  ? const Color(0xFFE9C46A) // Mood Booster
                                  : const Color(0xFFA8DADC), // Cool Blue Highlights
                      width: hasMatches ? 2 : (hasTournament ? 1.5 : 1),
                    ),
                    boxShadow: [
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
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEE').format(date),
                        style: GoogleFonts.poppins(
                          color: isSelected ? const Color(0xFFFDFCFB) : const Color(0xFF757575), // Background or Text Secondary
                          fontSize: 12,
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
                  _buildLegendItem(const Color(0xFFE9C46A), 'Tournament Days'), // Mood Booster
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
          'Match Schedule',
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
            onPressed: _fetchTournamentsAndMatches,
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
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(color: const Color(0xFFE76F51), fontSize: 16), // Error
                        textAlign: TextAlign.center,
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