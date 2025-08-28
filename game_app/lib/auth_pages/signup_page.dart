import 'dart:async';
import 'dart:io' show Platform; // Added for platform detection
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/auth_pages/basic_info_page.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:toastification/toastification.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // Firebase App Check

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final List<TextEditingController> _otpControllers;
  AuthBloc? _authBloc;

  bool _usePhone = false;
  bool _showOtpField = false;
  String? _verificationId;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  String? _selectedRole;
  final List<String> _availableRoles = ['player', 'organizer', 'umpire'];

  CountryCode _selectedCountry = CountryCode(
    code: 'IN',
    name: 'India',
    dialCode: '+91',
  );

  final Color _darkBackground = const Color(0xFF121212);
  final Color _primaryColor = const Color(0xFF6C9A8B);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = const Color(0xFFC1DADB);
  final Color _inputBackground = const Color(0xFF1E1E1E);

  late AnimationController _logoController;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _passwordController.addListener(_validatePasswordConstraints);
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
    _testFirestoreConnectivity();
    _initializeAppCheck(); // Initialize App Check
  }

  Future<void> _initializeAppCheck() async {
    try {
      if (Platform.isIOS) {
        
        await FirebaseAppCheck.instance.activate(
          appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,  );
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
      _selectedRole = null;
      _hasMinLength = false;
      _hasUppercase = false;
      _hasNumber = false;
      _hasSpecialChar = false;
    });
    debugPrint('All signup data reset');
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
    super.dispose();
  }

  Future<void> _testFirestoreConnectivity() async {
    try {
      await FirebaseFirestore.instance.collection('test').doc('connectivity').set({
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
    if (!RegExp(r'[A-Z]').hasMatch(password)) return 'Must have uppercase letter';
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

  String? _validateEmail(String email) {
    if (email.isEmpty) return null;
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

  Future<bool> _checkFieldUniqueness(String field, String value, {String? excludeUid}) async {
    try {
      if (field == 'phone') value = _normalizePhoneNumber(value);
      final querySnapshot = await FirebaseFirestore.instance
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

  void _navigateToBasicInfoPage(String uid, bool isPhoneSignup, String email, String phone, String role) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BasicInfoPage(
          uid: uid,
          isPhoneSignup: isPhoneSignup,
          email: email,
          phone: phone,
          role: role,
        ),
      ),
    );
  }

  void _navigateBasedOnRole(String role, AppUser appUser) {
    if (!mounted) return;
    if (appUser.isProfileComplete) {
      String route;
      switch (role) {
        case 'player':
          route = '/player';
          break;
        case 'organizer':
          route = '/organizer';
          break;
        case 'umpire':
          route = '/umpire';
          break;
        default:
          route = '/login';
      }
      Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
    } else {
      _navigateToBasicInfoPage(appUser.uid, appUser.phone != null, appUser.email ?? '', appUser.phone ?? '', appUser.role);
    }
  }

  Future<void> _handleSignupButtonPress() async {
    if (!mounted || _isLoading || _authBloc == null) return;

    try {
      if (_selectedRole == null) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please select your role'),
          autoCloseDuration: const Duration(seconds: 2),
        );
        return;
      }

      if (_usePhone) {
        await _handlePhoneSignup();
      } else {
        if (_formKey.currentState!.validate()) {
          await _handleEmailSignup();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('handleSignupButtonPress error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Signup Error'),
          description: Text('Error: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _handleEmailSignup() async {
    if (_authBloc == null) return;
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final confirmPassword = _confirmPasswordController.text;

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

      _authBloc!.add(
        AuthSignupEvent(
          email: email,
          password: password,
          role: _selectedRole!,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('handleEmailSignup error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Email Signup Error'),
          description: Text('Error: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<void> _handlePhoneSignup() async {
    if (!mounted || _authBloc == null) return;

    setState(() => _isLoading = true);
    try {
      if (!_showOtpField) {
        final phone = _normalizePhoneNumber(_phoneController.text.trim());
        final phoneError = _validatePhone(phone);

        if (phoneError != null) {
          if (mounted) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Validation Error'),
              description: Text(phoneError),
              autoCloseDuration: const Duration(seconds: 2),
            );
          }
          return;
        }

        final isPhoneUnique = await _checkFieldUniqueness('phone', phone);
        if (!isPhoneUnique) {
          if (mounted) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Validation Error'),
              description: const Text('Phone number already in use. Please login.'),
              autoCloseDuration: const Duration(seconds: 2),
            );
          }
          return;
        }

        _authBloc!.add(AuthPhoneStartEvent(phone, true, role: _selectedRole!));
      } else {
        final otp = _otpControllers.map((c) => c.text).join();
        if (otp.length != 6 || _verificationId == null) {
          if (mounted) {
            setState(() => _isLoading = false);
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Validation Error'),
              description: const Text('Enter a valid 6-digit OTP'),
              autoCloseDuration: const Duration(seconds: 2),
            );
          }
          return;
        }

        _authBloc!.add(AuthPhoneVerifyEvent(_verificationId!, otp, true, role: _selectedRole!));
      }
    } catch (e, stackTrace) {
      debugPrint('handlePhoneSignup error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Phone Signup Error'),
          description: Text('Error: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Widget _buildBackButton() {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: _textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimationConfiguration.staggeredList(
      position: 1,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: GoogleFonts.poppins(
                  color: _textColor,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Join us and start your journey',
                style: GoogleFonts.poppins(
                  color: _secondaryTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return AnimationConfiguration.staggeredList(
      position: 2,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _inputBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _secondaryTextColor.withOpacity(0.2)),
                  ),
                  child: ToggleButtons(
                    isSelected: [_usePhone == false, _usePhone],
                    onPressed: (index) {
                      setState(() {
                        _usePhone = index == 1;
                        _showOtpField = false;
                        _verificationId = null;
                        _resetAllData();
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: _textColor,
                    fillColor: _primaryColor.withOpacity(0.8),
                    borderColor: Colors.transparent,
                    selectedBorderColor: _primaryColor,
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 120,
                    ),
                    children: [
                      Text(
                        'Email',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                      Text(
                        'Phone',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!_usePhone) ...[
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  _buildConfirmPasswordField(),
                  const SizedBox(height: 16),
                  _buildPasswordRequirements(),
                ] else ...[
                  if (!_showOtpField) ...[
                    _buildPhoneInput(),
                  ] else ...[
                    _buildOtpFields(_otpControllers),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      style: GoogleFonts.poppins(color: _textColor),
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: GoogleFonts.poppins(color: _secondaryTextColor),
        filled: true,
        fillColor: _inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        prefixIcon: Icon(Icons.email, color: _secondaryTextColor),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: GoogleFonts.poppins(color: _textColor),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: GoogleFonts.poppins(color: _secondaryTextColor),
        filled: true,
        fillColor: _inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        prefixIcon: Icon(Icons.lock, color: _secondaryTextColor),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: _secondaryTextColor,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 8) {
          return 'Password must be at least 8 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: GoogleFonts.poppins(color: _textColor),
      decoration: InputDecoration(
        labelText: 'Confirm Password',
        labelStyle: GoogleFonts.poppins(color: _secondaryTextColor),
        filled: true,
        fillColor: _inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2),
        ),
        prefixIcon: Icon(Icons.lock, color: _secondaryTextColor),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
            color: _secondaryTextColor,
          ),
          onPressed: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password Requirements:',
          style: GoogleFonts.poppins(
            color: _secondaryTextColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildRequirement('At least 8 characters', _hasMinLength),
        _buildRequirement('Contains uppercase', _hasUppercase),
        _buildRequirement('Contains number', _hasNumber),
        _buildRequirement('Contains special character', _hasSpecialChar),
      ],
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle,
          size: 16,
          color: isMet ? Colors.green : _secondaryTextColor,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            color: isMet ? Colors.green : _secondaryTextColor,
            fontSize: 12,
          ),
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
              color: _secondaryTextColor,
              fontSize: 16,
            ),
            searchDecoration: InputDecoration(
              hintText: 'Search country...',
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
          child: TextFormField(
            controller: _phoneController,
            style: GoogleFonts.poppins(color: _textColor),
            keyboardType: TextInputType.phone,
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
                borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.2)),
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              return null;
            },
          ),
        ),
      ],
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
          child: TextFormField(
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
                borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return ' ';
              }
              return null;
            },
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

  Widget _buildRoleSelection() {
    return AnimationConfiguration.staggeredList(
      position: 3,
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
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableRoles.map((role) => ChoiceChip(
                  label: Text(
                    role.toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: _selectedRole == role ? _textColor : _secondaryTextColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: _selectedRole == role,
                  selectedColor: _primaryColor,
                  backgroundColor: _inputBackground,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _secondaryTextColor.withOpacity(0.2)),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedRole = selected ? role : null;
                    });
                    debugPrint('Selected role: $_selectedRole');
                  },
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return AnimationConfiguration.staggeredList(
      position: 4,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignupButtonPress,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoading ? Colors.grey : _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _usePhone
                          ? (_showOtpField ? 'Verify OTP' : 'Send OTP')
                          : 'Sign Up',
                      style: GoogleFonts.poppins(
                        color: _textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return AnimationConfiguration.staggeredList(
      position: 7,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: GoogleFonts.poppins(
                  color: _secondaryTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text(
                  'Log In',
                  style: GoogleFonts.poppins(
                    color: _primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) async {
        if (state is AuthLoading) {
          setState(() => _isLoading = true);
        } else if (state is AuthPhoneCodeSent) {
          setState(() {
            _isLoading = false;
            _showOtpField = true;
            _verificationId = state.verificationId;
          });
          toastification.show(
            context: context,
            type: ToastificationType.success,
            title: const Text('OTP Sent'),
            description: Text('Code sent to ${_normalizePhoneNumber(_phoneController.text.trim())}'),
            autoCloseDuration: const Duration(seconds: 2),
          );
        } else if (state is AuthAuthenticated) {
          setState(() => _isLoading = false);
          final user = state.user;

          if (state.appUser != null && state.appUser!.isProfileComplete) {
            _navigateBasedOnRole(state.appUser!.role, state.appUser!);
          } else {
            _navigateToBasicInfoPage(
              user.uid,
              _usePhone,
              _usePhone ? '' : _emailController.text.trim(),
              _usePhone ? _normalizePhoneNumber(_phoneController.text.trim()) : '',
              _selectedRole!,
            );
          }
        } else if (state is AuthError) {
          setState(() => _isLoading = false);
          if (mounted) {
            toastification.show(
              context: context,
              type: ToastificationType.error,
              title: const Text('Authentication Error'),
              description: Text(state.message),
              autoCloseDuration: const Duration(seconds: 2),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: _darkBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: AnimationConfiguration.synchronized(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackButton(),
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildSignupForm(),
                  const SizedBox(height: 24),
                  _buildRoleSelection(),
                  const SizedBox(height: 24),
                  _buildSignupButton(),
                  const SizedBox(height: 24),
                  _buildLoginPrompt(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmailVerificationPage extends StatefulWidget {
  final firebase_auth.User user;
  final void Function(String) onVerified; // Explicitly define as void Function(String)

  const EmailVerificationPage({
    super.key,
    required this.user,
    required this.onVerified,
  });

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> with TickerProviderStateMixin {
  bool _isLoading = false;
  final Color _darkBackground = const Color(0xFF121212);
  final Color _primaryColor = const Color(0xFF6C9A8B);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = const Color(0xFFC1DADB);

  late AnimationController _verificationController;
  late Animation<double> _verificationAnimation;

  @override
  void initState() {
    super.initState();
    _verificationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _verificationAnimation = CurvedAnimation(
      parent: _verificationController,
      curve: Curves.fastOutSlowIn,
    );
    _sendVerificationEmail();
    _verificationController.forward();
  }

  @override
  void dispose() {
    _verificationController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await widget.user.sendEmailVerification();
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.info,
          title: const Text('Verification Email Sent'),
          description: Text('A verification email has been sent to ${widget.user.email ?? 'unknown'}'),
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

  Future<bool> _checkEmailVerification() async {
    if (_isLoading || !mounted) return false;
    setState(() => _isLoading = true);
    try {
      await widget.user.reload();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      body: SafeArea(
        child: Center(
          child: ScaleTransition(
            scale: _verificationAnimation,
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: _darkBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.email_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verify Your Email',
                    style: GoogleFonts.poppins(
                      color: _textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'A verification email has been sent to ${widget.user.email ?? 'unknown'}',
                    style: GoogleFonts.poppins(
                      color: _secondaryTextColor,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
                          onPressed: _sendVerificationEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Resend Email',
                            style: GoogleFonts.poppins(
                              color: _textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  bool isVerified = await _checkEmailVerification();
                                  if (isVerified && mounted) {
                                    widget.onVerified(widget.user.uid); // Pass uid to callback
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'I Have Verified',
                                  style: GoogleFonts.poppins(
                                    color: _textColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      firebase_auth.FirebaseAuth.instance.signOut();
                      context.read<AuthBloc>().add(AuthLogoutEvent());
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}