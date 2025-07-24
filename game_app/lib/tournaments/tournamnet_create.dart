import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:game_app/models/tournament.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class CreateTournamentPage extends StatefulWidget {
  final String userId;
  final VoidCallback? onBackPressed;
  final VoidCallback? onTournamentCreated;

  const CreateTournamentPage({
    super.key,
    required this.userId,
    this.onBackPressed,
    this.onTournamentCreated,
  });

  @override
  State<CreateTournamentPage> createState() => _CreateTournamentPageState();
}

class _CreateTournamentPageState extends State<CreateTournamentPage> with SingleTickerProviderStateMixin {
  static const Color primaryColor = Color(0xFFF5F5F5);
  static const Color secondaryColor = Color(0xFFFFFFFF);
  static const Color accentColor = Color(0xFF4E6BFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color borderColor = Color(0xFFB0B0B0);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color highlightColor = Color(0xFFE0E0E0);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _rulesController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  DateTime? _selectedEndDate;
  String _playStyle = "Men's Singles";
  String _eventType = 'Knockout';
  bool _bringOwnEquipment = false;
  bool _costShared = false;
  bool _isLoading = false;
  String? _fetchedCity;
  bool _isFetchingLocation = false;
  bool _isCityValid = true;
  bool _isValidatingCity = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _debounceTimer;

  final Map<String, String> _validCities = {
    'hyderabad': 'Hyderabad',
    'mumbai': 'Mumbai',
    'delhi': 'Delhi',
    'bengaluru': 'Bengaluru',
    'chennai': 'Chennai',
    'kolkata': 'Kolkata',
    'pune': 'Pune',
    'ahmedabad': 'Ahmedabad',
    'jaipur': 'Jaipur',
    'lucknow': 'Lucknow',
    'karimnagar': 'Karimnagar',
  };

  @override
  void initState() {
    super.initState();
    _rulesController.text = _defaultRules(); // Set default rules
    _initializeAnimations();
    _initLocationServices();
  }

  String _defaultRules() {
    return '''
1. Matches follow BWF regulations - best of 3 games to 21 points (rally point scoring)
2. Players must report 15 minutes before scheduled match time
3. Proper sports attire and non-marking shoes required
4. Tournament director reserves the right to modify rules as needed
5. Any disputes will be resolved by the tournament committee
''';
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _venueController.dispose();
    _cityController.dispose();
    _entryFeeController.dispose();
    _rulesController.dispose();
    _maxParticipantsController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initLocationServices() async {
    debugPrint('Initializing location services');
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showErrorToast('Location Error', 'Location services are disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
        _showErrorToast('Location Error', 'Location permissions denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showErrorToast('Location Error', 'Location permissions are denied. Please enable them in app settings.');
      return;
    }

    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      debugPrint('Fetching current location');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 15));

      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      } catch (e) {
        debugPrint('High accuracy placemark failed: $e, falling back to medium');
        position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      }

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final city = place.locality ?? place.administrativeArea ?? place.subAdministrativeArea ?? place.name;
        debugPrint('Placemarks: ${placemarks.map((p) => p.toString()).toList()}');
        debugPrint('Fetched city: $city');

        if (city != null && city.isNotEmpty) {
          setState(() {
            _fetchedCity = _validCities[city.toLowerCase()] ?? city;
            _cityController.text = _fetchedCity!;
            _isCityValid = true;
          });
          _validateCityWithGeocoding(_fetchedCity!);
        } else {
          _showErrorToast('Location Error', 'Unable to determine city from location');
        }
      } else {
        _showErrorToast('Location Error', 'No placemarks found for the current location');
      }
    } on TimeoutException {
      debugPrint('Location request timed out');
      _showErrorToast('Location Error', 'Location request timed out');
    } catch (e, stackTrace) {
      debugPrint('Failed to fetch location: $e\n$stackTrace');
      _showErrorToast('Location Error', 'Failed to fetch location: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _validateCityWithGeocoding(String city) async {
    if (city.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isCityValid = false;
          _isValidatingCity = false;
          _cityController.clear();
        });
      }
      _showErrorToast('Invalid City', 'City cannot be empty');
      return;
    }

    if (mounted) {
      setState(() {
        _isValidatingCity = true;
      });
    }

    final normalizedCity = city.trim();
    final normalizedLower = normalizedCity.toLowerCase();

    // Check hardcoded valid cities
    if (_validCities.containsKey(normalizedLower)) {
      if (mounted) {
        setState(() {
          _cityController.text = _validCities[normalizedLower]!;
          _isCityValid = true;
          _isValidatingCity = false;
        });
      }
      debugPrint('City matched in validCities: ${_validCities[normalizedLower]}');
      return;
    }

    try {
      debugPrint('Geocoding: $normalizedCity, India');
      List<Location> locations = await locationFromAddress('$normalizedCity, India');
      debugPrint('Locations found: ${locations.length}');

      if (locations.isNotEmpty) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          locations.first.latitude,
          locations.first.longitude,
        );
        debugPrint('Placemarks: ${placemarks.map((p) => {
              'locality': p.locality,
              'name': p.name,
              'adminArea': p.administrativeArea,
              'subLocality': p.subLocality,
              'subAdminArea': p.subAdministrativeArea
            }).toList()}');

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final fields = [
            place.locality?.toLowerCase(),
            place.name?.toLowerCase(),
            place.administrativeArea?.toLowerCase(),
            place.subLocality?.toLowerCase(),
            place.subAdministrativeArea?.toLowerCase(),
          ].where((f) => f != null && f.contains(normalizedLower)).toList();

          if (fields.isNotEmpty) {
            if (mounted) {
              setState(() {
                _cityController.text = place.locality ?? normalizedCity;
                _isCityValid = true;
                _isValidatingCity = false;
              });
            }
            debugPrint('City validated: $normalizedCity (matched in $fields)');
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isCityValid = false;
          _isValidatingCity = false;
          _cityController.clear();
        });
        _showErrorToast('Invalid City', 'No matching city found for "$normalizedCity"');
      }
    } catch (e, stackTrace) {
      debugPrint('Geocoding error: $e\n$stackTrace');
      if (_validCities.containsKey(normalizedLower)) {
        if (mounted) {
          setState(() {
            _cityController.text = _validCities[normalizedLower]!;
            _isCityValid = true;
            _isValidatingCity = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isCityValid = false;
            _isValidatingCity = false;
            _cityController.clear();
          });
          _showErrorToast('Invalid City', 'Geocoding failed for "$normalizedCity"');
        }
      }
    }
  }

  void _debounceCityValidation(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 2000), () {
      _validateCityWithGeocoding(value);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    debugPrint('Opening date picker');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: secondaryColor,
              onSurface: textPrimary,
            ),
            dialogBackgroundColor: secondaryColor,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: accentColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await _selectTime(context);
      if (mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
      debugPrint('Selected date: $picked');
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    debugPrint('Opening end date picker');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: _selectedDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: secondaryColor,
              onSurface: textPrimary,
            ),
            dialogBackgroundColor: secondaryColor,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: accentColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedEndDate = picked;
      });
      debugPrint('Selected end date: $picked');
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    debugPrint('Opening time picker');
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: secondaryColor,
              onSurface: textPrimary,
            ),
            dialogBackgroundColor: secondaryColor,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: accentColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedTime = picked;
      });
      debugPrint('Selected time: $picked');
    }
  }

  Future<void> _createTournament() async {
  debugPrint('Starting tournament creation');
  if (!_formKey.currentState!.validate()) {
    debugPrint('Form validation failed');
    return;
  }
  if (_selectedDate == null || _selectedTime == null) {
    debugPrint('Start date or time missing');
    _showErrorToast('Start Date & Time Required', 'Please select a start date and time');
    return;
  }
  if (_selectedEndDate == null) {
    debugPrint('End date missing');
    _showErrorToast('End Date Required', 'Please select an end date');
    return;
  }
  if (!_isCityValid) {
    debugPrint('Invalid city');
    _showErrorToast('Invalid City', 'Please enter a valid Indian city');
    return;
  }

  final startDateTime = DateTime(
    _selectedDate!.year,
    _selectedDate!.month,
    _selectedDate!.day,
    _selectedTime!.hour,
    _selectedTime!.minute,
  );

  final endDate = DateTime(
    _selectedEndDate!.year,
    _selectedEndDate!.month,
    _selectedEndDate!.day,
  );

  if (endDate.isBefore(startDateTime)) {
    debugPrint('Invalid date range: endDate $endDate before startDateTime $startDateTime');
    _showErrorToast('Invalid Date Range', 'End date must be on or after start date');
    return;
  }

  if (mounted) {
    setState(() {
      _isLoading = true;
    });
  }

  try {
    debugPrint('Creating tournament document');
    final tournamentRef = FirebaseFirestore.instance.collection('tournaments').doc();
    final newTournament = Tournament(
      id: tournamentRef.id,
      name: _nameController.text.trim(),
      venue: _venueController.text.trim(),
      city: _cityController.text.trim(),
      startDate: _selectedDate!,
      startTime: _selectedTime!,
      endDate: endDate,
      entryFee: double.tryParse(_entryFeeController.text.trim()) ?? 0.0,
      status: 'open',
      createdBy: widget.userId,
      createdAt: DateTime.now(),
      participants: [],
      rules: _rulesController.text.trim().isNotEmpty ? _rulesController.text.trim() : null,
      maxParticipants: int.tryParse(_maxParticipantsController.text.trim()) ?? 1,
      gameFormat: _playStyle,
      gameType: _eventType,
      bringOwnEquipment: _bringOwnEquipment,
      costShared: _costShared,
      profileImage: null, // Explicitly set to null as it's optional
    );

    final tournamentData = newTournament.toFirestore();
    debugPrint('Tournament data: $tournamentData');

    // Validate only required fields
    if (newTournament.name.isEmpty || newTournament.venue.isEmpty || newTournament.city.isEmpty) {
      throw Exception('Required fields are empty');
    }

    await tournamentRef.set(tournamentData);
    debugPrint('Tournament created successfully: ${newTournament.id}');

    _showSuccessToast(
      'Event Created',
      '"${newTournament.name}" has been successfully created',
    );

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      widget.onTournamentCreated?.call();
    }
  } on FirebaseException catch (e, stackTrace) {
    debugPrint('Firestore error: ${e.code} - ${e.message}\n$stackTrace');
    _showErrorToast('Creation Failed', 'Firestore error: ${e.message}');
  } catch (e, stackTrace) {
    debugPrint('Tournament creation failed: $e\n$stackTrace');
    _showErrorToast('Creation Failed', 'Failed to create event: ${e.toString()}');
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
  void _showSuccessToast(String title, String message) {
    debugPrint('Showing success toast: $title - $message');
    toastification.show(
      context: context,
      type: ToastificationType.success,
      title: Text(title),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
      style: ToastificationStyle.flat,
      alignment: Alignment.bottomCenter,
      backgroundColor: successColor,
      foregroundColor: Colors.white,
    );
  }

  void _showErrorToast(String title, String message) {
    debugPrint('Showing error toast: $title - $message');
    toastification.show(
      context: context,
      type: ToastificationType.error,
      title: Text(title),
      description: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
      style: ToastificationStyle.flat,
      alignment: Alignment.bottomCenter,
      backgroundColor: errorColor,
      foregroundColor: Colors.white,
    );
  }

  String? _validateCity(String? value) {
    if (value == null || value.trim().isEmpty) {
      debugPrint('City validation failed: empty');
      return 'Enter a city';
    }
    if (!_isCityValid) {
      debugPrint('City validation failed: invalid');
      return 'Enter a valid Indian city';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building CreateTournamentPage');
    return Scaffold(
      backgroundColor: primaryColor,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, Color(0xFFE0E0E0)],
            stops: [0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Form(
                  key: _formKey,
                  child: CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        backgroundColor: secondaryColor.withOpacity(0.9),
                        elevation: 2,
                        leading: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 22),
                          onPressed: () {
                            debugPrint('Back button pressed');
                            if (widget.onBackPressed != null) {
                              widget.onBackPressed!();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        title: Text(
                          'Create Tournament',
                          style: GoogleFonts.poppins(
                            color: textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 22,
                          ),
                        ),
                        centerTitle: true,
                        pinned: true,
                        expandedHeight: 60,
                      ),
                      SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 16),
                          _buildSectionHeader('Event Details'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _nameController,
                            label: 'Tournament Name',
                            hintText: 'e.g., Summer Badminton Championship',
                            icon: Icons.event,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Enter a tournament name' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildDropdown(
                            label: 'Tournament Type',
                            value: _eventType,
                            items: [
                              'Knockout',
                              'Round-Robin',
                             'Double Elimination',
                              'Group + Knockout',
                              'Team Format',
                              'Ladder',
                              'Swiss Format',
                            ],
                            onChanged: (value) {
                              if (mounted) {
                                setState(() {
                                  _eventType = value!;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildPlayStyleSelector(),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Location Details'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _venueController,
                            label: 'Venue Name',
                            hintText: 'e.g., City Sports Complex',
                            icon: Icons.location_on,
                            validator: (value) => value == null || value.trim().isEmpty ? 'Enter a venue name' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildCityFieldWithLocation(),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Date & Time'),
                          const SizedBox(height: 12),
                          _buildDateTimeSelector(),
                          const SizedBox(height: 24),
                          _buildSectionHeader('Participation Details'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _entryFeeController,
                                  label: 'Entry Fee (₹)',
                                  hintText: '0 for free entry',
                                  icon: Icons.currency_rupee,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter an entry fee';
                                    }
                                    final fee = double.tryParse(value);
                                    if (fee == null || fee < 0) {
                                      return 'Enter a valid amount';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextField(
                                  controller: _maxParticipantsController,
                                  label: 'Max Participants',
                                  hintText: 'e.g., 32',
                                  icon: Icons.people,
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter max participants';
                                    }
                                    final max = int.tryParse(value);
                                    if (max == null || max <= 0) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildAdditionalSettings(),
                          const SizedBox(height: 32),
                          _buildCreateButton(),
                          const SizedBox(height: 40),
                        ]),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffix,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        style: GoogleFonts.poppins(
          color: textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: accentColor,
        keyboardType: keyboardType,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: textSecondary,
            fontSize: 14,
          ),
          labelStyle: GoogleFonts.poppins(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: icon != null ? Icon(icon, color: accentColor, size: 20) : null,
          suffixIcon: suffix,
          filled: true,
          fillColor: secondaryColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accentColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildCityFieldWithLocation() {
    return Stack(
      children: [
        _buildTextField(
          controller: _cityController,
          label: 'City',
          hintText: 'Select your city',
          icon: Icons.location_city,
          validator: _validateCity,
          onChanged: _debounceCityValidation,
          suffix: _isValidatingCity
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                )
              : Icon(
                  _isCityValid ? Icons.check_circle : Icons.error,
                  color: _isCityValid ? successColor : errorColor,
                  size: 20,
                ),
        ),
        if (!_isFetchingLocation)
          Positioned(
            right: 20,
            top: 4,
            child: IconButton(
              icon: Icon(
                Icons.my_location,
                color: _fetchedCity != null ? accentColor : textSecondary,
                size: 20,
              ),
              onPressed: _fetchedCity != null
                  ? () async {
                      if (mounted) {
                        setState(() {
                          _cityController.text = _fetchedCity!;
                          _isValidatingCity = true;
                        });
                        await _validateCityWithGeocoding(_fetchedCity!);
                        debugPrint('Set city to fetched: $_fetchedCity');
                      }
                    }
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildPlayStyleSelector() {
    const options = [
      "Men's Singles",
      "Women's Singles",
      "Men's Doubles",
      "Women's Doubles",
      'Mixed Doubles',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Play Style',
          style: GoogleFonts.poppins(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final option = options[index];
              return ChoiceChip(
                label: Text(
                  option,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _playStyle == option ? textPrimary : textSecondary,
                  ),
                ),
                selected: _playStyle == option,
                onSelected: (selected) {
                  if (mounted) {
                    setState(() {
                      _playStyle = option;
                    });
                  }
                  debugPrint('Selected play style: $option');
                },
                backgroundColor: secondaryColor,
                selectedColor: highlightColor,
                side: BorderSide(
                  color: _playStyle == option ? accentColor : borderColor,
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                showCheckmark: false,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: secondaryColor,
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: value,
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
            ),
            dropdownColor: secondaryColor,
            icon: Icon(Icons.arrow_drop_down, color: accentColor),
            style: GoogleFonts.poppins(color: textPrimary, fontSize: 15),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: secondaryColor,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: accentColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedDate == null
                            ? 'Start Date'
                            : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                        style: GoogleFonts.poppins(
                          color: _selectedDate == null ? textSecondary : textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => _selectTime(context),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: secondaryColor,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: accentColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedTime == null ? 'Start Time' : _selectedTime!.format(context),
                        style: GoogleFonts.poppins(
                          color: _selectedTime == null ? textSecondary : textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _selectEndDate(context),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: secondaryColor,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: accentColor, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _selectedEndDate == null
                            ? 'End Date'
                            : DateFormat('MMM dd, yyyy').format(_selectedEndDate!),
                        style: GoogleFonts.poppins(
                          color: _selectedEndDate == null ? textSecondary : textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalSettings() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          'Additional Settings',
          style: GoogleFonts.poppins(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        initiallyExpanded: true, // Encourage users to see default rules
        collapsedBackgroundColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        iconColor: accentColor,
        collapsedIconColor: textSecondary,
        children: [
          const SizedBox(height: 8),
          _buildTextField(
            controller: _rulesController,
            label: 'Rules & Guidelines',
            hintText: 'Describe the tournament rules and requirements...',
            icon: Icons.rule,
            maxLines: 4,
            validator: (value) => value == null || value.trim().isEmpty ? 'Please provide some rules' : null,
          ),
          const SizedBox(height: 16),
          _buildSwitchTile(
            title: 'Bring Own Equipment',
            subtitle: 'Participants must bring their own equipment',
            value: _bringOwnEquipment,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _bringOwnEquipment = value;
                });
              }
              debugPrint('Bring own equipment: $value');
            },
          ),
          _buildSwitchTile(
            title: 'Cost Shared',
            subtitle: 'Costs are shared among participants',
            value: _costShared,
            onChanged: (value) {
              if (mounted) {
                setState(() {
                  _costShared = value;
                });
              }
              debugPrint('Cost shared: $value');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: secondaryColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: accentColor,
            inactiveTrackColor: borderColor,
            activeTrackColor: accentColor.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createTournament,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: accentColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                'Create Tournament',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}