import 'package:cloud_firestore/cloud_firestore.dart';

class Court {
  final String id;
  final String name;
  final String type;
  final String venue;
  final String city;
  final double? latitude;
  final double? longitude;
  final List<TimeSlot> availableSlots;
  final String createdBy;
  final DateTime createdAt;

  Court({
    required this.id,
    required this.name,
    required this.type,
    required this.venue,
    required this.city,
    this.latitude,
    this.longitude,
    required this.availableSlots,
    required this.createdBy,
    required this.createdAt,
  });

  factory Court.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Court(
      id: doc.id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      venue: data['venue'] ?? '',
      city: data['city'] ?? '',
      latitude: data['latitude'] as double?,
      longitude: data['longitude'] as double?,
      availableSlots: (data['availableSlots'] as List<dynamic>?)
          ?.map((slotData) => TimeSlot.fromFirestore(slotData as Map<String, dynamic>))
          .toList() ?? [],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type,
      'venue': venue,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
      'availableSlots': availableSlots.map((slot) => slot.toFirestore()).toList(),
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class TimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final bool isBooked;
  final String? bookedBy;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.isBooked = false,
    this.bookedBy,
  });

  factory TimeSlot.fromFirestore(Map<String, dynamic> data) {
    return TimeSlot(
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      isBooked: data['isBooked'] as bool? ?? false,
      bookedBy: data['bookedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'isBooked': isBooked,
      'bookedBy': bookedBy,
    };
  }

  TimeSlot copyWith({bool? isBooked, String? bookedBy}) {
    return TimeSlot(
      startTime: startTime,
      endTime: endTime,
      isBooked: isBooked ?? this.isBooked,
      bookedBy: bookedBy ?? this.bookedBy,
    );
  }
}