import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:toastification/toastification.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:image_picker/image_picker.dart';

class ProfileDetailsPage extends StatefulWidget {
  final String uid;
  final String role;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? password;
  final bool isPhoneSignup;

  const ProfileDetailsPage({
    super.key,
    required this.uid,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.password,
    required this.isPhoneSignup,
  });

  @override
  State<ProfileDetailsPage> createState() => _ProfileDetailsPageState();
}

class _ProfileDetailsPageState extends State<ProfileDetailsPage> {
  String? _selectedGender;
  int? _selectedProfileImageIndex;
  DateTime? _selectedDateOfBirth;
  bool _isLoading = false;
  XFile? _uploadedImage;

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _profileImages = [
    'assets/sketch1.jpg',
    'assets/sketch2.jpeg',
    'assets/sketch3.jpeg',
    'assets/sketch4.jpeg',
  ];

  final Color _darkBackground = const Color(0xFF121212);
  final Color _primaryColor = const Color(0xFF6C9A8B);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = const Color(0xFFC1DADB);
  final Color _inputBackground = const Color(0xFF1E1E1E);

  final FixedExtentScrollController _yearController = FixedExtentScrollController();
  final FixedExtentScrollController _monthController = FixedExtentScrollController();
  final FixedExtentScrollController _dayController = FixedExtentScrollController();

  final List<int> _years = List.generate(100, (index) => DateTime.now().year - 70 + index);
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  List<int> _days = [];

