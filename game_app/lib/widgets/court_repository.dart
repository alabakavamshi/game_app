import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:game_app/models/court.dart';

class CourtRepository {
  final CollectionReference _courtsCollection =
      FirebaseFirestore.instance.collection('courts');

  Future<List<Court>> fetchCourts() async {
    final snapshot = await _courtsCollection.get();
    return snapshot.docs.map((doc) => Court.fromFirestore(doc)).toList();
  }

  Future<void> bookCourt(String courtId, DateTime startTime, String userId) async {
    final courtRef = _courtsCollection.doc(courtId);
    final courtDoc = await courtRef.get();
    final court = Court.fromFirestore(courtDoc);

    final updatedSlots = court.availableSlots.map((slot) {
      if (slot.startTime == startTime && !slot.isBooked) {
        return slot.copyWith(isBooked: true, bookedBy: userId);
      }
      return slot;
    }).toList();

    await courtRef.update({
      'availableSlots': updatedSlots.map((slot) => slot.toFirestore()).toList(),
    });
  }

  Future<void> addCourt(Court court) async {
    await _courtsCollection.doc(court.id).set(court.toFirestore());
  }
}