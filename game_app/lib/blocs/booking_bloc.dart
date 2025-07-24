import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/booking_event.dart';
import 'package:game_app/blocs/booking_state.dart';
import 'package:game_app/models/court.dart';
import 'package:game_app/widgets/court_repository.dart';

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final CourtRepository _repository;

  BookingBloc() : _repository = CourtRepository(), super(BookingInitial()) {
    on<FetchCourtsEvent>(_onFetchCourts);
    on<BookCourtEvent>(_onBookCourt);
  }

  Future<void> _onFetchCourts(FetchCourtsEvent event, Emitter<BookingState> emit) async {
    emit(BookingLoading());
    try {
      final courts = await _repository.fetchCourts();
      emit(BookingLoaded(courts));
    } catch (e) {
      emit(BookingError('Failed to fetch courts: $e'));
    }
  }

  Future<void> _onBookCourt(BookCourtEvent event, Emitter<BookingState> emit) async {
    if (state is BookingLoaded) {
      final currentState = state as BookingLoaded;
      final court = currentState.courts.firstWhere((c) => c.id == event.courtId);
      final slot = court.availableSlots.firstWhere((s) => s.startTime == event.startTime);

      if (slot.isBooked) {
        emit(BookingError('This slot is already booked.'));
        return;
      }

      try {
        // Update Firestore
        await _repository.bookCourt(event.courtId, event.startTime, event.userId);

        // Update local state
        final updatedCourts = currentState.courts.map((court) {
          if (court.id == event.courtId) {
            final updatedSlots = court.availableSlots.map((slot) {
              if (slot.startTime == event.startTime && !slot.isBooked) {
                return slot.copyWith(isBooked: true, bookedBy: event.userId);
              }
              return slot;
            }).toList();
            return Court(
              id: court.id,
              name: court.name,
              type: court.type,
              venue: court.venue,
              city: court.city,
              availableSlots: updatedSlots,
              createdBy: court.createdBy,
              createdAt: court.createdAt,
            );
          }
          return court;
        }).toList();

        emit(BookingLoaded(updatedCourts));
      } catch (e) {
        emit(BookingError('Failed to book court: $e'));
      }
    }
  }
}