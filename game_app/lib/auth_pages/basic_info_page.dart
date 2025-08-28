import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:game_app/auth_pages/profile_details_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:toastification/toastification.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class BasicInfoPage extends StatefulWidget {
  final String uid;
  final bool isPhoneSignup;
  final String email;
  final String phone;
  final String role;

  const BasicInfoPage({
    super.key,
    required this.uid,
    required this.isPhoneSignup,
    required this.email,
    required this.phone,
    required this.role,
  });

  @override
  State<BasicInfoPage> createState() => _BasicInfoPageState();
}

class _BasicInfoPageState extends State<BasicInfoPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  CountryCode _selectedCountry = CountryCode(code: 'IN', name: 'India', dialCode: '+91');
  String? _verificationId;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _showOtpField = false;
  bool _showPasswordFields = false;

  final Color _darkBackground = const Color(0xFF121212);
  final Color _primaryColor = const Color(0xFF6C9A8B);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = const Color(0xFFC1DADB);
  final Color _inputBackground = const Color(0xFF1E1E1E);
  final Color _errorColor = Colors.redAccent;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updatePasswordFieldsVisibility);
    if (!widget.isPhoneSignup) {
      _emailController.text = widget.email;
    }
  }

  @override
  void dispose() {
    _emailController.removeListener(_updatePasswordFieldsVisibility);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updatePasswordFieldsVisibility() {
    setState(() {
      _showPasswordFields = _emailController.text.trim().isNotEmpty;
    });
  }

  String _normalizePhoneNumber(String phone) {
    phone = phone.trim();
    if (!phone.startsWith(_selectedCountry.dialCode as Pattern)) {
      return '${_selectedCountry.dialCode}$phone';
    }
    return phone;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return null; // Email is optional
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value)) return 'Invalid email format';
    return null;
  }

  String? _validatePhone(String? value) {
    if (!widget.isPhoneSignup && (value == null || value.isEmpty)) {
      return 'Phone number is required';
    }
    if (value == null || value.isEmpty) return null; // Phone is optional for phone signup
    final phone = _normalizePhoneNumber(value);
    if (phone.length < 8 || phone.length > 15) {
      return 'Invalid phone number length';
    }
    if (!RegExp(r'^\+[0-9]{1,4}[0-9]{7,14}$').hasMatch(phone)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _showPasswordFields ? 'Password is required when email is provided' : null;
    }
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Must have uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Must have number';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Must have special character';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return _showPasswordFields ? 'Please confirm your password' : null;
    }
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<bool> _checkFieldUniqueness(String field, String value) async {
    try {
      if (field == 'phone') value = _normalizePhoneNumber(value);
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: value.trim())
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e, stackTrace) {
      debugPrint('checkFieldUniqueness error: $e\nStack: $stackTrace');
      return false;
    }
  }

  Future<void> _handleNext() async {
    if (!mounted || _isLoading) return;

    if (_formKey.currentState!.validate()) {
      if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Validation Error'),
          description: const Text('Please fill all required fields'),
          autoCloseDuration: const Duration(seconds: 2),
        );
        return;
      }

      if (widget.isPhoneSignup && _emailController.text.trim().isNotEmpty) {
        final emailError = _validateEmail(_emailController.text.trim());
        if (emailError != null) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: Text(emailError),
            autoCloseDuration: const Duration(seconds: 2),
          );
          return;
        }
        final passwordError = _validatePassword(_passwordController.text);
        if (passwordError != null) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: Text(passwordError),
            autoCloseDuration: const Duration(seconds: 2),
          );
          return;
        }
        final confirmPasswordError = _validateConfirmPassword(_confirmPasswordController.text);
        if (confirmPasswordError != null) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: Text(confirmPasswordError),
            autoCloseDuration: const Duration(seconds: 2),
          );
          return;
        }
        final isEmailUnique = await _checkFieldUniqueness('email', _emailController.text.trim());
        if (!isEmailUnique) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: const Text('Email already in use. Please login with this email.'),
            autoCloseDuration: const Duration(seconds: 2),
          );
          return;
        }
      }

      if (!widget.isPhoneSignup) {
        final phone = _normalizePhoneNumber(_phoneController.text.trim());
        final phoneError = _validatePhone(phone);
        if (phoneError != null) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: Text(phoneError),
            autoCloseDuration: const Duration(seconds: 2),
          );
          return;
        }
        final isPhoneUnique = await _checkFieldUniqueness('phone', phone);
        if (!isPhoneUnique) {
          toastification.show(
            context: context,
            type: ToastificationType.error,
            title: const Text('Validation Error'),
            description: const Text('Phone number already in use by another account.'),
            autoCloseDuration: const Duration(seconds: 2),
          );
          return;
        }
        if (!_showOtpField) {
          setState(() => _isLoading = true);
          await firebase_auth.FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: phone,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (credential) async {
              final user = firebase_auth.FirebaseAuth.instance.currentUser;
              if (user != null && mounted) {
                try {
                  await user.linkWithCredential(credential);
                  setState(() => _isLoading = false);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileDetailsPage(
                        uid: widget.uid,
                        role: widget.role,
                        firstName: _firstNameController.text.trim(),
                        lastName: _lastNameController.text.trim(),
                        email: widget.isPhoneSignup ? _emailController.text.trim() : widget.email,
                        phone: widget.isPhoneSignup ? widget.phone : _normalizePhoneNumber(_phoneController.text.trim()),
                        password: widget.isPhoneSignup && _emailController.text.trim().isNotEmpty
                            ? _passwordController.text
                            : null,
                            isPhoneSignup: widget.isPhoneSignup,
                      ),
                    ),
                  );
                } catch (e, stackTrace) {
                  debugPrint('Auto phone link error: $e\nStack: $stackTrace');
                  if (mounted) {
                    setState(() => _isLoading = false);
                    toastification.show(
                      context: context,
                      type: ToastificationType.error,
                      title: const Text('Phone Link Error'),
                      description: Text('Error: $e'),
                      autoCloseDuration: const Duration(seconds: 2),
                    );
                  }
                }
              }
            },
            verificationFailed: (e) {
              if (mounted) {
                setState(() => _isLoading = false);
                toastification.show(
                  context: context,
                  type: ToastificationType.error,
                  title: const Text('Phone Verification Failed'),
                  description: Text('Error: ${e.message}'),
                  autoCloseDuration: const Duration(seconds: 2),
                );
              }
              debugPrint('Phone verification failed: ${e.message}');
            },
            codeSent: (verId, _) {
              if (mounted) {
                setState(() {
                  _verificationId = verId;
                  _showOtpField = true;
                  _isLoading = false;
                });
                debugPrint('Code sent to $phone, verificationId: $verId');
              }
            },
            codeAutoRetrievalTimeout: (_) {
              if (mounted) setState(() => _isLoading = false);
            },
          );
          return;
        }
      }

      if (!_showOtpField) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileDetailsPage(
              uid: widget.uid,
              role: widget.role,
              firstName: _firstNameController.text.trim(),
              lastName: _lastNameController.text.trim(),
              email: widget.isPhoneSignup ? _emailController.text.trim() : widget.email,
              phone: widget.isPhoneSignup ? widget.phone : _normalizePhoneNumber(_phoneController.text.trim()),
              password: widget.isPhoneSignup && _emailController.text.trim().isNotEmpty
                  ? _passwordController.text
                  : null,
                  isPhoneSignup: widget.isPhoneSignup,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (!mounted || _isLoading) return;

    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6 || _verificationId == null) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Validation Error'),
        description: const Text('Enter a valid 6-digit OTP'),
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = firebase_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final user = firebase_auth.FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.linkWithCredential(credential);
        if (mounted) {
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileDetailsPage(
                uid: widget.uid,
                role: widget.role,
                firstName: _firstNameController.text.trim(),
                lastName: _lastNameController.text.trim(),
                email: widget.isPhoneSignup ? _emailController.text.trim() : widget.email,
                phone: widget.isPhoneSignup ? widget.phone : _normalizePhoneNumber(_phoneController.text.trim()),
                password: widget.isPhoneSignup && _emailController.text.trim().isNotEmpty
                    ? _passwordController.text
                    : null,
                    isPhoneSignup: widget.isPhoneSignup,
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('OTP verification error: $e\nStack: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('OTP Verification Failed'),
          description: Text('Error: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Widget _buildModernButton({
    required String text,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
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
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
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
    String? Function(String?)? validator,
  }) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: GoogleFonts.poppins(
                color: _secondaryTextColor.withOpacity(0.7),
                fontSize: 14,
              ),
              filled: true,
              fillColor: _inputBackground,
              border: OutlineInputBorder(
                borderRadius: isPhone
                    ? const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: isPhone
                    ? const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
                borderSide: BorderSide(color: _secondaryTextColor.withOpacity(0.2), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: isPhone
                    ? const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
                borderSide: BorderSide(color: _primaryColor, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: isPhone
                    ? const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
                borderSide: BorderSide(color: _errorColor, width: 1.5),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: isPhone
                    ? const BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      )
                    : BorderRadius.circular(16),
                borderSide: BorderSide(color: _errorColor, width: 2),
              ),
              prefixIcon: Icon(icon, color: _secondaryTextColor, size: 20),
              suffixIcon: suffixIcon,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: validator,
          ),
        ),
      ),
    );
  }

  Widget _buildOtpFields(List<TextEditingController> controllers) {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter verification code',
                style: GoogleFonts.poppins(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Row(
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
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _errorColor, width: 1.5),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _errorColor, width: 2),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryPicker() {
    return AnimationConfiguration.staggeredList(
      position: 0,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            decoration: BoxDecoration(
              color: _inputBackground,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
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
                hintStyle: GoogleFonts.poppins(color: _secondaryTextColor.withOpacity(0.7)),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: AnimationConfiguration.synchronized(
            duration: const Duration(milliseconds: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimationConfiguration.staggeredList(
                  position: 0,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: _textColor, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AnimationConfiguration.staggeredList(
                  position: 2,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Information',
                            style: GoogleFonts.poppins(
                              color: _textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 28,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Let\'s get to know you better',
                            style: GoogleFonts.poppins(
                              color: _secondaryTextColor.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AnimationConfiguration.staggeredList(
                        position: 3,
                        duration: const Duration(milliseconds: 500),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildModernTextField(
                              controller: _firstNameController,
                              label: 'First Name',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your first name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimationConfiguration.staggeredList(
                        position: 4,
                        duration: const Duration(milliseconds: 500),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: _buildModernTextField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your last name';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (widget.isPhoneSignup) ...[
                        AnimationConfiguration.staggeredList(
                          position: 5,
                          duration: const Duration(milliseconds: 500),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildModernTextField(
                                    controller: _emailController,
                                    label: 'Email (Optional)',
                                    icon: Icons.email_outlined,
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      'Add an email to secure your account',
                                      style: GoogleFonts.poppins(
                                        color: _secondaryTextColor.withOpacity(0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_showPasswordFields) ...[
                          const SizedBox(height: 16),
                          AnimationConfiguration.staggeredList(
                            position: 6,
                            duration: const Duration(milliseconds: 500),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildModernTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: _secondaryTextColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  validator: _validatePassword,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AnimationConfiguration.staggeredList(
                            position: 7,
                            duration: const Duration(milliseconds: 500),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildModernTextField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      color: _secondaryTextColor,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword = !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  validator: _validateConfirmPassword,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ] else ...[
                        AnimationConfiguration.staggeredList(
                          position: 5,
                          duration: const Duration(milliseconds: 500),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      _buildCountryPicker(),
                                      const SizedBox(width: 1),
                                      Expanded(
                                        child: _buildModernTextField(
                                          controller: _phoneController,
                                          label: 'Phone Number',
                                          icon: Icons.phone_outlined,
                                          keyboardType: TextInputType.phone,
                                          isPhone: true,
                                          validator: _validatePhone,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(
                                      'Phone number is required for account recovery',
                                      style: GoogleFonts.poppins(
                                        color: _secondaryTextColor.withOpacity(0.6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_showOtpField) ...[
                          const SizedBox(height: 24),
                          _buildOtpFields(_otpControllers),
                        ],
                      ],
                      const SizedBox(height: 32),
                      _buildModernButton(
                        text: _showOtpField ? 'Verify OTP' : 'Continue',
                        isLoading: _isLoading,
                        onPressed: _showOtpField ? _handleVerifyOtp : _handleNext,
                      ),
                      const SizedBox(height: 24),
                      AnimationConfiguration.staggeredList(
                        position: 8,
                        duration: const Duration(milliseconds: 500),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: Center(
                              child: Text(
                                'Step 1 of 2',
                                style: GoogleFonts.poppins(
                                  color: _secondaryTextColor.withOpacity(0.7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}