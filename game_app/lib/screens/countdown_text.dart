// countdown_text.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CountdownText extends StatefulWidget {
  final Timestamp? matchTime;
  final Timestamp? tournamentTime;

  const CountdownText({
    super.key,
    required this.matchTime,
    required this.tournamentTime,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _buildCountdown() {
    final startTime = widget.matchTime ?? widget.tournamentTime;
    if (startTime == null) return 'Not scheduled';

    final startDateTime = startTime.toDate();
    final difference = startDateTime.difference(_now);

    if (difference.isNegative) {
      return 'Ready to start';
    }

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ${difference.inSeconds % 60}s';
    } else {
      return '${difference.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 16, color: Colors.cyanAccent),
        const SizedBox(width: 8),
        Text(
          'Starts in: ${_buildCountdown()}',
          style: GoogleFonts.poppins(
            color: Colors.cyanAccent,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}