import 'package:equatable/equatable.dart';

abstract class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

class FetchCourtsEvent extends BookingEvent {}

class BookCourtEvent extends BookingEvent {
  final String courtId;
  final DateTime startTime;
  final String userId;

  const BookCourtEvent(this.courtId, this.startTime, this.userId);

  @override
  List<Object?> get props => [courtId, startTime, userId];
}