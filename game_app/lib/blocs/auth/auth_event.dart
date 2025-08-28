import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckEvent extends AuthEvent {}

class AuthLoginEvent extends AuthEvent {
  final String email;
  final String password;
  final String? role;

  const AuthLoginEvent({
    required this.email,
    required this.password,
    this.role,
  });

  @override
  List<Object?> get props => [email, password, role];
}

class AuthSignupEvent extends AuthEvent {
  final String email;
  final String password;
  final String role;

  const AuthSignupEvent({
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [email, password, role];
}

class AuthPhoneStartEvent extends AuthEvent {
  final String phoneNumber;
  final bool isSignup;
  final String? role;

  const AuthPhoneStartEvent(
    this.phoneNumber,
    this.isSignup, {
    this.role,
  });

  @override
  List<Object?> get props => [phoneNumber, isSignup, role];
}

class AuthPhoneVerifyEvent extends AuthEvent {
  final String verificationId;
  final String smsCode;
  final bool isSignup;
  final String? role;

  const AuthPhoneVerifyEvent(
    this.verificationId,
    this.smsCode,
    this.isSignup, {
    this.role,
  });

  @override
  List<Object?> get props => [verificationId, smsCode, isSignup, role];
}

class AuthLinkPhoneCredentialEvent extends AuthEvent {
  final firebase_auth.AuthCredential credential;

  const AuthLinkPhoneCredentialEvent(this.credential);

  @override
  List<Object?> get props => [credential];
}

class AuthLinkEmailCredentialEvent extends AuthEvent {
  final firebase_auth.AuthCredential credential;

  const AuthLinkEmailCredentialEvent(this.credential);

  @override
  List<Object?> get props => [credential];
}

class AuthRefreshProfileEvent extends AuthEvent {
  final String uid;

  const AuthRefreshProfileEvent(this.uid);

  @override
  List<Object?> get props => [uid];
}

class AuthLogoutEvent extends AuthEvent {}

class AuthStateChangedEvent extends AuthEvent {
  final firebase_auth.User? user;

  const AuthStateChangedEvent(this.user);

  @override
  List<Object?> get props => [user];
}