import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_event.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/models/user_model.dart';
import 'package:game_app/organiser_pages/hosted_tournaments_page.dart';
import 'package:game_app/player_pages/joined_tournaments.dart';
import 'package:game_app/auth_pages/welcome_screen.dart';
import 'package:game_app/umpire/hosted_umpire_matches.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toastification/toastification.dart';

// New Profile Information Page with Apple-style design
class ProfileInformationPage extends StatefulWidget {
  final User user;
  final AppUser appUser;

  const ProfileInformationPage({
    super.key,
    required this.user,
    required this.appUser,
  });

  @override
  State<ProfileInformationPage> createState() => _ProfileInformationPageState();
}

class _ProfileInformationPageState extends State<ProfileInformationPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  final List<String> _genderOptions = ['Male', 'Female'];
  bool _isUploadingImage = false;
  String? _profileImageUrl;
  bool _isEditing = false;
  bool _isVerifyingPhone = false;
  bool _isOtpSent = false;
  String? _verificationId;
  String? _originalPhoneNumber;
  String? _originalEmail;
  bool _isVerifyingEmail = false;


  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _firstNameController.text = widget.appUser.firstName;
    _lastNameController.text = widget.appUser.lastName;
    _emailController.text = widget.appUser.email ?? widget.user.email ?? '';
    _phoneController.text = widget.appUser.phone ?? widget.user.phoneNumber ?? '';
    _originalPhoneNumber = _phoneController.text;
    _originalEmail = _emailController.text;
    _genderController.text = widget.appUser.gender ?? _genderOptions[0];
    _profileImageUrl = widget.appUser.profileImage ?? 'assets/logo.png';
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    _otpController.dispose();
    super.dispose();
  }








  Future<bool> _isPhoneNumberInUse(String phoneNumber, String currentUserId) async {
    if (phoneNumber.isEmpty || phoneNumber == _originalPhoneNumber) return false;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .get();
      return querySnapshot.docs.any((doc) => doc.id != currentUserId);
    } catch (e) {
      debugPrint('Error checking phone number: $e');
      return true;
    }
  }

  Future<bool> _isEmailInUse(String email, String currentUserId) async {
    if (email.isEmpty || email == _originalEmail) return false;
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      return querySnapshot.docs.any((doc) => doc.id != currentUserId);
    } catch (e) {
      debugPrint('Error checking email: $e');
      return true;
    }
  }

  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    setState(() {
      _isVerifyingPhone = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
          setState(() {
            _isOtpSent = true;
            _isVerifyingPhone = false;
          });
          _showToast('Phone number automatically verified', ToastificationType.success);
        } catch (e) {
          _showToast('Failed to link phone number: ${e.toString()}', ToastificationType.error);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
      _isVerifyingPhone = false;
    });
    _showToast('Verification failed: ${e.message}', ToastificationType.error);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isVerifyingPhone = false;
        });
        _showToast('OTP sent to $phoneNumber', ToastificationType.success);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _verifyOtp(String otp) async {
    if (_verificationId == null) return;

    setState(() {
      _isVerifyingPhone = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
      setState(() {
        _isOtpSent = false;
        _isVerifyingPhone = false;
        _otpController.clear();
      });
      _showToast('Phone number verified successfully', ToastificationType.success);
    } catch (e) {
      setState(() {
        _isVerifyingPhone = false;
      });
      _showToast('Invalid OTP. Please try again', ToastificationType.error);
    }
  }

  Future<void> _sendEmailVerification() async {
    setState(() {
      _isVerifyingEmail = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        _showToast('Verification email sent to ${_emailController.text}', ToastificationType.success);
      }
    } catch (e) {
      _showToast('Failed to send verification email: ${e.toString()}', ToastificationType.error);
    } finally {
      setState(() {
        _isVerifyingEmail = false;
      });
    }
  }

  Future<void> _updateEmail(String email) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(email);
        _showToast('Verification email sent to $email', ToastificationType.success);
      }
    } catch (e) {
      _showToast('Failed to update email: ${e.toString()}', ToastificationType.error);
    }
  }

  Future<void> _pickAndSetProfileImage(String uid) async {
    final List<String> sketchOptions = [
      'assets/sketch1.jpg',
      'assets/sketch2.jpeg',
      'assets/sketch3.jpeg',
      'assets/sketch4.jpeg',
    ];

    setState(() => _isUploadingImage = true);

    try {
      final selectedSketch = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose your avatar',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: sketchOptions.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, sketchOptions[index]),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.5),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            sketchOptions[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (selectedSketch != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'profileImage': selectedSketch});
        if (mounted) {
          setState(() => _profileImageUrl = selectedSketch);
          context.read<AuthBloc>().add(AuthRefreshProfileEvent(uid));
          _showToast('Profile image updated', ToastificationType.success);
        }
      }
    } catch (e) {
      _showToast('Failed to update image: ${e.toString()}', ToastificationType.error);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showToast(String message, ToastificationType type) {
    toastification.show(
      context: context,
      type: type,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      style: ToastificationStyle.fillColored,
      alignment: Alignment.topCenter,
      animationDuration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _saveProfileChanges(String uid) async {
    try {
      if (_isOtpSent && _otpController.text.isEmpty) {
        _showToast('Please enter the OTP', ToastificationType.error);
        return;
      }

      if (!_isOtpSent && _phoneController.text != _originalPhoneNumber) {
        final isPhoneInUse = await _isPhoneNumberInUse(_phoneController.text, uid);
        if (isPhoneInUse) {
          _showToast('Phone number already in use', ToastificationType.error);
          return;
        }
        await _verifyPhoneNumber(_phoneController.text);
        return;
      }

      if (_emailController.text != _originalEmail) {
        final isEmailInUse = await _isEmailInUse(_emailController.text, uid);
        if (isEmailInUse) {
          _showToast('Email already in use', ToastificationType.error);
          return;
        }
        await _updateEmail(_emailController.text);
      }

      final updates = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'gender': _genderController.text.trim(),
      };

      if (_phoneController.text != _originalPhoneNumber && _isOtpSent) {
        updates['phone'] = _phoneController.text.trim();
      }

      if (_emailController.text != _originalEmail) {
        updates['email'] = _emailController.text.trim();
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);
      context.read<AuthBloc>().add(AuthRefreshProfileEvent(uid));
      setState(() {
        _isEditing = false;
        _isOtpSent = false;
        _otpController.clear();
        _originalPhoneNumber = _phoneController.text;
        _originalEmail = _emailController.text;
      });
      _showToast('Profile updated successfully', ToastificationType.success);
    } catch (e) {
      _showToast('Failed to update profile: ${e.toString()}', ToastificationType.error);
    }
  }

  Widget _buildProfileHeader(User user, AppUser appUser) {
    final displayName = "${appUser.firstName} ${appUser.lastName}".trim();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: _isUploadingImage ? null : () => _pickAndSetProfileImage(user.uid),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : ClipOval(
                        child: _profileImageUrl != null
                            ? Image.asset(
                                _profileImageUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.asset(
                                  'assets/logo.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/logo.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                      ),
              ),
            ),
            if (!_isUploadingImage)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1E293B),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          displayName,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(appUser.role).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getRoleColor(appUser.role),
              width: 1,
            ),
          ),
          child: Text(
            appUser.role.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _getRoleColor(appUser.role),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'player':
        return const Color(0xFF10B981);
      case 'organizer':
        return const Color(0xFFF59E0B);
      case 'umpire':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  Widget _buildEmailVerificationPrompt(User user) {
    if (user.email != null && user.email!.isNotEmpty && !user.emailVerified) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.amber, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your email is not verified. Please verify to secure your account.',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isVerifyingEmail ? null : _sendEmailVerification,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isVerifyingEmail
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : Text(
                      'Verify Now',
                      style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w500),
                    ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildEditProfileForm(User user, AppUser appUser) {
    return Column(
      children: [
        _buildFormField(
          icon: Icons.person_outline,
          label: 'First Name',
          controller: _firstNameController,
        ),
        _buildFormField(
          icon: Icons.person_outline,
          label: 'Last Name',
          controller: _lastNameController,
        ),
        _buildFormField(
          icon: Icons.email_outlined,
          label: 'Email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          isVerifying: _isVerifyingEmail,
        ),
        _buildFormField(
          icon: Icons.phone_outlined,
          label: 'Phone',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          isVerifying: _isVerifyingPhone,
          readOnly: _isOtpSent,
        ),
        if (_isOtpSent)
          _buildFormField(
            icon: Icons.sms,
            label: 'Enter OTP',
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            hasSuffixIcon: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () async {
                if (_otpController.text.length == 6) {
                  await _verifyOtp(_otpController.text);
                }
              },
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: _genderController.text.isNotEmpty ? _genderController.text : null,
            items: _genderOptions.map((gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(
                  gender,
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _genderController.text = value;
              }
            },
            decoration: InputDecoration(
              labelText: 'Gender',
              labelStyle: GoogleFonts.poppins(color: Colors.white70),
              border: InputBorder.none,
              icon: Icon(Icons.person, color: Colors.white70),
            ),
            dropdownColor: const Color(0xFF1E293B),
            style: GoogleFonts.poppins(color: Colors.white),
            icon: Icon(Icons.arrow_drop_down, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _isOtpSent = false;
                      _phoneController.text = _originalPhoneNumber ?? '';
                      _emailController.text = _originalEmail ?? '';
                      _otpController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await _saveProfileChanges(user.uid);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _isOtpSent ? 'Verify & Save' : 'Save',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isVerifying = false,
    bool readOnly = false,
    int? maxLength,
    bool hasSuffixIcon = false,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.white70),
          border: InputBorder.none,
          icon: Icon(icon, color: Colors.white70),
          suffixIcon: isVerifying
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : hasSuffixIcon ? suffixIcon : null,
        ),
        keyboardType: keyboardType,
        readOnly: readOnly,
        maxLength: maxLength,
      ),
    );
  }

  Widget _buildProfileInfoItem({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    Color? subtitleColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: Colors.white70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: subtitleColor ?? Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Color(0xFF6C9A8B),
        elevation: 0,
        title: Text(
          'Personal Information',
          style: GoogleFonts.poppins(
            color: Colors.white, 
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              child: Text(
                'Edit',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF007AFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1C1C1E),
              Color(0xFF2C2C2E),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildProfileHeader(widget.user, widget.appUser)),
              const SizedBox(height: 32),
              _buildEmailVerificationPrompt(widget.user),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'PERSONAL INFORMATION',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _isEditing
                  ? _buildEditProfileForm(widget.user, widget.appUser)
                  : Column(
                      children: [
                        _buildProfileInfoItem(
                          icon: Icons.person_outline,
                          label: 'First Name',
                          value: widget.appUser.firstName,
                        ),
                        _buildProfileInfoItem(
                          icon: Icons.person_outline,
                          label: 'Last Name',
                          value: widget.appUser.lastName,
                        ),
                        _buildProfileInfoItem(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: widget.appUser.email ?? widget.user.email ?? 'Not set',
                          subtitle: widget.user.email != null && widget.user.email!.isNotEmpty
                              ? (widget.user.emailVerified ? 'Verified' : 'Not Verified')
                              : null,
                          subtitleColor: widget.user.email != null && widget.user.email!.isNotEmpty
                              ? (widget.user.emailVerified ? Colors.green : Colors.amber)
                              : null,
                        ),
                        _buildProfileInfoItem(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: widget.appUser.phone ?? widget.user.phoneNumber ?? 'Not set',
                        ),
                        _buildProfileInfoItem(
                          icon: Icons.person,
                          label: 'Gender',
                          value: widget.appUser.gender ?? 'Not set',
                        ),
                      ],
                    ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Main Profile Page with Apple-style design
class PlayerProfilePage extends StatefulWidget {
  const PlayerProfilePage({super.key});

  @override
  State<PlayerProfilePage> createState() => _PlayerProfilePageState();
}

class _PlayerProfilePageState extends State<PlayerProfilePage> {
  Map<String, dynamic>? _playerStats;
  bool _isUploadingImage = false;
  String? _profileImageUrl;
  bool _isVerifyingPhone = false;
  bool _isOtpSent = false;
  String? _verificationId;
  final TextEditingController _otpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<AuthBloc>().add(AuthRefreshProfileEvent(user.uid));
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _pickAndSetProfileImage(String uid) async {
    final List<String> sketchOptions = [
      'assets/sketch1.jpg',
      'assets/sketch2.jpeg',
      'assets/sketch3.jpeg',
      'assets/sketch4.jpeg',
    ];

    setState(() => _isUploadingImage = true);

    try {
      final selectedSketch = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose your avatar',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1,
                  ),
                  itemCount: sketchOptions.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, sketchOptions[index]),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blueAccent.withOpacity(0.5),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.asset(
                            sketchOptions[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (selectedSketch != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'profileImage': selectedSketch});
        if (mounted) {
          setState(() => _profileImageUrl = selectedSketch);
          context.read<AuthBloc>().add(AuthRefreshProfileEvent(uid));
          _showToast('Profile image updated', ToastificationType.success);
        }
      }
    } catch (e) {
      _showToast('Failed to update image: ${e.toString()}', ToastificationType.error);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showToast(String message, ToastificationType type) {
    toastification.show(
      context: context,
      type: type,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 3),
      style: ToastificationStyle.fillColored,
      alignment: Alignment.topCenter,
      animationDuration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _fetchPlayerStats(String userId) async {
    try {
      final tournamentsQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .get();

      int totalMatches = 0;
      int wins = 0;
      int losses = 0;
      int currentStreak = 0;
      int longestWinStreak = 0;
      int longestLossStreak = 0;
      String bestTournamentResult = 'N/A';
      final tournamentResults = <String, String>{};

      for (var tournamentDoc in tournamentsQuery.docs) {
        final tournamentData = tournamentDoc.data();
        final matches = List<Map<String, dynamic>>.from(tournamentData['matches'] ?? []);

        bool playedInTournament = false;
        int tournamentWins = 0;
        int tournamentLosses = 0;

        for (var match in matches) {
          final player1Id = match['player1Id']?.toString() ?? '';
          final player2Id = match['player2Id']?.toString() ?? '';
          final team1Ids = List<String>.from(match['team1Ids'] ?? []);
          final team2Ids = List<String>.from(match['team2Ids'] ?? []);

          if (player1Id == userId ||
              player2Id == userId ||
              team1Ids.contains(userId) ||
              team2Ids.contains(userId)) {
            final isCompleted = match['completed'] == true;
            if (isCompleted) {
              totalMatches++;
              playedInTournament = true;

              final winner = match['winner']?.toString();
              if (winner == 'player1' && player1Id == userId ||
                  winner == 'player2' && player2Id == userId ||
                  winner == 'team1' && team1Ids.contains(userId) ||
                  winner == 'team2' && team2Ids.contains(userId)) {
                wins++;
                tournamentWins++;
                currentStreak = currentStreak >= 0 ? currentStreak + 1 : 1;
                longestWinStreak = currentStreak > longestWinStreak ? currentStreak : longestWinStreak;
              } else if (winner != null && winner.isNotEmpty) {
                losses++;
                tournamentLosses++;
                currentStreak = currentStreak <= 0 ? currentStreak - 1 : -1;
                longestLossStreak = (-currentStreak) > longestLossStreak ? -currentStreak : longestLossStreak;
              }
            }
          }
        }

        if (playedInTournament && (tournamentWins > 0 || tournamentLosses > 0)) {
          tournamentResults[tournamentDoc.id] = '$tournamentWins-$tournamentLosses';
        }
      }

      if (tournamentResults.isNotEmpty) {
        bestTournamentResult = tournamentResults.values.reduce((a, b) {
          final aParts = a.split('-').map(int.parse).toList();
          final bParts = b.split('-').map(int.parse).toList();
          final aWinRate = aParts[0] / (aParts[0] + aParts[1]);
          final bWinRate = bParts[0] / (bParts[0] + bParts[1]);
          return aWinRate > bWinRate ? a : b;
        });
      }

      if (mounted) {
        setState(() {
          _playerStats = {
            'totalMatches': totalMatches,
            'wins': wins,
            'losses': losses,
            'winPercentage': totalMatches > 0 ? (wins / totalMatches * 100) : 0.0,
            'currentStreak': currentStreak,
            'longestWinStreak': longestWinStreak,
            'longestLossStreak': longestLossStreak,
            'bestTournamentResult': bestTournamentResult,
          };
        });
      }
    } catch (e) {
      debugPrint('Error fetching stats: $e');
      _showToast('Failed to fetch stats', ToastificationType.error);
    }
  }

  Future<void> _deleteAccount(String uid) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        await user.delete();
        context.read<AuthBloc>().add(AuthLogoutEvent());
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (route) => false,
        );
        _showToast('Account deleted', ToastificationType.success);
      }
    } catch (e) {
      _showToast('Failed to delete account: ${e.toString()}', ToastificationType.error);
    }
  }

  Future<void> _reauthenticateWithPhone(String phoneNumber, String uid) async {
    setState(() {
      _isVerifyingPhone = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);
          setState(() {
            _isVerifyingPhone = false;
            _isOtpSent = false;
          });
          await _deleteAccount(uid);
        } catch (e) {
          setState(() {
            _isVerifyingPhone = false;
          });
          _showToast('Re-authentication failed: ${e.toString()}', ToastificationType.error);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isVerifyingPhone = false;
        });
        _showToast('Phone verification failed: ${e.message}', ToastificationType.error);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isOtpSent = true;
          _isVerifyingPhone = false;
        });
        _showToast('OTP sent to $phoneNumber', ToastificationType.success);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _verifyPhoneOtpForDelete(String otp, String uid) async {
    if (_verificationId == null) return;

    setState(() {
      _isVerifyingPhone = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);
      setState(() {
        _isOtpSent = false;
        _isVerifyingPhone = false;
        _otpController.clear();
      });
      await _deleteAccount(uid);
    } catch (e) {
      setState(() {
        _isVerifyingPhone = false;
      });
      _showToast('Invalid OTP. Please try again', ToastificationType.error);
    }
  }

  Future<void> _showReauthenticationDialog(String uid) async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final phoneController = TextEditingController();
    bool usePhone = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verify Your Identity',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'For security, please enter your credentials to continue',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setDialogState(() {
                            usePhone = false;
                            _isOtpSent = false;
                            _otpController.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: !usePhone ? Colors.white.withOpacity(0.1) : null,
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          'Email',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setDialogState(() {
                            usePhone = true;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: usePhone ? Colors.white.withOpacity(0.1) : null,
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Text(
                          'Phone',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!usePhone) ...[
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.email, color: Colors.white70),
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.lock, color: Colors.white70),
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                    obscureText: true,
                  ),
                ] else ...[
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.phone, color: Colors.white70),
                      suffixIcon: _isVerifyingPhone
                          ? const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                    keyboardType: TextInputType.phone,
                    readOnly: _isOtpSent,
                  ),
                  if (_isOtpSent) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        labelText: 'Enter OTP',
                        labelStyle: GoogleFonts.poppins(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: Icon(Icons.sms, color: Colors.white70),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            if (_otpController.text.length == 6) {
                              await _verifyPhoneOtpForDelete(_otpController.text, uid);
                            }
                          },
                        ),
                      ),
                      style: GoogleFonts.poppins(color: Colors.white),
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isOtpSent = false;
                          _otpController.clear();
                        });
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (!usePhone) {
                          try {
                            final email = emailController.text.trim();
                            final password = passwordController.text.trim();
                            if (email.isEmpty || password.isEmpty) {
                              _showToast('Fields cannot be empty', ToastificationType.error);
                              return;
                            }
                            final credential = EmailAuthProvider.credential(
                              email: email,
                              password: password,
                            );
                            await FirebaseAuth.instance.currentUser?.reauthenticateWithCredential(credential);
                            Navigator.pop(context);
                            await _deleteAccount(uid);
                          } catch (e) {
                            _showToast('Authentication failed: ${e.toString()}', ToastificationType.error);
                          }
                        } else {
                          if (!_isOtpSent) {
                            if (phoneController.text.isEmpty) {
                              _showToast('Phone number cannot be empty', ToastificationType.error);
                              return;
                            }
                            await _reauthenticateWithPhone(phoneController.text, uid);
                            setDialogState(() {});
                          } else if (_otpController.text.length == 6) {
                            await _verifyPhoneOtpForDelete(_otpController.text, uid);
                          } else {
                            _showToast('Please enter a valid OTP', ToastificationType.error);
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        usePhone && !_isOtpSent ? 'Send OTP' : 'Continue',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user, AppUser? appUser) {
    final displayName = appUser != null ? "${appUser.firstName} ${appUser.lastName}".trim() : 'User';
    final role = appUser?.role ?? 'Unknown';

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: _isUploadingImage ? null : () => _pickAndSetProfileImage(user.uid),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF818CF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isUploadingImage
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : ClipOval(
                        child: _profileImageUrl != null
                            ? Image.asset(
                                _profileImageUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Image.asset(
                                  'assets/logo.png',
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                'assets/logo.png',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                      ),
              ),
            ),
            if (!_isUploadingImage)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1E293B),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit,
                  size: 16,
                  color: Colors.white,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          displayName,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(role).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getRoleColor(role),
              width: 1,
            ),
          ),
          child: Text(
            role.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _getRoleColor(role),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'player':
        return const Color(0xFF10B981);
      case 'organizer':
        return const Color(0xFFF59E0B);
      case 'umpire':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  Widget _buildPlayerStatsSection(User user, AppUser? appUser) {
    return Column(
      children: [
        _buildSectionHeader('PLAYER STATS'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('Matches', _playerStats?['totalMatches']?.toString() ?? '0'),
                    _buildStatItem('Wins', _playerStats?['wins']?.toString() ?? '0'),
                    _buildStatItem('Losses', _playerStats?['losses']?.toString() ?? '0'),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem(
                        'Win %',
                        _playerStats?['winPercentage'] != null
                            ? '${_playerStats!['winPercentage'].toStringAsFixed(1)}'
                            : '0'),
                    _buildStatItem(
                        'Streak',
                        _playerStats?['currentStreak'] != null
                            ? (_playerStats!['currentStreak'] > 0
                                ? 'W-${_playerStats!['currentStreak']}'
                                : 'L-${_playerStats!['currentStreak']}')
                            : '-'),
                    _buildStatItem('Best', _playerStats?['bestTournamentResult']?.toString() ?? '-'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 48, color: Colors.white70),
              const SizedBox(height: 16),
              Text(
                'Log Out?',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to log out of your account?',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthLogoutEvent());
                        Navigator.pop(context);
                        _showToast('Logged out successfully', ToastificationType.success);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007AFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Log Out',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfoButton(User user, AppUser appUser) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileInformationPage(
                  user: user,
                  appUser: appUser,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, color: Color(0xFF007AFF), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View and edit your profile details',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<AppUser?> _fetchUserFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user from Firestore: $e');
      return null;
    }
  }

  void _showDeleteAccountConfirmationDialog(String uid) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.amber),
              const SizedBox(height: 16),
              Text(
                'Delete Account?',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete your account and all associated data. This action cannot be undone.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showReauthenticationDialog(uid);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
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
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthInitial || state is AuthLoading) {
            return const Scaffold(
              backgroundColor: Color(0xFF1C1C1E),
              body: Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }

          if (state is AuthAuthenticated) {
            final user = state.user;
            if (state.appUser == null) {
              return FutureBuilder<AppUser?>(
                future: _fetchUserFromFirestore(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: Color(0xFF1C1C1E),
                      body: Center(child: CircularProgressIndicator(color: Colors.white)),
                    );
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Scaffold(
                      backgroundColor: Color(0xFF1C1C1E),
                      body: Center(child: Text('Error loading profile', style: TextStyle(color: Colors.white))),
                    );
                  }
                  final appUser = snapshot.data!;
                  _profileImageUrl = appUser.profileImage ?? 'assets/logo.png';
                  if (appUser.role.toLowerCase() == 'player') {
                    _fetchPlayerStats(user.uid);
                  }
                  return _buildScaffold(context, user, appUser);
                },
              );
            }
            final appUser = state.appUser!;
            _profileImageUrl = appUser.profileImage ?? 'assets/logo.png';
            if (appUser.role.toLowerCase() == 'player') {
              _fetchPlayerStats(user.uid);
            }
            return _buildScaffold(context, user, appUser);
          }

          return const Scaffold(
            backgroundColor: Color(0xFF1C1C1E),
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, User user, AppUser appUser) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Color(0xFF6C9A8B),
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.settings, color: Colors.white, size: 24),
        //     onPressed: () {
        //       showModalBottomSheet(
        //         context: context,
        //         backgroundColor: Colors.transparent,
        //         builder: (context) => Container(
        //           decoration: BoxDecoration(
        //             color: const Color(0xFF2C2C2E),
        //             borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        //             boxShadow: [
        //               BoxShadow(
        //                 color: Colors.black.withOpacity(0.3),
        //                 blurRadius: 20,
        //                 spreadRadius: 5,
        //               ),
        //             ],
        //           ),
        //           padding: const EdgeInsets.all(16),
        //           child: Column(
        //             mainAxisSize: MainAxisSize.min,
        //             children: [
        //               ListTile(
        //                 leading: const Icon(Icons.image, color: Colors.white70, size: 22),
        //                 title: Text(
        //                   'Change Avatar',
        //                   style: GoogleFonts.poppins(
        //                       color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
        //                 ),
        //                 onTap: () {
        //                   Navigator.pop(context);
        //                   _pickAndSetProfileImage(user.uid);
        //                 },
        //               ),
        //               if (appUser.role.toLowerCase() == 'player')
        //                 ListTile(
        //                   leading: const Icon(Icons.refresh, color: Colors.white70, size: 22),
        //                   title: Text(
        //                     'Refresh Stats',
        //                     style: GoogleFonts.poppins(
        //                         color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
        //                   ),
        //                   onTap: () {
        //                     Navigator.pop(context);
        //                     _fetchPlayerStats(user.uid);
        //                   },
        //                 ),
        //               const SizedBox(height: 8),
        //               TextButton(
        //                 onPressed: () => Navigator.pop(context),
        //                 child: Text(
        //                   'Cancel',
        //                   style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
        //                 ),
        //               ),
        //             ],
        //           ),
        //         ),
        //       );
        //     },
        //   ),
        // ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1C1C1E),
              Color(0xFF2C2C2E),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildProfileHeader(user, appUser)),
              const SizedBox(height: 32),
              _buildProfileInfoButton(user, appUser),
              if (appUser.role.toLowerCase() == 'player')
                _buildPlayerStatsSection(user, appUser),
              _buildSectionHeader('ACTIVITY'),
              if (appUser.role == 'organizer')
                _buildActionButton(
                  icon: Icons.tour,
                  label: 'Hosted Tournaments',
                  description: 'View and manage your hosted tournaments',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HostedTournamentsPage(userId: user.uid)),
                  ),
                  color: const Color(0xFF8B5CF6),
                ),
              if (appUser.role == 'player')
                _buildActionButton(
                  icon: Icons.event,
                  label: 'Joined Tournaments',
                  description: 'View your tournament participations',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => JoinedTournamentsPage(userId: user.uid)),
                  ),
                  color: const Color(0xFF10B981),
                ),
              if (appUser.role == 'umpire')
                _buildActionButton(
                  icon: Icons.gavel,
                  label: 'Umpired Matches',
                  description: 'View matches you are officiating',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => UmpiredMatchesPage(userId: user.uid)),
                  ),
                  color: const Color(0xFF3B82F6),
                ),
              _buildActionButton(
                icon: Icons.lock_reset,
                label: 'Reset Password',
                description: 'Change your account password',
                onTap: () {
                  final email = appUser.email ?? user.email ?? '';
                  if (email.isNotEmpty) {
                    FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                    _showToast('Password reset email sent', ToastificationType.success);
                  } else {
                    _showToast('No email available', ToastificationType.error);
                  }
                },
                color: const Color(0xFFF59E0B),
              ),
              _buildSectionHeader('ACCOUNT'),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      onTap: _showLogoutConfirmationDialog,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout, color: Color(0xFF007AFF), size: 20),
                      ),
                      title: Text(
                        'Log Out',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 22),
                    ),
                    Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.1), indent: 56),
                    ListTile(
                      onTap: () => _showDeleteAccountConfirmationDialog(user.uid),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 20),
                      ),
                      title: Text(
                        'Delete Account',
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}