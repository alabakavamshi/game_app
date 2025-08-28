import 'dart:async';
import 'dart:io' show Platform; // Added for platform detection
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:toastification/toastification.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // Added for App Check

class LoginPage extends StatefulWidget {
  final String? role;

  const LoginPage({super.key, this.role});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final List<TextEditingController> _otpControllers;
  AuthBloc? _authBloc;

  bool _usePhone = false;
  bool _showOtpField = false;
  String? _verificationId;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isDialogOpen = false;
  int _signupStep = 0;

  final List<bool> _authModeSelection = [true, false];

  CountryCode _selectedCountry = CountryCode(
    code: 'IN',
    name: 'India',
    dialCode: '+91',
  );

  // Color palette
  final Color _darkBackground = const Color(0xFF121212);
  final Color _primaryColor = const Color(0xFF6C9A8B);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = const Color(0xFFC1DADB);
  final Color _inputBackground = const Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _testFirestoreConnectivity();
    _initializeAppCheck(); // Initialize App Check
  }

  Future<void> _initializeAppCheck() async {
    try {
      if (Platform.isIOS) {
        // For iOS, use App Attest (iOS 14.0+) with fallback to DeviceCheck
        await FirebaseAppCheck.instance.activate(
          appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,   );
        debugPrint('App Check activated with App Attest for iOS');
      } else if (Platform.isAndroid) {
        // For Android, use Play Integrity
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity, // Use Play Integrity for production
          // androidProvider: AndroidProvider.debug, // Uncomment for debug builds (requires debug token)
        );
        debugPrint('App Check activated with Play Integrity for Android');
      } else {
        debugPrint('Platform not supported for App Check');
      }
    } catch (e) {
      debugPrint('App Check activation failed: $e');
    }
  }

  void _initializeControllers() {
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _otpControllers = List.generate(6, (_) => TextEditingController());
  }

  void _resetAllData() {
    _emailController.clear();
    _phoneController.clear();
    _passwordController.clear();
    for (var controller in _otpControllers) {
      controller.clear();
    }
    setState(() {
      _showOtpField = false;
      _verificationId = null;
      _signupStep = 0;
      _isLoading = false;
    });
    debugPrint('All login data reset');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authBloc = context.read<AuthBloc>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
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

  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Email cannot be empty';
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

  String _normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (!phone.startsWith(_selectedCountry.dialCode as Pattern)) {
      return '${_selectedCountry.dialCode}$phone';
    }
    return phone;
  }

  Future<bool> _checkFieldUniqueness(String field, String value) async {
    try {
      if (field == 'phone') value = _normalizePhoneNumber(value);
      debugPrint('Checking uniqueness for $field: $value');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: value.trim())
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint(
                'Firestore uniqueness query timed out for $field: $value',
              );
              throw Exception('Firestore query timed out');
            },
          );
      debugPrint(
        'Uniqueness check result for $field: ${querySnapshot.docs.isEmpty ? 'Unique' : 'Not unique'}',
      );
      return querySnapshot.docs.isEmpty;
    } catch (e, stackTrace) {
      debugPrint('checkFieldUniqueness error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to check $field uniqueness: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      return false;
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

  Future<void> _checkAndCompleteMissingDetails(String uid) async {
    debugPrint('Checking missing details for UID: $uid');
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      debugPrint('User document exists: ${userDoc.exists}');

      if (!userDoc.exists) {
        debugPrint(
          'User document not found for UID: $uid, triggering profile creation',
        );
        await _collectMissingDetails(context, uid);
        return;
      }

      final data = userDoc.data()!;
      debugPrint('User data: $data');
      final bool isMissingDetails =
          data['firstName'] == null ||
          data['lastName'] == null ||
          (data['phone'] == null || data['phone'].isEmpty) ||
          data['profileImage'] == null ||
          data['gender'] == null;

      if (isMissingDetails && !_isDialogOpen) {
        debugPrint(
          'Missing details detected, showing completion dialog for UID: $uid',
        );
        await _collectMissingDetails(context, uid);
      } else {
        debugPrint('All details present, navigating for UID: $uid');
        _navigateBasedOnRole(uid);
      }
    } catch (e, stackTrace) {
      debugPrint(
        'checkAndCompleteMissingDetails error: $e\nStack: $stackTrace',
      );
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to check user details: $e'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _collectMissingDetails(BuildContext context, String uid) async {
    if (!mounted || _isDialogOpen || _authBloc == null) {
      debugPrint(
        'Dialog already open or widget not mounted, skipping dialog for UID: $uid',
      );
      return;
    }
    setState(() => _isDialogOpen = true);

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
    String? selectedGender;
    int? selectedProfileImageIndex;

    final List<String> genders = [
      'Male',
      'Female',
      'Other',
      'Prefer not to say',
    ];
    final List<String> profileImages = [
      'assets/sketch1.jpg',
      'assets/sketch2.jpeg',
      'assets/sketch3.jpeg',
      'assets/sketch4.jpeg',
    ];

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
                      color: _darkBackground,
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
                                color: _textColor,
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
                              itemCount: profileImages.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      selectedProfileImageIndex = index;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            selectedProfileImageIndex == index
                                                ? _primaryColor
                                                : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        profileImages[index],
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
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: firstNameController,
                              style: GoogleFonts.poppins(color: _textColor),
                              decoration: InputDecoration(
                                labelText: 'First Name',
                                labelStyle: GoogleFonts.poppins(
                                  color: _secondaryTextColor,
                                ),
                                filled: true,
                                fillColor: _inputBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _secondaryTextColor.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _primaryColor,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: _secondaryTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: lastNameController,
                              style: GoogleFonts.poppins(color: _textColor),
                              decoration: InputDecoration(
                                labelText: 'Last Name',
                                labelStyle: GoogleFonts.poppins(
                                  color: _secondaryTextColor,
                                ),
                                filled: true,
                                fillColor: _inputBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _secondaryTextColor.withOpacity(0.2),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: _primaryColor,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: _secondaryTextColor,
                                ),
                              ),
                            ),
                          ] else if (_signupStep == 2) ...[
                            Text(
                              'Step 3: Add Phone (Optional)',
                              style: GoogleFonts.poppins(
                                color: _textColor,
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
                                    color: _inputBackground,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      bottomLeft: Radius.circular(12),
                                    ),
                                    border: Border.all(
                                      color: _secondaryTextColor.withOpacity(
                                        0.2,
                                      ),
                                    ),
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
                                      color: _textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    dialogTextStyle: GoogleFonts.poppins(
                                      color: _textColor,
                                      fontSize: 16,
                                    ),
                                    searchDecoration: InputDecoration(
                                      hintText: 'Search country...',
                                      hintStyle: GoogleFonts.poppins(
                                        color: _secondaryTextColor,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    dialogBackgroundColor: _darkBackground,
                                    backgroundColor: Colors.transparent,
                                    flagWidth: 25,
                                  ),
                                ),
                                const SizedBox(width: 1),
                                Expanded(
                                  child: TextField(
                                    controller: phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: GoogleFonts.poppins(
                                      color: _textColor,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Phone Number (Optional)',
                                      labelStyle: GoogleFonts.poppins(
                                        color: _secondaryTextColor,
                                      ),
                                      filled: true,
                                      fillColor: _inputBackground,
                                      border: OutlineInputBorder(
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        borderSide: BorderSide(
                                          color: _secondaryTextColor
                                              .withOpacity(0.2),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                          bottomRight: Radius.circular(12),
                                        ),
                                        borderSide: BorderSide(
                                          color: _primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                      prefixIcon: Icon(
                                        Icons.phone,
                                        color: _secondaryTextColor,
                                      ),
                                    ),
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
                                              );
                                          if (!isPhoneUnique) {
                                            toastification.show(
                                              context: dialogContext,
                                              type: ToastificationType.error,
                                              title: const Text(
                                                'Validation Error',
                                              ),
                                              description: const Text(
                                                'Phone number already in use by another account.',
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
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Column(
                              children:
                                  genders.map((gender) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: ListTile(
                                        title: Text(
                                          gender,
                                          style: GoogleFonts.poppins(
                                            color: _textColor,
                                          ),
                                        ),
                                        leading: Radio<String>(
                                          value: gender,
                                          groupValue: selectedGender,
                                          onChanged: (String? value) {
                                            setDialogState(() {
                                              selectedGender = value;
                                            });
                                          },
                                          fillColor:
                                              MaterialStateProperty.resolveWith<
                                                Color
                                              >((Set<MaterialState> states) {
                                                if (states.contains(
                                                  MaterialState.selected,
                                                )) {
                                                  return _primaryColor;
                                                }
                                                return _textColor;
                                              }),
                                        ),
                                        tileColor: _inputBackground,
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
                                  onPressed: () {
                                    setDialogState(() {
                                      if (_signupStep == 2) {
                                        verificationId = null;
                                        for (var controller in otpControllers) {
                                          controller.clear();
                                        }
                                      }
                                      _signupStep--;
                                      if (_signupStep == 0 ||
                                          _signupStep == 1) {
                                        selectedGender = null;
                                      }
                                      debugPrint('Back to step $_signupStep');
                                    });
                                  },
                                ),
                              _buildModernButton(
                                text: _signupStep < 3 ? 'Next' : 'Complete',
                                onPressed: () async {
                                  if (isDialogClosing) return;
                                  if (_signupStep < 3) {
                                    if (_signupStep == 0 &&
                                        selectedProfileImageIndex == null) {
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
                                    if (selectedGender == null) {
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
                                            'gender': selectedGender,
                                            'profileImage':
                                                profileImages[selectedProfileImageIndex!],
                                            'location': location,
                                            'createdAt':
                                                FieldValue.serverTimestamp(),
                                            'role': widget.role ?? 'player',
                                          }, SetOptions(merge: true));
                                      debugPrint(
                                        'User details saved for UID: $uid',
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
      debugPrint('collectMissingDetails error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to collect missing details: $e'),
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
        setState(() => _isDialogOpen = false);
      }
      debugPrint('Dialog closed for UID: $uid');
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

  void _navigateBasedOnRole(String uid) async {
    debugPrint('Navigating based on role for UID: $uid');
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Firestore user doc fetch timed out for UID: $uid');
              throw Exception('Firestore query timed out');
            },
          );
      if (!userDoc.exists) {
        debugPrint(
          'User document not found for UID: $uid, triggering profile creation',
        );
        await _collectMissingDetails(context, uid);
        return;
      }

      final data = userDoc.data()!;
      final role = data['role'] ?? 'player';
      debugPrint('User role: $role');

      if (mounted) {
        debugPrint('Navigating to /$role for UID: $uid');
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/$role', (route) => false);
      } else {
        debugPrint('Widget not mounted, skipping navigation for UID: $uid');
      }
    } catch (e, stackTrace) {
      debugPrint('navigateBasedOnRole error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Navigation Error'),
          description: Text('Error: $e. Please complete your profile.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _handleLoginButtonPress() async {
    debugPrint('=== LOGIN BUTTON PRESSED ===');
    debugPrint('usePhone: $_usePhone, isLoading: $_isLoading, mounted: $mounted');

    if (!mounted || _isLoading || _authBloc == null) {
      debugPrint('Cannot proceed: mounted=$mounted, isLoading=$_isLoading, authBloc=$_authBloc');
      return;
    }

    // Set loading state AFTER all checks
    setState(() => _isLoading = true);

    try {
      if (_usePhone) {
        await _handlePhoneLogin();
      } else {
        await _handleEmailLogin();
      }
    } catch (e, stackTrace) {
      debugPrint('Login error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Login Error'),
          description: Text('Error: ${e.toString()}'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _handlePhoneLogin() async {
    debugPrint('=== PHONE LOGIN STARTED ===');
    debugPrint('mounted: $mounted, isLoading: $_isLoading, authBloc: $_authBloc, showOtpField: $_showOtpField');

    // Only check for critical errors, not isLoading
    if (!mounted) {
      debugPrint('Widget not mounted, aborting phone login');
      return;
    }

    if (_authBloc == null) {
      debugPrint('AuthBloc is null, aborting phone login');
      setState(() => _isLoading = false);
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('System Error'),
        description: const Text('Authentication service not available'),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return;
    }

    debugPrint('Phone login processing started');

    try {
      if (!_showOtpField) {
        await _sendOtp();
      } else {
        await _verifyOtp();
      }
    } catch (e, stackTrace) {
      debugPrint('Phone login error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Phone Auth Error'),
          description: Text('Unexpected error: ${e.toString()}'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _handleEmailLogin() async {
    if (_authBloc == null) return;
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (email.isEmpty) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please enter your email'),
          autoCloseDuration: const Duration(seconds: 2),
        );
        debugPrint('Email empty');
        setState(() => _isLoading = false);
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
        setState(() => _isLoading = false);
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
        setState(() => _isLoading = false);
        return;
      }

      _authBloc!.add(
        AuthLoginEvent(email: email, password: password, role: widget.role),
      );
    } catch (e, stackTrace) {
      debugPrint('handleEmailLogin error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _sendOtp() async {
    final phone = _normalizePhoneNumber(_phoneController.text.trim());
    debugPrint('Sending OTP to: $phone');

    if (phone.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please enter a phone number'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
      return;
    }

    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: Text(phoneError),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      return;
    }

    // Check if phone exists in database
    try {
      final isPhoneUnique = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone.trim())
          .get()
          .then((snapshot) => snapshot.docs.isEmpty);

      if (isPhoneUnique) {
        if (mounted) {
          setState(() => _isLoading = false);
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Account Not Found'),
            description: const Text('No account found with this phone number. Please sign up.'),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Phone check error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Connection Error'),
          description: const Text('Could not verify phone number. Please try again.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      return;
    }

    // Send OTP
    try {
      await firebase_auth.FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) async {
          debugPrint('Auto-verification completed');
          try {
            final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
            if (mounted) {
              setState(() => _isLoading = false);
              await _checkAndCompleteMissingDetails(userCredential.user!.uid);
            }
          } catch (e) {
            debugPrint('Auto-verification sign-in error: $e');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          }
        },
        verificationFailed: (e) {
          debugPrint('Verification failed: ${e.message}');
          if (mounted) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Verification Failed'),
              description: Text('Error: ${e.message}'),
              autoCloseDuration: const Duration(seconds: 3),
            );
          }
        },
        codeSent: (verificationId, _) {
          debugPrint('OTP sent successfully');
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _showOtpField = true;
              _isLoading = false;
            });
            toastification.show(
              context: context,
              type: ToastificationType.success,
              title: const Text('OTP Sent'),
              description: Text('Code sent to $phone'),
              autoCloseDuration: const Duration(seconds: 3),
            );
          }
        },
        codeAutoRetrievalTimeout: (_) {
          debugPrint('Code auto-retrieval timed out');
          if (mounted) {
            setState(() => _isLoading = false);
          }
        },
      );
    } catch (e) {
      debugPrint('OTP sending error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('OTP Error'),
          description: const Text('Failed to send OTP. Please try again.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    debugPrint('Verifying OTP: $otp');

    if (otp.length != 6 || _verificationId == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please enter a valid 6-digit OTP'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
      return;
    }

    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );

      final userCredential = await firebase_auth.FirebaseAuth.instance.signInWithCredential(credential);
      debugPrint('OTP verification successful for UID: ${userCredential.user?.uid}');

      if (mounted) {
        setState(() => _isLoading = false);
        await _checkAndCompleteMissingDetails(userCredential.user!.uid);
      }
    } catch (e) {
      debugPrint('OTP verification error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Verification Failed'),
          description: const Text('Invalid OTP. Please try again.'),
          autoCloseDuration: const Duration(seconds: 3),
        );
      }
    }
  }

  Widget _buildBackButton() {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: _textColor),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back',
          style: GoogleFonts.poppins(
            color: _textColor,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Login to continue your journey',
          style: GoogleFonts.poppins(color: _secondaryTextColor, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: _inputBackground,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            border: Border.all(color: _secondaryTextColor.withOpacity(0.2)),
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
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            dialogTextStyle: GoogleFonts.poppins(
              color: _textColor,
              fontSize: 16,
            ),
            searchDecoration: InputDecoration(
              hintText: 'Search country...',
              hintStyle: GoogleFonts.poppins(color: _secondaryTextColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            dialogBackgroundColor: _darkBackground,
            backgroundColor: Colors.transparent,
            flagWidth: 25,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.poppins(color: _textColor),
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: GoogleFonts.poppins(color: _secondaryTextColor),
              filled: true,
              fillColor: _inputBackground,
              border: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                borderSide: BorderSide(
                  color: _secondaryTextColor.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              prefixIcon: Icon(Icons.phone, color: _secondaryTextColor),
            ),
          ),
        ),
      ],
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
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(color: _textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: _secondaryTextColor),
        filled: true,
        fillColor: _inputBackground,
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
          borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              isPhone
                  ? const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  )
                  : BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        prefixIcon: Icon(icon, color: _secondaryTextColor),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildOtpFields(List<TextEditingController> controllers) {
    if (controllers.length != 6) {
      debugPrint('OTP controllers list is invalid, reinitializing');
      controllers.clear();
      controllers.addAll(List.generate(6, (_) => TextEditingController()));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          child: TextField(
            controller: controllers[index],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: _textColor,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            maxLength: 1,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: _inputBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _secondaryTextColor.withOpacity(0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
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
    );
  }

  Widget _buildModernButton({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _primaryColor,
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
          padding: const EdgeInsets.symmetric(vertical: 16),
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
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
      ),
    );
  }

  Widget _buildSignupPrompt() {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.of(context).pushReplacementNamed('/signup');
        },
        child: RichText(
          text: TextSpan(
            text: 'Don\'t have an account? ',
            style: GoogleFonts.poppins(color: _secondaryTextColor),
            children: [
              TextSpan(
                text: 'Sign Up',
                style: GoogleFonts.poppins(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
      backgroundColor: _darkBackground,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthLoading) {
            debugPrint('Auth loading state');
          } else if (state is AuthAuthenticated) {
            debugPrint('Authenticated with UID: ${state.user.uid}');
            setState(() => _isLoading = false);
            await _checkAndCompleteMissingDetails(state.user.uid);
          } else if (state is AuthError) {
            debugPrint('Auth error: ${state.message}');
            if (mounted) {
              setState(() => _isLoading = false);
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
            setState(() => _isLoading = false);
            _resetAllData();
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),
                const SizedBox(height: 20),

                _buildHeader(),
                const SizedBox(height: 40),
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
                    selectedColor: _textColor,
                    fillColor: _primaryColor.withOpacity(0.8),
                    borderColor: _secondaryTextColor.withOpacity(0.2),
                    selectedBorderColor: _primaryColor,
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
                            color: _textColor,
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
                            color: _textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                        color: _secondaryTextColor,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _sendPasswordResetEmail,
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.poppins(
                          color: _primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  if (!_showOtpField) ...[
                    _buildPhoneInput(),
                  ] else ...[
                    _buildOtpFields(_otpControllers),
                  ],
                ],
                const SizedBox(height: 24),
                _buildModernButton(
                  text:
                      _isLoading
                          ? 'Processing...'
                          : _usePhone && _showOtpField
                          ? 'Verify OTP'
                          : 'Log In',
                  onPressed: _isLoading ? null : _handleLoginButtonPress,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 24),

                _buildSignupPrompt(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}