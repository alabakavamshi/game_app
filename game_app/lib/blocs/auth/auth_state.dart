import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:game_app/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final AppUser? appUser; // Changed to nullable

  const AuthAuthenticated(this.user, {this.appUser});

  @override
  List<Object?> get props => [user.uid, appUser];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

class AuthPhoneCodeSent extends AuthState {
  final String verificationId;
  final bool isSignup;
  final int? resendToken;

  const AuthPhoneCodeSent(this.verificationId, this.isSignup, this.resendToken);

  @override
  List<Object?> get props => [verificationId, isSignup, resendToken];
}