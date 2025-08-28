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
  final DateTime? createdAt; // Allow nullable
  final bool isProfileComplete; // New field

  AppUser({
    required this.uid,
    this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    this.profileImage,
    this.gender,
    required this.role,
    this.createdAt,
    required this.isProfileComplete, // Required field
  });

  factory AppUser.fromMap(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      profileImage: data['profileImage'] as String?,
      gender: data['gender'] as String?,
      role: data['role'] ?? 'player',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      isProfileComplete: data['isProfileComplete'] ?? false,
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isProfileComplete': isProfileComplete,
    };
  }

  bool get isPlayer => role == 'player';
  bool get isOrganizer => role == 'organizer';
  bool get isUmpire => role == 'umpire';
}