import 'package:equatable/equatable.dart';
import 'package:game_app/models/court.dart';

abstract class BookingState extends Equatable {
  const BookingState();

  @override
  List<Object?> get props => [];
}

class BookingInitial extends BookingState {}

class BookingLoading extends BookingState {}

class BookingLoaded extends BookingState {
  final List<Court> courts;

  const BookingLoaded(this.courts);

  @override
  List<Object?> get props => [courts];
}

class BookingError extends BookingState {
  final String message;

  const BookingError(this.message);

  @override
  List<Object?> get props => [message];
}