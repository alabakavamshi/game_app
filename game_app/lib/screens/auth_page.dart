import 'dart:async';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:toastification/toastification.dart';
import 'package:geolocator/geolocator.dart';

class AuthPage extends StatefulWidget {
  final String? role;
  final bool isSignup;

  const AuthPage({super.key, this.role, this.isSignup = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}


class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final List<TextEditingController> _otpControllers;
  AuthBloc? _authBloc;

  bool _isSignup = false;
  bool _usePhone = false;
  bool _showOtpField = false;
  String? _verificationId;
  bool _isSignupFromState = false;
  final List<bool> _authModeSelection = [true, false];
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;
  bool _isVerificationInProgress = false;
  bool _isVerificationDialogShowing = false;
  bool _isPhoneLinkingInProgress = false;
  bool _isDialogOpen = false;

  String? _selectedRole;
  final List<String> _availableRoles = ['player', 'organizer', 'umpire'];

  late AnimationController _logoController;
  late AnimationController _verificationController;
  late Animation<double> _verificationAnimation;

  int _signupStep = 0;
  String? _selectedGender;
  int? _selectedProfileImageIndex;
  final List<String> _genders = [
    'Male',
    'Female',
    'Other',
    'Prefer not to say',
  ];
  final List<String> _profileImages = [
    'assets/sketch1.jpg',
    'assets/sketch2.jpeg',
    'assets/sketch3.jpeg',
    'assets/sketch4.jpeg',
  ];

  CountryCode _selectedCountry = CountryCode(
    code: 'IN',
    name: 'India',
    dialCode: '+91',
  );

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _isSignup = widget.isSignup;
    try {
      _passwordController.addListener(_validatePasswordConstraints);

      _logoController = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this,
      )..forward();

      _verificationController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      );
      _verificationAnimation = CurvedAnimation(
        parent: _verificationController,
        curve: Curves.fastOutSlowIn,
      );

      if (widget.role != null && _availableRoles.contains(widget.role)) {
        _selectedRole = widget.role;
      }

