import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

class Tournament {
  final String id;
  final String name;
  final String venue;
  final String city;
  final DateTime startDate; // UTC timestamp containing both date and time
  final DateTime? endDate;
  final double entryFee;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final List<Map<String, dynamic>> participants;
  final String? rules;
  final int maxParticipants;
  final String gameFormat;
  final String gameType;
  final bool bringOwnEquipment;
  final bool costShared;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> teams;
  final String? profileImage;
  final String timezone;

  Tournament({
    required this.id,
    required this.name,
    required this.venue,
    required this.city,
    required this.startDate,
    this.endDate,
    required this.entryFee,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.participants,
    this.rules,
    required this.maxParticipants,
    required this.gameFormat,
    required this.gameType,
    required this.bringOwnEquipment,
    required this.costShared,
    this.matches = const [],
    this.teams = const [],
    this.profileImage,
    required this.timezone,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'venue': venue,
      'city': city,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'entryFee': entryFee,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'participants': participants,
      'rules': rules,
      'maxParticipants': maxParticipants,
      'gameFormat': gameFormat,
      'gameType': gameType,
      'bringOwnEquipment': bringOwnEquipment,
      'costShared': costShared,
      'matches': matches,
      'teams': teams,
      'profileImage': profileImage,
      'timezone': timezone,
    };
  }

  factory Tournament.fromFirestore(Map<String, dynamic> data, String id) {
    final startDateTimestamp = data['startDate'] as Timestamp? ?? Timestamp.now();
    final timezoneName = data['timezone'] as String? ?? 'UTC';
   
    final startDate = startDateTimestamp.toDate();

    return Tournament(
      id: id,
      name: data['name'] ?? '',
      venue: data['venue'] ?? '',
      city: data['city'] ?? '',
      startDate: startDate,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      entryFee: (data['entryFee'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] ?? 'open',
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participants: List<Map<String, dynamic>>.from(data['participants'] ?? []),
      rules: data['rules'] as String?,
      maxParticipants: data['maxParticipants'] ?? 0,
      gameFormat: data['gameFormat'] ?? 'Singles',
      gameType: data['gameType'] ?? 'Tournament',
      bringOwnEquipment: data['bringOwnEquipment'] ?? false,
      costShared: data['costShared'] ?? false,
      matches: List<Map<String, dynamic>>.from(data['matches'] ?? []),
      teams: List<Map<String, dynamic>>.from(data['teams'] ?? []),
      profileImage: data['profileImage'] as String?,
      timezone: timezoneName,
    );
  }

  // Helper method to get TimeOfDay from startDate for display purposes
  TimeOfDay getStartTime() {
    final localStartDate = tz.TZDateTime.from(startDate, tz.getLocation(timezone));
    return TimeOfDay(hour: localStartDate.hour, minute: localStartDate.minute);
  }

  // Helper method to get formatted time string
  String getFormattedStartTime() {
    final localStartDate = tz.TZDateTime.from(startDate, tz.getLocation(timezone));
    return DateFormat('hh:mm a').format(localStartDate);
  }
}