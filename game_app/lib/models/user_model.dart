import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String? email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String? profileImage;
  final String? gender;
  final String role; // 'player', 'organizer', 'umpire'
  final DateTime createdAt;

  AppUser({
    required this.uid,
    this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    this.profileImage,
    this.gender,
    required this.role,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'],
      phone: data['phone'],
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      profileImage: data['profileImage'],
      gender: data['gender'],
      role: data['role'] ?? 'player',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'firstName': firstName,
      'lastName': lastName,
      'profileImage': profileImage,
      'gender': gender,
      'role': role,
      'createdAt': createdAt,
    };
  }

  bool get isPlayer => role == 'player';
  bool get isOrganizer => role == 'organizer';
  bool get isUmpire => role == 'umpire';
}