  @override
  void initState() {
    super.initState();
    _updateDays(DateTime.now().month, DateTime.now().year);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialYear = DateTime.now().year - 20;
      final yearIndex = _years.indexOf(initialYear);
      if (yearIndex != -1) {
        _yearController.jumpToItem(yearIndex);
      }
      _monthController.jumpToItem(DateTime.now().month - 1);
      _dayController.jumpToItem(DateTime.now().day - 1);
    });
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _updateDays(int month, int year) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    _days = List.generate(daysInMonth, (index) => index + 1);
    if (_dayController.hasClients && _dayController.selectedItem >= daysInMonth) {
      _dayController.jumpToItem(daysInMonth - 1);
    }
    setState(() {});
  }

  void _showScrollableDatePicker() {
    if (!_yearController.hasClients) {
      final initialYear = DateTime.now().year - 20;
      final yearIndex = _years.indexOf(initialYear);
      if (yearIndex != -1) {
        _yearController.jumpToItem(yearIndex);
      }
    }
    if (!_monthController.hasClients) {
      _monthController.jumpToItem(DateTime.now().month - 1);
    }
    if (!_dayController.hasClients) {
      _dayController.jumpToItem(DateTime.now().day - 1);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _darkBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Text(
                'Select Date of Birth',
                style: GoogleFonts.poppins(
                  color: _textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Year',
                          style: GoogleFonts.poppins(
                            color: _secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: _inputBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListWheelScrollView(
                            controller: _yearController,
                            itemExtent: 50,
                            perspective: 0.005,
                            diameterRatio: 1.2,
                            onSelectedItemChanged: (index) {
                              if (index >= 0 && _monthController.hasClients) {
                                final selectedMonth = _monthController.selectedItem + 1;
                                final selectedYear = _years[index];
                                _updateDays(selectedMonth, selectedYear);
                              }
                            },
                            children: _years.map((year) {
                              return Center(
                                child: Text(
                                  year.toString(),
                                  style: GoogleFonts.poppins(
                                    color: _textColor,
                                    fontSize: 20,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Month',
                          style: GoogleFonts.poppins(
                            color: _secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: _inputBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListWheelScrollView(
                            controller: _monthController,
                            itemExtent: 50,
                            perspective: 0.005,
                            diameterRatio: 1.2,
                            onSelectedItemChanged: (index) {
                              if (index >= 0 && _yearController.hasClients) {
                                final selectedMonth = index + 1;
                                final selectedYear = _years[_yearController.selectedItem];
                                _updateDays(selectedMonth, selectedYear);
                              }
                            },
                            children: _months.map((month) {
                              return Center(
                                child: Text(
                                  month,
                                  style: GoogleFonts.poppins(
                                    color: _textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Day',
                          style: GoogleFonts.poppins(
                            color: _secondaryTextColor,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: _inputBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListWheelScrollView(
                            controller: _dayController,
                            itemExtent: 50,
                            perspective: 0.005,
                            diameterRatio: 1.2,
                            children: _days.map((day) {
                              return Center(
                                child: Text(
                                  day.toString(),
                                  style: GoogleFonts.poppins(
                                    color: _textColor,
                                    fontSize: 20,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: _inputBackground,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: _textColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final selectedYear = _years[_yearController.selectedItem];
                        final selectedMonth = _monthController.selectedItem + 1;
                        final selectedDay = _days[_dayController.selectedItem];
                        setState(() {
                          _selectedDateOfBirth = DateTime(selectedYear, selectedMonth, selectedDay);
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Confirm',
                        style: GoogleFonts.poppins(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
      debugPrint('Location fetched: ${position.latitude}, ${position.longitude}');
      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (e, stackTrace) {
      debugPrint('Failed to fetch location: $e\nStack: $stackTrace');
      return null;
    }
  }

  Future<String?> _uploadImageToFirebase(XFile image) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${widget.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(File(image.path));
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('Image upload error: $e\nStack: $stackTrace');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _uploadedImage = image;
          _selectedProfileImageIndex = null;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Image picking error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: const Text('Failed to pick image'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    }
  }

  Future<bool> _checkFieldUniqueness(String field, String value) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where(field, isEqualTo: value.trim())
          .where('uid', isNotEqualTo: widget.uid)
          .get();
      return querySnapshot.docs.isEmpty;
    } catch (e, stackTrace) {
      debugPrint('checkFieldUniqueness error: $e\nStack: $stackTrace');
      return false;
    }
  }

  Future<void> _saveUserDetails() async {
    if (!mounted || _isLoading) return;

    if (_selectedGender == null || (_selectedProfileImageIndex == null && _uploadedImage == null)) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Validation Error'),
        description: const Text('Please select gender and profile image'),
        autoCloseDuration: const Duration(seconds: 2),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // For phone signups, link email if provided
      if (widget.isPhoneSignup && widget.email.isNotEmpty && widget.password != null) {
        final user = firebase_auth.FirebaseAuth.instance.currentUser;
        if (user != null) {
          final isEmailUnique = await _checkFieldUniqueness('email', widget.email);
          if (!isEmailUnique) {
            throw Exception('Email already in use by another account');
          }
          final credential = firebase_auth.EmailAuthProvider.credential(
            email: widget.email,
            password: widget.password!,
          );
          await user.linkWithCredential(credential);
          await user.sendEmailVerification();
          toastification.show(
            context: context,
            type: ToastificationType.info,
            title: const Text('Verification Email Sent'),
            description: Text('A verification email has been sent to ${widget.email}'),
            autoCloseDuration: const Duration(seconds: 2),
          );
        }
      }

      // Skip phone uniqueness check since it's handled in BasicInfoPage

      String? profileImageUrl;
      if (_uploadedImage != null) {
        profileImageUrl = await _uploadImageToFirebase(_uploadedImage!);
        if (profileImageUrl == null) {
          throw Exception('Failed to upload profile image');
        }
      } else {
        profileImageUrl = _profileImages[_selectedProfileImageIndex!];
      }

      final location = await _fetchUserLocation();
      final userData = {
        'uid': widget.uid,
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': widget.email.isNotEmpty ? widget.email : null,
        'phone': widget.phone.isNotEmpty ? widget.phone : null,
        'role': widget.role,
        'gender': _selectedGender,
        'profileImage': profileImageUrl,
        'dateOfBirth': _selectedDateOfBirth != null ? Timestamp.fromDate(_selectedDateOfBirth!) : null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isProfileComplete': true,
        'location': location != null
            ? {
                'latitude': location['latitude'],
                'longitude': location['longitude'],
              }
            : null,
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set(userData, SetOptions(merge: true));

      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Success'),
          description: const Text('Profile created successfully'),
          autoCloseDuration: const Duration(seconds: 2),
        );

        debugPrint('Navigating to ${widget.role} home for UID: ${widget.uid}');
        Navigator.of(context).pushNamedAndRemoveUntil('/${widget.role}', (route) => false);
      }
    } catch (e, stackTrace) {
      debugPrint('saveUserDetails error: $e\nStack: $stackTrace');
      if (mounted) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Error'),
          description: Text('Failed to save profile: $e'),
          autoCloseDuration: const Duration(seconds: 2),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Widget _buildGenderOption(String gender) {
    final isSelected = _selectedGender == gender;
    final isMale = gender == 'Male';

    return AnimationConfiguration.staggeredList(
      position: _genders.indexOf(gender),
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedGender = gender;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? _primaryColor.withOpacity(0.2) : _inputBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _primaryColor : _secondaryTextColor.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isSelected ? 0.3 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isMale
                            ? [const Color(0xFF64B5F6), const Color(0xFF1976D2)]
                            : [const Color(0xFFF48FB1), const Color(0xFFD81B60)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(
                      isMale ? Icons.male : Icons.female,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    gender,
                    style: GoogleFonts.poppins(
                      color: isSelected ? _primaryColor : _textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
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

  Widget _buildProfileImageOption(int index) {
    final isSelected = _selectedProfileImageIndex == index;

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedProfileImageIndex = index;
                _uploadedImage = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      _profileImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: _inputBackground,
                          child: Center(
                            child: Icon(
                              Icons.person,
                              color: _secondaryTextColor,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: _darkBackground, width: 2),
                        ),
                        child: Icon(
                          Icons.check,
                          color: _textColor,
                          size: 14,
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

  Widget _buildUploadImageOption() {
    final isSelected = _uploadedImage != null && _selectedProfileImageIndex == null;

    return AnimationConfiguration.staggeredList(
      position: _profileImages.length,
      duration: const Duration(milliseconds: 500),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: _pickImage,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.transparent,
                  width: 3,
                ),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _uploadedImage == null
                        ? Container(
                            color: _inputBackground,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.upload,
                                    color: _secondaryTextColor,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Upload',
                                    style: GoogleFonts.poppins(
                                      color: _secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Image.file(
                            File(_uploadedImage!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: _inputBackground,
                                child: Center(
                                  child: Icon(
                                    Icons.person,
                                    color: _secondaryTextColor,
                                    size: 40,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: _darkBackground, width: 2),
                        ),
                        child: Icon(
                          Icons.check,
                          color: _textColor,
                          size: 14,
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 400 ? 2 : 4;
    final childAspectRatio = screenWidth < 400 ? 1.0 : 0.8;

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
                const SizedBox(height: 16),
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
                            'Profile Details',
                            style: GoogleFonts.poppins(
                              color: _textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 28,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete your profile',
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
                AnimationConfiguration.staggeredList(
                  position: 3,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Gender',
                            style: GoogleFonts.poppins(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildGenderOption('Male'),
                              _buildGenderOption('Female'),
                            ],
                          ),
                          if (_selectedGender == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Please select a gender',
                                style: GoogleFonts.poppins(
                                  color: Colors.redAccent,
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
                const SizedBox(height: 24),
                AnimationConfiguration.staggeredList(
                  position: 4,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Profile Avatar or Upload Image',
                            style: GoogleFonts.poppins(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: _profileImages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == _profileImages.length) {
                                return _buildUploadImageOption();
                              }
                              return _buildProfileImageOption(index);
                            },
                          ),
                          if (_selectedProfileImageIndex == null && _uploadedImage == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Please select or upload a profile image',
                                style: GoogleFonts.poppins(
                                  color: Colors.redAccent,
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
                const SizedBox(height: 24),
                AnimationConfiguration.staggeredList(
                  position: 5,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date of Birth (Optional)',
                            style: GoogleFonts.poppins(
                              color: _textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _showScrollableDatePicker,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: _inputBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _secondaryTextColor.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: _secondaryTextColor, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _selectedDateOfBirth == null
                                        ? 'Select date of birth'
                                        : DateFormat('MMMM dd, yyyy').format(_selectedDateOfBirth!),
                                    style: GoogleFonts.poppins(
                                      color: _selectedDateOfBirth == null ? _secondaryTextColor : _textColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_selectedDateOfBirth != null)
                                    IconButton(
                                      icon: Icon(Icons.clear, color: _secondaryTextColor, size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _selectedDateOfBirth = null;
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildModernButton(
                  text: 'Complete Profile',
                  isLoading: _isLoading,
                  onPressed: _saveUserDetails,
                ),
                const SizedBox(height: 24),
                AnimationConfiguration.staggeredList(
                  position: 6,
                  duration: const Duration(milliseconds: 500),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Center(
                        child: Text(
                          'Step 2 of 2',
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}