      _testFirestoreConnectivity();
    } catch (e, stackTrace) {
      debugPrint('initState error: $e\nStack: $stackTrace');
    }
  }

  void _initializeControllers() {
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _otpControllers = List.generate(6, (_) => TextEditingController());
  }

  void _resetAllData() {
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    for (var controller in _otpControllers) {
      controller.clear();
    }
    setState(() {
      _showOtpField = false;
      _verificationId = null;
      _selectedRole =
          widget.role != null && _availableRoles.contains(widget.role)
              ? widget.role
              : null;
      _selectedGender = null;
      _selectedProfileImageIndex = null;
      _signupStep = 0;
      _isSignupFromState = false;
      _hasMinLength = false;
      _hasUppercase = false;
      _hasNumber = false;
      _hasSpecialChar = false;
    });
    debugPrint('All auth data reset');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authBloc = context.read<AuthBloc>();
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePasswordConstraints);
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    _logoController.dispose();
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _testFirestoreConnectivity() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('Firestore test skipped - user not authenticated');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'testTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('Firestore connectivity test successful');
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore connectivity test failed: ${e.code} - ${e.message}',
      );
      if (mounted) {
        if (e.code == 'permission-denied') {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Permission Denied'),
            description: const Text(
              'You don\'t have permission to access this data',
            ),
            autoCloseDuration: const Duration(seconds: 5),
          );
        } else {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Firestore Connection Failed'),
            description: Text('Error: ${e.message}'),
            autoCloseDuration: const Duration(seconds: 5),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Firestore connectivity test failed: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Connection Error'),
          description: Text('Failed to connect to Firestore: $e'),
          autoCloseDuration: const Duration(seconds: 5),
        );
      }
    }
  }

  void _validatePasswordConstraints() {
    if (!mounted) return;
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
      _hasNumber = RegExp(r'[0-9]').hasMatch(password);
      _hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    });
  }

  String? _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Must have uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) return 'Must have number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Must have special character';
    }
    return null;
  }

  String _normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (!phone.startsWith(_selectedCountry.dialCode as Pattern)) {
      return '${_selectedCountry.dialCode}$phone';
    }
    return phone;
  }

  Widget _buildPhoneInput() {
    return AnimationConfiguration.staggeredList(
      position: 2,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: CountryCodePicker(
                  onChanged: (CountryCode country) {
                    setState(() {
                      _selectedCountry = country;
                    });
                  },
                  initialSelection: 'IN',
                  favorite: ['+91', 'IN'],
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  alignLeft: false,
                  textStyle: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  dialogTextStyle: GoogleFonts.poppins(
                    color: const Color.fromARGB(255, 240, 202, 202),
                    fontSize: 16,
                  ),
                  searchDecoration: InputDecoration(
                    hintText: 'Search country...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  dialogBackgroundColor: const Color.fromARGB(255, 0, 0, 0),
                  backgroundColor: const Color.fromARGB(0, 4, 4, 4),
                  flagWidth: 25,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(width: 1),
              Expanded(
                child: _buildModernTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  isPhone: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String email) {
    if (email.isEmpty) return null; // Email is optional for phone signup
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(email)) return 'Invalid email format';
    return null;
  }

  String? _validatePhone(String phone) {
    phone = _normalizePhoneNumber(phone);
    if (phone.isEmpty) return 'Phone number cannot be empty';
    if (phone.length < 8 || phone.length > 15) {
      return 'Invalid phone number length';
    }
    if (!RegExp(r'^\+[0-9]{1,4}[0-9]{7,14}$').hasMatch(phone)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  Future<bool> _checkFieldUniqueness(
    String field,
    String value, {
    String? excludeUid,
  }) async {
    try {
      if (field == 'phone') value = _normalizePhoneNumber(value);
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where(field, isEqualTo: value.trim())
              .get();
      if (excludeUid != null) {
        return querySnapshot.docs.every((doc) => doc.id != excludeUid);
      }
      return querySnapshot.docs.isEmpty;
    } catch (e, stackTrace) {
      debugPrint('checkFieldUniqueness error: $e\nStack: $stackTrace');
      return false;
    }
  }

  Future<void> _sendVerificationEmail(firebase_auth.User user) async {
    try {
      await user.sendEmailVerification();
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.info,
          title: const Text('Verification Email Sent'),
          description: Text(
            'A verification email has been sent to ${user.email ?? 'unknown'}',
          ),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('sendVerificationEmail error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error Sending Verification Email'),
          description: Text('Failed to send verification email: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = _emailController.text.trim();
    if (_validateEmail(email) != null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Validation Error'),
        description: const Text('Please enter a valid email address'),
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }

    try {
      await firebase_auth.FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Password Reset Email Sent'),
          description: Text('A password reset email has been sent to $email'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('sendPasswordResetEmail error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to send password reset email: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<bool> _checkEmailVerification(firebase_auth.User user) async {
    if (_isVerificationInProgress || !mounted) return false;
    setState(() => _isVerificationInProgress = true);
    try {
      await user.reload();
      final updatedUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (updatedUser != null && updatedUser.emailVerified) {
        debugPrint('Email verified for UID: ${updatedUser.uid}');
        return true;
      } else {
        if (mounted) {
          toastification.show(
            context: context,
            type: ToastificationType.warning,
            title: const Text('Email Not Verified'),
            description: const Text('Your email is still not verified'),
            autoCloseDuration: const Duration(seconds: 2),
          );
        }
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('checkEmailVerification error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Verification Error'),
          description: Text('Failed to check verification status: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isVerificationInProgress = false);
    }
  }

  Future<Map<String, double?>?> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      debugPrint(
        'Location fetched: ${position.latitude}, ${position.longitude}',
      );
      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (e, stackTrace) {
      debugPrint('Failed to fetch location: $e\nStack: $stackTrace');
      return null;
    }
  }

  void _showEmailVerificationDialog(firebase_auth.User user) {
    if (_isVerificationDialogShowing || !mounted || _isDialogOpen) return;
    _isVerificationDialogShowing = true;
    _verificationController.forward();
    _sendVerificationEmail(user);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => WillPopScope(
            onWillPop: () async {
              _isVerificationDialogShowing = false;
              return true;
            },
            child: ScaleTransition(
              scale: _verificationAnimation,
              child: Dialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B263B),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: Tween(begin: 0.0, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _verificationController,
                            curve: const Interval(
                              0.0,
                              0.5,
                              curve: Curves.elasticOut,
                            ),
                          ),
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Colors.cyanAccent, Colors.blueAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.email_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Verify Your Email',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.cyanAccent.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'A verification email has been sent to ${user.email ?? 'unknown'}',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 16,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildModernButton(
                            text: 'Resend Email',
                            gradient: const LinearGradient(
                              colors: [Colors.orangeAccent, Colors.orange],
                            ),
                            onPressed:
                                () async => await _sendVerificationEmail(user),
                          ),
                          _buildModernButton(
                            text:
                                _isVerificationInProgress
                                    ? 'Verifying...'
                                    : 'I Have Verified',
                            gradient: const LinearGradient(
                              colors: [Colors.cyanAccent, Colors.blueAccent],
                            ),
                            onPressed:
                                _isVerificationInProgress
                                    ? null
                                    : () async {
                                      bool isVerified =
                                          await _checkEmailVerification(user);
                                      if (isVerified && mounted) {
                                        Navigator.of(context).pop();
                                        if (_isSignupFromState) {
                                          await _collectEmailSignupDetails(
                                            context,
                                            user.uid,
                                          );
                                        } else {
                                          _checkAndCompleteMissingDetails(
                                            user.uid,
                                          );
                                        }
                                      }
                                    },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          firebase_auth.FirebaseAuth.instance.signOut();
                          _authBloc?.add(AuthLogoutEvent());
                          if (mounted) Navigator.pop(context);
                        },
                        child: Text(
                          'Sign Out',
                          style: GoogleFonts.poppins(
                            color: Colors.redAccent,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    ).then((_) => _isVerificationDialogShowing = false);
  }

  Future<void> _checkAndCompleteMissingDetails(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        debugPrint(
          'User document not found for UID: $uid, waiting for profile creation',
        );
        return;
      }

      final data = userDoc.data()!;
      final bool isMissingDetails =
          data['firstName'] == null ||
          data['lastName'] == null ||
          (data['phone'] == null || data['phone'].isEmpty) ||
          data['profileImage'] == null ||
          data['gender'] == null;

      if (isMissingDetails && !_isDialogOpen) {
        debugPrint('Missing details for UID: $uid, showing completion dialog');
        if (_usePhone) {
          await _collectPhoneSignupDetails(
            context,
            uid,
            data['role'] ?? _selectedRole!,
          );
        } else {
          await _collectEmailSignupDetails(context, uid);
        }
      } else {
        _navigateBasedOnRole(uid);
      }
    } catch (e, stackTrace) {
      debugPrint(
        'checkAndCompleteMissingDetails error: $e\nStack: $stackTrace',
      );
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to check user details: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  void _navigateBasedOnRole(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final data = userDoc.data()!;
      final role = data['role'] ?? 'player';

      if (mounted) {
        debugPrint('Navigating to $role home for UID: $uid');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/$role', (route) => false);
      }
    } catch (e, stackTrace) {
      debugPrint('navigateBasedOnRole error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Navigation Error'),
          description: Text('Error: $e. Please complete your profile.'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _handleAuthButtonPress() async {
    if (!mounted || _isPhoneLinkingInProgress || _authBloc == null) return;
    try {
      if (_isSignup && _selectedRole == null) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please select your role'),
          autoCloseDuration: const Duration(seconds: 2),
        );
        debugPrint('Role required');
        return;
      }
      if (_usePhone) {
        await _handlePhoneAuth();
      } else {
        await _handleEmailAuth();
      }
    } catch (e, stackTrace) {
      debugPrint('handleAuthButtonPress error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Auth Error'),
          description: Text('Error: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _handleEmailAuth() async {
    if (_authBloc == null) return;
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final confirmPassword = _confirmPasswordController.text;

      if (email.isEmpty) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please enter your email'),
          autoCloseDuration: const Duration(seconds: 2),
        );
        debugPrint('Email empty');
        return;
      }

      if (password.isEmpty) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please enter your password'),
          autoCloseDuration: const Duration(seconds: 2),
        );
        debugPrint('Password empty');
        return;
      }

      final emailError = _validateEmail(email);
      if (emailError != null) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: Text(emailError),
          autoCloseDuration: const Duration(seconds: 2),
        );
        debugPrint('Email error: $emailError');
        return;
      }

      final passwordError = _validatePassword(password);
      if (passwordError != null) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: Text(passwordError),
          autoCloseDuration: const Duration(seconds: 2),
        );
        debugPrint('Password error: $passwordError');
        return;
      }

      if (_isSignup) {
        if (confirmPassword.isEmpty) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: const Text('Please confirm your password'),
            autoCloseDuration: const Duration(seconds: 2),
          );
          debugPrint('Confirm password empty');
          return;
        }

        if (password != confirmPassword) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: const Text('Passwords do not match'),
            autoCloseDuration: const Duration(seconds: 2),
          );
          debugPrint('Password mismatch');
          return;
        }

        final isEmailUnique = await _checkFieldUniqueness('email', email);
        if (!isEmailUnique) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: const Text('Email already in use. Please login.'),
            autoCloseDuration: const Duration(seconds: 2),
          );
          debugPrint('Email already in use: $email');
          return;
        }

        setState(() => _isSignupFromState = true);
        _authBloc!.add(
          AuthSignupEvent(
            email: email,
            password: password,
            role: _selectedRole!,
          ),
        );
      } else {
        setState(() => _isSignupFromState = false);
        _authBloc!.add(
          AuthLoginEvent(email: email, password: password, role: widget.role),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('handleEmailAuth error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Email Auth Error'),
          description: Text('Error: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _handlePhoneAuth() async {
    if (!mounted || _isPhoneLinkingInProgress || _authBloc == null) return;
    setState(() => _isPhoneLinkingInProgress = true);
    try {
      if (!_showOtpField) {
        final phone = _normalizePhoneNumber(_phoneController.text.trim());
        final phoneError = _validatePhone(phone);
        if (phoneError != null) {
          if (mounted) {
            setState(() => _isPhoneLinkingInProgress = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Validation Error'),
              description: Text(phoneError),
              autoCloseDuration: const Duration(seconds: 2),
            );
            debugPrint('Phone error: $phoneError');
          }
          return;
        }

        final isPhoneUnique = await _checkFieldUniqueness('phone', phone);
        if (_isSignup && !isPhoneUnique) {
          if (mounted) {
            setState(() => _isPhoneLinkingInProgress = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Validation Error'),
              description: const Text(
                'Phone number already in use. Please login with this number or use a different one.',
              ),
              autoCloseDuration: const Duration(seconds: 3),
            );
            debugPrint('Phone already in use: $phone');
          }
          return;
        }
        if (!_isSignup && isPhoneUnique) {
          if (mounted) {
            setState(() => _isPhoneLinkingInProgress = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Validation Error'),
              description: const Text(
                'No account found with this phone number. Please sign up.',
              ),
              autoCloseDuration: const Duration(seconds: 3),
            );
            debugPrint('Phone not found: $phone');
          }
          return;
        }

        await firebase_auth.FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            if (mounted) {
              try {
                final userCredential = await firebase_auth.FirebaseAuth.instance
                    .signInWithCredential(credential);
                if (_isSignup) {
                  setState(() => _isSignupFromState = true);
                  _authBloc!.add(
                    AuthRefreshProfileEvent(userCredential.user!.uid),
                  );
                } else {
                  _checkAndCompleteMissingDetails(userCredential.user!.uid);
                }
              } catch (e, stackTrace) {
                debugPrint('Auto verification error: $e\nStack: $stackTrace');
                if (mounted) {
                  toastification.show(
                    context: context,
                    type: ToastificationType.error,
                    title: const Text('Phone Auth Error'),
                    description: Text('Error: $e'),
                    autoCloseDuration: const Duration(seconds: 2),
                  );
                }
              }
            }
          },
          verificationFailed: (e) {
            if (mounted) {
              setState(() => _isPhoneLinkingInProgress = false);
              toastification.show(
                context: context,
                type: ToastificationType.error,
                title: const Text('Phone Verification Failed'),
                description: Text('Error: ${e.message}'),
                autoCloseDuration: const Duration(seconds: 2),
              );
              debugPrint('Verification failed: ${e.message} Code: ${e.code}');
            }
          },
          codeSent: (verificationId, _) {
            if (mounted) {
              setState(() {
                _verificationId = verificationId;
                _showOtpField = true;
                _isPhoneLinkingInProgress = false;
              });
              toastification.show(
                context: context,
                type: ToastificationType.success,
                title: const Text('OTP Sent'),
                description: Text('Code sent to $phone'),
                autoCloseDuration: const Duration(seconds: 2),
              );
              debugPrint(
                'Code sent to $phone, verificationId: $verificationId',
              );
            }
          },
          codeAutoRetrievalTimeout: (_) {},
        );
      } else {
        final otp = _otpControllers.map((c) => c.text).join();
        if (otp.length != 6 || _verificationId == null) {
          if (mounted) {
            setState(() => _isPhoneLinkingInProgress = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Validation Error'),
              description: const Text('Enter a valid 6-digit OTP'),
              autoCloseDuration: const Duration(seconds: 2),
            );
            debugPrint('Invalid OTP or verificationId');
          }
          return;
        }

        setState(() => _isPhoneLinkingInProgress = true);
        final credential = firebase_auth.PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: otp,
        );
        try {
          final userCredential = await firebase_auth.FirebaseAuth.instance
              .signInWithCredential(credential);
          if (_isSignup) {
            setState(() => _isSignupFromState = true);
            _authBloc!.add(AuthRefreshProfileEvent(userCredential.user!.uid));
          } else {
            _checkAndCompleteMissingDetails(userCredential.user!.uid);
          }
        } catch (e, stackTrace) {
          debugPrint('OTP verification error: $e\nStack: $stackTrace');
          if (mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('OTP Verification Failed'),
              description: Text('Error: $e'),
              autoCloseDuration: const Duration(seconds: 2),
            );
          }
        } finally {
          if (mounted) setState(() => _isPhoneLinkingInProgress = false);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('handlePhoneAuth error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isPhoneLinkingInProgress = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Phone Auth Error'),
          description: Text('Error: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _collectPhoneSignupDetails(
    BuildContext context,
    String uid,
    String role,
  ) async {
    if (!mounted || _isDialogOpen || _authBloc == null) {
      debugPrint(
        'Dialog already open or widget not mounted, skipping dialog for UID: $uid',
      );
      return;
    }
    setState(() {
      _isDialogOpen = true;
      _signupStep = 0;
    });
    debugPrint('Showing phone signup dialog for UID: $uid with role: $role');

    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    bool localObscurePhonePassword = true;
    bool localObscurePhoneConfirmPassword = true;
    bool isDialogClosing = false;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogContext) => StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                if (!mounted || isDialogClosing) return const SizedBox.shrink();

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B263B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStepIndicator(0, "Profile"),
                              _buildStepConnector(),
                              _buildStepIndicator(1, "Basic Info"),
                              _buildStepConnector(),
                              _buildStepIndicator(2, "Role"),
                              _buildStepConnector(),
                              _buildStepIndicator(3, "Email"),
                              _buildStepConnector(),
                              _buildStepIndicator(4, "Gender"),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_signupStep == 0) ...[
                            Text(
                              'Step 1: Select Profile Image',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                  ),
                              itemCount: _profileImages.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      _selectedProfileImageIndex = index;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            _selectedProfileImageIndex == index
                                                ? Colors.cyanAccent
                                                : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        _profileImages[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else if (_signupStep == 1) ...[
                            Text(
                              'Step 2: Basic Information',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildModernTextField(
                              controller: firstNameController,
                              label: 'First Name',
                              icon: Icons.person,
                            ),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: lastNameController,
                              label: 'Last Name',
                              icon: Icons.person,
                            ),
                          ] else if (_signupStep == 2) ...[
                            Text(
                              'Step 3: Select Role',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select Your Role',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children:
                                      _availableRoles
                                          .map(
                                            (role) => ChoiceChip(
                                              label: Text(
                                                role.toUpperCase(),
                                                style: GoogleFonts.poppins(
                                                  color:
                                                      _selectedRole == role
                                                          ? Colors.white
                                                          : Colors.grey,
                                                ),
                                              ),
                                              selected: _selectedRole == role,
                                              selectedColor: Colors.blueAccent,
                                              backgroundColor: Colors.white
                                                  .withOpacity(0.1),
                                              onSelected: (selected) {
                                                setDialogState(() {
                                                  _selectedRole =
                                                      selected ? role : null;
                                                });
                                                debugPrint(
                                                  'Selected role: $_selectedRole',
                                                );
                                              },
                                            ),
                                          )
                                          .toList(),
                                ),
                              ],
                            ),
                          ] else if (_signupStep == 3) ...[
                            Text(
                              'Step 4: Add Email (Optional)',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildModernTextField(
                              controller: emailController,
                              label: 'Email (Optional)',
                              icon: Icons.email,
                            ),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: passwordController,
                              label: 'Password (Required if Email is provided)',
                              icon: Icons.lock,
                              obscureText: localObscurePhonePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  localObscurePhonePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white70,
                                ),
                                onPressed:
                                    () => setDialogState(
                                      () =>
                                          localObscurePhonePassword =
                                              !localObscurePhonePassword,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: confirmPasswordController,
                              label:
                                  'Confirm Password (Required if Email is provided)',
                              icon: Icons.lock,
                              obscureText: localObscurePhoneConfirmPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  localObscurePhoneConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white70,
                                ),
                                onPressed:
                                    () => setDialogState(
                                      () =>
                                          localObscurePhoneConfirmPassword =
                                              !localObscurePhoneConfirmPassword,
                                    ),
                              ),
                            ),
                          ] else if (_signupStep == 4) ...[
                            Text(
                              'Step 5: Select Gender',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              children:
                                  _genders.map((gender) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          gender,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                          ),
                                        ),
                                        leading: Radio<String>(
                                          value: gender,
                                          groupValue: _selectedGender,
                                          onChanged: (String? value) {
                                            setDialogState(() {
                                              _selectedGender = value;
                                            });
                                          },
                                          fillColor:
                                              MaterialStateProperty.resolveWith<
                                                Color
                                              >((Set<MaterialState> states) {
                                                if (states.contains(
                                                  MaterialState.selected,
                                                )) {
                                                  return Colors.cyanAccent;
                                                }
                                                return Colors.white;
                                              }),
                                        ),
                                        tileColor: Colors.white.withOpacity(
                                          0.1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (_signupStep > 0)
                                _buildModernButton(
                                  text: 'Back',
                                  gradient: const LinearGradient(
                                    colors: [Colors.grey, Colors.grey],
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      _signupStep--;
                                      if (_signupStep == 0) {
                                        _selectedRole = null;
                                        _selectedGender = null;
                                      } else if (_signupStep == 2) {
                                        _selectedGender = null;
                                      }
                                      debugPrint('Back to step $_signupStep');
                                    });
                                  },
                                ),
                              _buildModernButton(
                                text: _signupStep < 4 ? 'Next' : 'Complete',
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.cyanAccent,
                                    Colors.blueAccent,
                                  ],
                                ),
                                onPressed: () async {
                                  if (isDialogClosing) return;
                                  if (_signupStep < 4) {
                                    if (_signupStep == 0 &&
                                        _selectedProfileImageIndex == null) {
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Validation Error'),
                                        description: const Text(
                                          'Please select a profile image',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                      return;
                                    } else if (_signupStep == 1 &&
                                        (firstNameController.text.isEmpty ||
                                            lastNameController.text.isEmpty)) {
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Validation Error'),
                                        description: const Text(
                                          'Please fill all fields',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                      return;
                                    } else if (_signupStep == 2 &&
                                        _selectedRole == null) {
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Validation Error'),
                                        description: const Text(
                                          'Please select a role',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                      return;
                                    } else if (_signupStep == 3) {
                                      if (emailController.text
                                          .trim()
                                          .isNotEmpty) {
                                        final emailError = _validateEmail(
                                          emailController.text.trim(),
                                        );
                                        if (emailError != null) {
                                          toastification.show(
                                            context: dialogContext,
                                            type: ToastificationType.error,
                                            title: const Text(
                                              'Validation Error',
                                            ),
                                            description: Text(emailError),
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                          return;
                                        }
                                        if (passwordController.text.isEmpty ||
                                            confirmPasswordController
                                                .text
                                                .isEmpty) {
                                          toastification.show(
                                            context: dialogContext,
                                            type: ToastificationType.error,
                                            title: const Text(
                                              'Validation Error',
                                            ),
                                            description: const Text(
                                              'Password and confirmation are required when email is provided',
                                            ),
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                          return;
                                        }
                                        if (passwordController.text !=
                                            confirmPasswordController.text) {
                                          toastification.show(
                                            context: dialogContext,
                                            type: ToastificationType.error,
                                            title: const Text(
                                              'Validation Error',
                                            ),
                                            description: const Text(
                                              'Passwords do not match',
                                            ),
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                          return;
                                        }
                                        final passwordError = _validatePassword(
                                          passwordController.text,
                                        );
                                        if (passwordError != null) {
                                          toastification.show(
                                            context: dialogContext,
                                            type: ToastificationType.error,
                                            title: const Text(
                                              'Validation Error',
                                            ),
                                            description: Text(passwordError),
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                          return;
                                        }
                                        final isEmailUnique =
                                            await _checkFieldUniqueness(
                                              'email',
                                              emailController.text.trim(),
                                            );
                                        if (!isEmailUnique) {
                                          toastification.show(
                                            context: dialogContext,
                                            type: ToastificationType.error,
                                            title: const Text(
                                              'Validation Error',
                                            ),
                                            description: const Text(
                                              'Email already in use. Please login with this email.',
                                            ),
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                          return;
                                        }
                                        try {
                                          final user =
                                              firebase_auth
                                                  .FirebaseAuth
                                                  .instance
                                                  .currentUser;
                                          if (user != null) {
                                            final credential = firebase_auth
                                                .EmailAuthProvider.credential(
                                              email:
                                                  emailController.text.trim(),
                                              password: passwordController.text,
                                            );
                                            await user.linkWithCredential(
                                              credential,
                                            );
                                            await _sendVerificationEmail(user);
                                          }
                                        } catch (e, stackTrace) {
                                          debugPrint(
                                            'Error linking email: $e\nStack: $stackTrace',
                                          );
                                          toastification.show(
                                            context: dialogContext,
                                            type: ToastificationType.error,
                                            title: const Text('Error'),
                                            description: Text(
                                              'Failed to link email: $e',
                                            ),
                                            autoCloseDuration: const Duration(
                                              seconds: 2,
                                            ),
                                          );
                                          return;
                                        }
                                      }
                                      setDialogState(() {
                                        _signupStep++;
                                        debugPrint(
                                          'Advanced to step $_signupStep',
                                        );
                                      });
                                    } else {
                                      setDialogState(() {
                                        _signupStep++;
                                        debugPrint(
                                          'Advanced to step $_signupStep',
                                        );
                                      });
                                    }
                                  } else {
                                    if (_selectedGender == null) {
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Validation Error'),
                                        description: const Text(
                                          'Please select your gender',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                      return;
                                    }
                                    try {
                                      isDialogClosing = true;
                                      final location =
                                          await _fetchUserLocation();
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .set({
                                            'email':
                                                emailController.text
                                                        .trim()
                                                        .isEmpty
                                                    ? ''
                                                    : emailController.text
                                                        .trim(),
                                            'firstName':
                                                firstNameController.text.trim(),
                                            'lastName':
                                                lastNameController.text.trim(),
                                            'phone': _normalizePhoneNumber(
                                              _phoneController.text.trim(),
                                            ),
                                            'role': _selectedRole ?? role,
                                            'gender': _selectedGender,
                                            'profileImage':
                                                _profileImages[_selectedProfileImageIndex!],
                                            'location': location,
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));
                                      debugPrint(
                                        'User details saved for UID: $uid with role: $_selectedRole',
                                      );
                                      Navigator.pop(dialogContext);
                                      if (mounted) {
                                        _authBloc!.add(
                                          AuthRefreshProfileEvent(uid),
                                        );
                                        _navigateBasedOnRole(uid);
                                      }
                                    } catch (e, stackTrace) {
                                      debugPrint(
                                        'Error saving profile: $e\n$stackTrace',
                                      );
                                      isDialogClosing = false;
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Error'),
                                        description: Text(
                                          'Failed to save profile: $e',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      );
    } catch (e, stackTrace) {
      debugPrint('collectPhoneSignupDetails error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to collect phone signup details: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } finally {
      emailController.dispose();
      passwordController.dispose();
      confirmPasswordController.dispose();
      firstNameController.dispose();
      lastNameController.dispose();
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
          _isSignupFromState = false;
          _signupStep = 0;
          _selectedGender = null;
          _selectedProfileImageIndex = null;
        });
      }
      debugPrint('Dialog closed for UID: $uid');
    }
  }

  Future<void> _collectEmailSignupDetails(
    BuildContext context,
    String uid,
  ) async {
    if (!mounted || _isDialogOpen || _authBloc == null) {
      debugPrint(
        'Dialog already open or widget not mounted, skipping email dialog for UID: $uid',
      );
      return;
    }
    setState(() {
      _isDialogOpen = true;
      _signupStep = 0;
    });
    debugPrint(
      'Showing email signup dialog for UID: $uid with role: $_selectedRole',
    );

    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();
    final List<TextEditingController> otpControllers = List.generate(
      6,
      (_) => TextEditingController(),
    );
    String? verificationId;
    bool isPhoneVerifying = false;
    bool isDialogClosing = false;

    try {
      await showDialog(
        context: context,
        barrierDismissible: true,
        builder:
            (dialogContext) => StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                if (!mounted || isDialogClosing) return const SizedBox.shrink();

                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B263B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildStepIndicator(0, "Profile"),
                              _buildStepConnector(),
                              _buildStepIndicator(1, "Basic Info"),
                              _buildStepConnector(),
                              _buildStepIndicator(2, "Phone"),
                              _buildStepConnector(),
                              _buildStepIndicator(3, "Gender"),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (_signupStep == 0) ...[
                            Text(
                              'Step 1: Select Profile Image',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                  ),
                              itemCount: _profileImages.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      _selectedProfileImageIndex = index;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            _selectedProfileImageIndex == index
                                                ? Colors.cyanAccent
                                                : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        _profileImages[index],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else if (_signupStep == 1) ...[
                            Text(
                              'Step 2: Basic Information',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildModernTextField(
                              controller: firstNameController,
                              label: 'First Name',
                              icon: Icons.person,
                            ),
                            const SizedBox(height: 16),
                            _buildModernTextField(
                              controller: lastNameController,
                              label: 'Last Name',
                              icon: Icons.person,
                            ),
                          ] else if (_signupStep == 2) ...[
                            Text(
                              'Step 3: Add Phone (Optional)',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    '+91',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 1),
                                Expanded(
                                  child: _buildModernTextField(
                                    controller: phoneController,
                                    label: 'Phone Number (Optional)',
                                    icon: Icons.phone,
                                    keyboardType: TextInputType.phone,
                                    isPhone: true,
                                  ),
                                ),
                              ],
                            ),
                            if (verificationId != null) ...[
                              const SizedBox(height: 16),
                              _buildOtpFields(otpControllers),
                            ],
                            const SizedBox(height: 20),
                            if (verificationId == null)
                              _buildModernButton(
                                text:
                                    isPhoneVerifying
                                        ? 'Sending...'
                                        : 'Send OTP',
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.cyanAccent,
                                    Colors.blueAccent,
                                  ],
                                ),
                                onPressed:
                                    isPhoneVerifying
                                        ? null
                                        : () async {
                                          final phone = _normalizePhoneNumber(
                                            phoneController.text.trim(),
                                          );
                                          final phoneError = _validatePhone(
                                            phone,
                                          );
                                          if (phoneError != null) {
                                            toastification.show(
                                              context: dialogContext,
                                              type: ToastificationType.error,
                                              title: const Text(
                                                'Validation Error',
                                              ),
                                              description: Text(phoneError),
                                              autoCloseDuration: const Duration(
                                                seconds: 2,
                                              ),
                                            );
                                            return;
                                          }
                                          final isPhoneUnique =
                                              await _checkFieldUniqueness(
                                                'phone',
                                                phone,
                                                excludeUid: uid,
                                              );
                                          if (!isPhoneUnique) {
                                            toastification.show(
                                              context: dialogContext,
                                              type: ToastificationType.error,
                                              title: const Text(
                                                'Validation Error',
                                              ),
                                              description: const Text(
                                                'Phone number already in use by another account. Please login with this number.',
                                              ),
                                              autoCloseDuration: const Duration(
                                                seconds: 2,
                                              ),
                                            );
                                            return;
                                          }
                                          setDialogState(
                                            () => isPhoneVerifying = true,
                                          );
                                          await firebase_auth
                                              .FirebaseAuth
                                              .instance
                                              .verifyPhoneNumber(
                                                phoneNumber: phone,
                                                timeout: const Duration(
                                                  seconds: 60,
                                                ),
                                                verificationCompleted: (
                                                  credential,
                                                ) async {
                                                  final user =
                                                      firebase_auth
                                                          .FirebaseAuth
                                                          .instance
                                                          .currentUser;
                                                  if (user != null &&
                                                      mounted &&
                                                      !isDialogClosing) {
                                                    try {
                                                      await user
                                                          .linkWithCredential(
                                                            credential,
                                                          );
                                                      setDialogState(() {
                                                        _signupStep++;
                                                        debugPrint(
                                                          'Phone linked, advanced to step $_signupStep',
                                                        );
                                                      });
                                                    } catch (e, stackTrace) {
                                                      debugPrint(
                                                        'Auto phone link error: $e\nStack: $stackTrace',
                                                      );
                                                      toastification.show(
                                                        context: dialogContext,
                                                        type:
                                                            ToastificationType
                                                                .error,
                                                        title: const Text(
                                                          'Phone Link Error',
                                                        ),
                                                        description: Text(
                                                          'Error: $e',
                                                        ),
                                                        autoCloseDuration:
                                                            const Duration(
                                                              seconds: 2,
                                                            ),
                                                      );
                                                    }
                                                  }
                                                },
                                                verificationFailed: (e) {
                                                  setDialogState(
                                                    () =>
                                                        isPhoneVerifying =
                                                            false,
                                                  );
                                                  toastification.show(
                                                    context: dialogContext,
                                                    type:
                                                        ToastificationType
                                                            .error,
                                                    title: const Text(
                                                      'Phone Verification Failed',
                                                    ),
                                                    description: Text(
                                                      'Error: ${e.message}',
                                                    ),
                                                    autoCloseDuration:
                                                        const Duration(
                                                          seconds: 2,
                                                        ),
                                                  );
                                                  debugPrint(
                                                    'Phone verification failed: ${e.message}',
                                                  );
                                                },
                                                codeSent: (verId, _) {
                                                  setDialogState(() {
                                                    verificationId = verId;
                                                    isPhoneVerifying = false;
                                                  });
                                                  debugPrint(
                                                    'Code sent to $phone, verificationId: $verId',
                                                  );
                                                },
                                                codeAutoRetrievalTimeout:
                                                    (_) {},
                                              );
                                        },
                              )
                            else
                              _buildModernButton(
                                text:
                                    isPhoneVerifying
                                        ? 'Verifying...'
                                        : 'Verify OTP',
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.cyanAccent,
                                    Colors.blueAccent,
                                  ],
                                ),
                                onPressed:
                                    isPhoneVerifying
                                        ? null
                                        : () async {
                                          final otp =
                                              otpControllers
                                                  .map((c) => c.text)
                                                  .join();
                                          if (otp.length != 6 ||
                                              verificationId == null) {
                                            toastification.show(
                                              context: dialogContext,
                                              type: ToastificationType.error,
                                              title: const Text(
                                                'Validation Error',
                                              ),
                                              description: const Text(
                                                'Enter a valid 6-digit OTP',
                                              ),
                                              autoCloseDuration: const Duration(
                                                seconds: 2,
                                              ),
                                            );
                                            return;
                                          }
                                          setDialogState(
                                            () => isPhoneVerifying = true,
                                          );
                                          final credential = firebase_auth
                                              .PhoneAuthProvider.credential(
                                            verificationId: verificationId!,
                                            smsCode: otp,
                                          );
                                          try {
                                            final user =
                                                firebase_auth
                                                    .FirebaseAuth
                                                    .instance
                                                    .currentUser;
                                            if (user != null &&
                                                !isDialogClosing) {
                                              await user.linkWithCredential(
                                                credential,
                                              );
                                              setDialogState(() {
                                                _signupStep++;
                                                debugPrint(
                                                  'Phone linked, advanced to step $_signupStep',
                                                );
                                              });
                                            }
                                          } catch (e, stackTrace) {
                                            debugPrint(
                                              'OTP verification error: $e\nStack: $stackTrace',
                                            );
                                            toastification.show(
                                              context: dialogContext,
                                              type: ToastificationType.error,
                                              title: const Text(
                                                'OTP Verification Failed',
                                              ),
                                              description: Text('Error: $e'),
                                              autoCloseDuration: const Duration(
                                                seconds: 2,
                                              ),
                                            );
                                          } finally {
                                            setDialogState(
                                              () => isPhoneVerifying = false,
                                            );
                                          }
                                        },
                              ),
                          ] else if (_signupStep == 3) ...[
                            Text(
                              'Step 4: Select Gender',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              children:
                                  _genders.map((gender) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          gender,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                          ),
                                        ),
                                        leading: Radio<String>(
                                          value: gender,
                                          groupValue: _selectedGender,
                                          onChanged: (String? value) {
                                            setDialogState(() {
                                              _selectedGender = value;
                                            });
                                          },
                                          fillColor:
                                              MaterialStateProperty.resolveWith<
                                                Color
                                              >((Set<MaterialState> states) {
                                                if (states.contains(
                                                  MaterialState.selected,
                                                )) {
                                                  return Colors.cyanAccent;
                                                }
                                                return Colors.white;
                                              }),
                                        ),
                                        tileColor: Colors.white.withOpacity(
                                          0.1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              if (_signupStep > 0)
                                _buildModernButton(
                                  text: 'Back',
                                  gradient: const LinearGradient(
                                    colors: [Colors.grey, Colors.grey],
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      if (_signupStep == 2) {
                                        verificationId = null;
                                        for (var controller in otpControllers) {
                                          controller.clear();
                                        }
                                      }
                                      _signupStep--;
                                      if (_signupStep == 0) {
                                        _selectedRole = null;
                                        _selectedGender = null;
                                      } else if (_signupStep == 1) {
                                        _selectedGender = null;
                                      }
                                      debugPrint('Back to step $_signupStep');
                                    });
                                  },
                                ),
                              _buildModernButton(
                                text: _signupStep < 3 ? 'Next' : 'Complete',
                                gradient: const LinearGradient(
                                  colors: [
                                    Colors.cyanAccent,
                                    Colors.blueAccent,
                                  ],
                                ),
                                onPressed: () async {
                                  if (isDialogClosing) return;
                                  if (_signupStep < 3) {
                                    if (_signupStep == 0 &&
                                        _selectedProfileImageIndex == null) {
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Validation Error'),
                                        description: const Text(
                                          'Please select a profile image',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                      return;
                                    } else if (_signupStep == 1 &&
                                        (firstNameController.text.isEmpty ||
                                            lastNameController.text.isEmpty)) {
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Validation Error'),
                                        description: const Text(
                                          'Please fill all required fields',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                      return;
                                    } else if (_signupStep == 2 &&
                                        phoneController.text.trim().isEmpty) {
                                      setDialogState(() {
                                        _signupStep++;
                                        debugPrint(
                                          'No phone provided, skipping to step $_signupStep',
                                        );
                                      });
                                    } else {
                                      setDialogState(() {
                                        _signupStep++;
                                        debugPrint(
                                          'Advanced to step $_signupStep',
                                        );
                                      });
                                    }
                                  } else {
                                    if (_selectedGender == null) {
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Validation Error'),
                                        description: const Text(
                                          'Please select your gender',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                      return;
                                    }
                                    try {
                                      isDialogClosing = true;
                                      final location =
                                          await _fetchUserLocation();
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .set({
                                            'email':
                                                _emailController.text.trim(),
                                            'firstName':
                                                firstNameController.text.trim(),
                                            'lastName':
                                                lastNameController.text.trim(),
                                            'phone':
                                                phoneController.text.isEmpty
                                                    ? ''
                                                    : _normalizePhoneNumber(
                                                      phoneController.text
                                                          .trim(),
                                                    ),
                                            'role': _selectedRole!,
                                            'gender': _selectedGender,
                                            'profileImage':
                                                _profileImages[_selectedProfileImageIndex!],
                                            'location': location,
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));
                                      debugPrint(
                                        'User details saved for UID: $uid with role: $_selectedRole',
                                      );
                                      Navigator.pop(dialogContext);
                                      if (mounted) {
                                        _authBloc!.add(
                                          AuthRefreshProfileEvent(uid),
                                        );
                                        _navigateBasedOnRole(uid);
                                      }
                                    } catch (e, stackTrace) {
                                      debugPrint(
                                        'Error saving profile: $e\n$stackTrace',
                                      );
                                      isDialogClosing = false;
                                      toastification.show(
                                        context: dialogContext,
                                        type: ToastificationType.error,
                                        title: const Text('Error'),
                                        description: Text(
                                          'Failed to save profile: $e',
                                        ),
                                        autoCloseDuration: const Duration(
                                          seconds: 2,
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      );
    } catch (e, stackTrace) {
      debugPrint('collectEmailSignupDetails error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to collect email signup details: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } finally {
      firstNameController.dispose();
      lastNameController.dispose();
      phoneController.dispose();
      for (var controller in otpControllers) {
        controller.dispose();
      }
      if (mounted) {
        setState(() {
          _isDialogOpen = false;
          _isSignupFromState = false;
          _signupStep = 0;
          _selectedGender = null;
          _selectedProfileImageIndex = null;
        });
      }
      debugPrint('Email dialog closed for UID: $uid');
    }
  }

  Widget _buildRoleSelection() {
    return AnimationConfiguration.staggeredList(
      position: 6,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Your Role',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    _availableRoles
                        .map(
                          (role) => ChoiceChip(
                            label: Text(
                              role.toUpperCase(),
                              style: GoogleFonts.poppins(
                                color:
                                    _selectedRole == role
                                        ? Colors.white
                                        : Colors.grey,
                              ),
                            ),
                            selected: _selectedRole == role,
                            selectedColor: Colors.blueAccent,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            onSelected: (selected) {
                              setState(() {
                                _selectedRole = selected ? role : null;
                              });
                              debugPrint('Selected role: $_selectedRole');
                            },
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    bool isPhone = false,
  }) {
    return AnimationConfiguration.staggeredList(
      position: 2,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: _modernInputDecoration(
              label,
              isPhone: isPhone,
            ).copyWith(suffixIcon: suffixIcon),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpFields(List<TextEditingController> controllers) {
    if (controllers.length != 6) {
      debugPrint('OTP controllers list is invalid, reinitializing');
      controllers.clear();
      controllers.addAll(List.generate(6, (_) => TextEditingController()));
    }

    return AnimationConfiguration.staggeredList(
      position: 2,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 50,
                child: TextField(
                  controller: controllers[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLength: 1,
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.cyanAccent,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.length == 1 && index < 5) {
                      FocusScope.of(context).nextFocus();
                    } else if (value.isEmpty && index > 0) {
                      FocusScope.of(context).previousFocus();
                    }
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildModernButton({
    required String text,
    required LinearGradient gradient,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child:
            isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Text(
                  text,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
      ),
    );
  }

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.cancel,
          size: 16,
          color: isMet ? Colors.greenAccent : Colors.redAccent,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            color: isMet ? Colors.white70 : Colors.redAccent,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  InputDecoration _modernInputDecoration(String label, {bool isPhone = false}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius:
            isPhone
                ? const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                )
                : BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            isPhone
                ? const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                )
                : BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            isPhone
                ? const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                )
                : BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
      ),
    );
  }

  Widget _buildStepIndicator(int stepNumber, String label) {
    return Column(
      children: [
        Container(
          width: 25,
          height: 25,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _signupStep == stepNumber ? Colors.cyanAccent : Colors.grey,
          ),
          child: Center(
            child: Text(
              (stepNumber + 1).toString(),
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector() {
    return Container(
      width: 30,
      height: 2,
      color: Colors.grey,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthLoading) {
            debugPrint('Auth loading state');
          } else if (state is AuthAuthenticated) {
            debugPrint('Authenticated with UID: ${state.user.uid}');
            if (_isSignupFromState && !_usePhone) {
              final user = firebase_auth.FirebaseAuth.instance.currentUser;
              if (user != null && !user.emailVerified) {
                _showEmailVerificationDialog(user);
              } else {
                await _collectEmailSignupDetails(context, state.user.uid);
              }
            } else if (!_isSignupFromState) {
              await _checkAndCompleteMissingDetails(state.user.uid);
            }
          } else if (state is AuthError) {
            debugPrint('Auth error: ${state.message}');
            if (mounted) {
              toastification.show(
                context: context,
                type: ToastificationType.error,
                title: const Text('Authentication Error'),
                description: Text(state.message),
                autoCloseDuration: const Duration(seconds: 2),
              );
            }
          } else if (state is AuthUnauthenticated) {
            debugPrint('Unauthenticated state');
            _resetAllData();
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: AnimationLimiter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 500),
                    childAnimationBuilder:
                        (widget) => SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(child: widget),
                        ),
                    children: [
                      Center(
                        child: Text(
                          _isSignup ? 'Create Account' : 'Welcome Back',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _isSignup
                              ? 'Join us and start your journey!'
                              : 'Login to continue your journey',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: ToggleButtons(
                          isSelected: _authModeSelection,
                          onPressed: (index) {
                            setState(() {
                              _usePhone = index == 1;
                              _authModeSelection[0] = !_usePhone;
                              _authModeSelection[1] = _usePhone;
                              _showOtpField = false;
                              _verificationId = null;
                              _resetAllData();
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          selectedColor: Colors.white,
                          fillColor: Colors.blueAccent.withOpacity(0.8),
                          borderColor: Colors.white.withOpacity(0.2),
                          selectedBorderColor: Colors.cyanAccent,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Text(
                                'Email',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              child: Text(
                                'Phone',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_usePhone) ...[
                        _buildModernTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email,
                        ),
                        const SizedBox(height: 16),
                        _buildModernTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          ),
                        ),
                        if (_isSignup) ...[
                          const SizedBox(height: 16),
                          _buildModernTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirm Password',
                            icon: Icons.lock,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              _buildPasswordRequirement(
                                'At least 8 characters',
                                _hasMinLength,
                              ),
                              _buildPasswordRequirement(
                                'Contains uppercase letter',
                                _hasUppercase,
                              ),
                              _buildPasswordRequirement(
                                'Contains number',
                                _hasNumber,
                              ),
                              _buildPasswordRequirement(
                                'Contains special character',
                                _hasSpecialChar,
                              ),
                            ],
                          ),
                        ],
                      ] else ...[
                        _buildPhoneInput(),
                        if (_showOtpField) ...[
                          const SizedBox(height: 16),
                          _buildOtpFields(_otpControllers),
                        ],
                      ],
                      if (_isSignup) ...[
                        const SizedBox(height: 16),
                        Center(child: _buildRoleSelection()),
                      ],
                      const SizedBox(height: 20),
                      Center(
                        child: _buildModernButton(
                          text:
                              _isPhoneLinkingInProgress
                                  ? 'Processing...'
                                  : _showOtpField
                                  ? 'Verify OTP'
                                  : _isSignup
                                  ? 'Sign Up'
                                  : 'Login',
                          gradient: const LinearGradient(
                            colors: [Colors.cyanAccent, Colors.blueAccent],
                          ),
                          isLoading: _isPhoneLinkingInProgress,
                          onPressed:
                              _isPhoneLinkingInProgress
                                  ? null
                                  : _handleAuthButtonPress,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!_isSignup && !_usePhone)
                        Center(
                          child: TextButton(
                            onPressed: _sendPasswordResetEmail,
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.poppins(
                                color: Colors.cyanAccent,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isSignup = !_isSignup;
                              _resetAllData();
                            });
                          },
                          child: Text(
                            _isSignup
                                ? 'Already have an account? Login'
                                : 'Don\'t have an account? Sign Up',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}