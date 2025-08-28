import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/models/user_model.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart'; // Added for App Check

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<firebase_auth.User?>? _authSubscription;

  AuthBloc({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _auth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        super(AuthInitial()) {
    _auth.setPersistence(firebase_auth.Persistence.LOCAL).then((_) {
      debugPrint('Firebase Auth persistence set to LOCAL');
    }).catchError((error) {
      debugPrint('Error setting persistence: $error');
    });

    on<AuthCheckEvent>(_onAuthCheck);
    on<AuthLoginEvent>(_onAuthLogin);
    on<AuthSignupEvent>(_onAuthSignup);
    on<AuthPhoneStartEvent>(_onAuthPhoneStart);
    on<AuthPhoneVerifyEvent>(_onAuthPhoneVerify);
    on<AuthLogoutEvent>(_onAuthLogout);
    on<AuthRefreshProfileEvent>(_onAuthRefreshProfile);
    on<AuthLinkPhoneCredentialEvent>(_onAuthLinkPhoneCredential);
    on<AuthLinkEmailCredentialEvent>(_onAuthLinkEmailCredential);
    on<AuthStateChangedEvent>(_onAuthStateChanged);

    _initializeAppCheck(); // Initialize App Check
    add(AuthCheckEvent());
  }

  Future<void> _initializeAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity, // Use Play Integrity for production
        // Use AndroidProvider.debug with a debug token for testing
        // appleProvider: AppleProvider.deviceCheck, // Uncomment for iOS
      );
      debugPrint('App Check activated successfully');
    } catch (e) {
      debugPrint('App Check activation failed: $e');
      // Emit an error state if App Check fails, but allow the app to proceed
      add(AuthError('App Check initialization failed: $e') as AuthEvent);
    }
  }

  Future<AppUser?> _fetchUserProfile(String uid) async {
    try {
      debugPrint('Fetching user profile for UID: $uid');
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        debugPrint('User document found: ${userDoc.data()}');
        return AppUser.fromMap(userDoc.data()!, uid);
      } else {
        debugPrint('User document not found for UID: $uid');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('Error fetching user profile: $e\nStack: $stackTrace');
      return null;
    }
  }

  Future<void> _onAuthCheck(AuthCheckEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _authSubscription?.cancel();
      _authSubscription = null;

      await Future.delayed(const Duration(seconds: 2));

      final currentUser = _auth.currentUser;
      debugPrint('Synchronous check: currentUser = $currentUser');
      if (currentUser != null) {
        final appUser = await _fetchUserProfile(currentUser.uid);
        emit(AuthAuthenticated(currentUser, appUser: appUser));
      } else {
        emit(AuthUnauthenticated());
      }

      _authSubscription = _auth.authStateChanges()
          .debounceTime(const Duration(milliseconds: 500))
          .listen((user) {
        debugPrint('authStateChanges: user = $user');
        add(AuthStateChangedEvent(user));
      }, onError: (error) {
        debugPrint('authStateChanges error: $error');
        emit(AuthError('Authentication check failed: $error'));
      });
    } catch (e, stackTrace) {
      debugPrint('AuthCheckEvent error: $e\nStack: $stackTrace');
      emit(AuthError('Failed to check authentication: $e'));
    }
  }

  Future<void> _onAuthStateChanged(AuthStateChangedEvent event, Emitter<AuthState> emit) async {
    try {
      debugPrint('authStateChanges: user = ${event.user}');
      if (event.user != null) {
        final appUser = await _fetchUserProfile(event.user!.uid);
        emit(AuthAuthenticated(event.user!, appUser: appUser));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e, stackTrace) {
      debugPrint('AuthStateChanged error: $e\nStack: $stackTrace');
      emit(AuthError('Failed to process auth state change: $e'));
    }
  }

  Future<void> _onAuthLogin(AuthLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      final appUser = await _fetchUserProfile(userCredential.user!.uid);
      if (appUser == null) {
        throw Exception('User profile not found');
      }

      if (event.role != null && appUser.role != event.role) {
        await _auth.signOut();
        throw Exception('You are not authorized to access this role');
      }

      emit(AuthAuthenticated(userCredential.user!, appUser: appUser));
    } catch (e, stackTrace) {
      debugPrint('Login error: $e\nStack: $stackTrace');
      emit(AuthError('Login failed: $e'));
    }
  }

  Future<void> _onAuthSignup(AuthSignupEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      if (!['player', 'organizer', 'umpire'].contains(event.role)) {
        throw Exception('Invalid user role');
      }

      debugPrint('Starting email signup for ${event.email} with role: ${event.role}');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );

      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': event.email,
        'role': event.role,
        'createdAt': FieldValue.serverTimestamp(),
        'isProfileComplete': false,
      });

      await userCredential.user!.sendEmailVerification();
      emit(AuthAuthenticated(userCredential.user!, appUser: null));
    } catch (e, stackTrace) {
      debugPrint('Signup error: $e\nStack: $stackTrace');
      emit(AuthError('Signup failed: $e'));
    }
  }

  Future<void> _onAuthPhoneStart(AuthPhoneStartEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    if (event.isSignup) {
      try {
        final phoneQuery = await _firestore
            .collection('users')
            .where('phone', isEqualTo: event.phoneNumber)
            .get();

        if (phoneQuery.docs.isNotEmpty) {
          emit(AuthError('This phone number is already in use'));
          return;
        }
      } catch (e, stackTrace) {
        debugPrint('Phone number check error: $e\nStack: $stackTrace');
        emit(AuthError('Error checking phone number: $e'));
        return;
      }
    }

    final completer = Completer<void>();

    try {
      debugPrint('Starting phone verification for ${event.phoneNumber}');
      await _auth.verifyPhoneNumber(
        phoneNumber: event.phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          try {
            final userCredential = await _auth.signInWithCredential(credential);
            if (userCredential.user != null) {
              if (event.isSignup) {
                await _firestore.collection('users').doc(userCredential.user!.uid).set({
                  'uid': userCredential.user!.uid,
                  'phone': userCredential.user!.phoneNumber ?? '',
                  'role': event.role ?? 'player',
                  'createdAt': FieldValue.serverTimestamp(),
                  'isProfileComplete': false,
                });
              }
              final appUser = await _fetchUserProfile(userCredential.user!.uid);
              emit(AuthAuthenticated(userCredential.user!, appUser: appUser));
            } else {
              emit(AuthError('Auto-verification failed'));
            }
          } catch (e, stackTrace) {
            debugPrint('Auto-verification error: $e\nStack: $stackTrace');
            emit(AuthError('Auto-verification failed: $e'));
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          debugPrint('Verification failed: ${e.message}');
          // Check if reCAPTCHA is triggered and suggest App Check setup
          if (e.message?.contains('reCAPTCHA') == true) {
            emit(AuthError('reCAPTCHA required. Ensure App Check is configured with Play Integrity.'));
          } else {
            emit(AuthError('Verification failed: ${e.message}'));
          }
          if (!completer.isCompleted) completer.complete();
        },
        codeSent: (String verificationId, int? resendToken) {
          emit(AuthPhoneCodeSent(verificationId, event.isSignup, resendToken));
          if (!completer.isCompleted) completer.complete();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          emit(AuthPhoneCodeSent(verificationId, event.isSignup, null));
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;
    } catch (e, stackTrace) {
      debugPrint('Phone auth error: $e\nStack: $stackTrace');
      emit(AuthError('Phone auth failed: $e'));
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _onAuthPhoneVerify(AuthPhoneVerifyEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      if (event.verificationId.isNotEmpty) {
        final credential = firebase_auth.PhoneAuthProvider.credential(
          verificationId: event.verificationId,
          smsCode: event.smsCode,
        );
        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null && event.isSignup) {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'phone': userCredential.user!.phoneNumber ?? '',
            'role': event.role ?? 'player',
            'createdAt': FieldValue.serverTimestamp(),
            'isProfileComplete': false,
          });
        }
        final appUser = await _fetchUserProfile(userCredential.user!.uid);
        emit(AuthAuthenticated(userCredential.user!, appUser: appUser));
      } else {
        final user = _auth.currentUser;
        if (user != null) {
          final appUser = await _fetchUserProfile(user.uid);
          emit(AuthAuthenticated(user, appUser: appUser));
        } else {
          emit(AuthError('Auto-verification failed'));
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Phone verification error: $e\nStack: $stackTrace');
      emit(AuthError('Phone verification failed: $e'));
    }
  }

  Future<void> _onAuthLinkPhoneCredential(AuthLinkPhoneCredentialEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(AuthError('No user signed in'));
        return;
      }

      await user.linkWithCredential(event.credential);
      await user.reload();

      final updatedUser = _auth.currentUser;
      if (updatedUser != null) {
        final appUser = await _fetchUserProfile(updatedUser.uid);
        emit(AuthAuthenticated(updatedUser, appUser: appUser));
      } else {
        emit(AuthError('Failed to link phone number'));
      }
    } catch (e, stackTrace) {
      debugPrint('Link phone credential error: $e\nStack: $stackTrace');
      emit(AuthError('Failed to link phone number: $e'));
    }
  }

  Future<void> _onAuthLinkEmailCredential(AuthLinkEmailCredentialEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(AuthError('No user signed in'));
        return;
      }

      await user.linkWithCredential(event.credential);
      await user.reload();

      final updatedUser = _auth.currentUser;
      if (updatedUser != null) {
        final appUser = await _fetchUserProfile(updatedUser.uid);
        emit(AuthAuthenticated(updatedUser, appUser: appUser));
      } else {
        emit(AuthError('Failed to link email'));
      }
    } catch (e, stackTrace) {
      debugPrint('Link email credential error: $e\nStack: $stackTrace');
      emit(AuthError('Failed to link email: $e'));
    }
  }

  Future<void> _onAuthLogout(AuthLogoutEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      debugPrint('Attempting logout');
      await _authSubscription?.cancel();
      _authSubscription = null;
      await _auth.signOut();
      debugPrint('Logout successful: Emitting AuthUnauthenticated');
      emit(AuthUnauthenticated());
    } catch (e, stackTrace) {
      debugPrint('Logout error: $e\nStack: $stackTrace');
      emit(AuthError('Failed to logout: $e'));
    }
  }

  Future<void> _onAuthRefreshProfile(AuthRefreshProfileEvent event, Emitter<AuthState> emit) async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.uid == event.uid) {
        final appUser = await _fetchUserProfile(user.uid);
        emit(AuthAuthenticated(user, appUser: appUser));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e, stackTrace) {
      debugPrint('Refresh profile error: $e\nStack: $stackTrace');
      emit(AuthError('Error refreshing profile: $e'));
    }
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}