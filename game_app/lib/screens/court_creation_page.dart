import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:game_app/blocs/auth/auth_bloc.dart';
import 'package:game_app/blocs/auth/auth_state.dart';
import 'package:game_app/models/court.dart';
import 'package:game_app/widgets/court_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:toastification/toastification.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

class CourtCreationPage extends StatefulWidget {
  final String userCity; // Add userCity parameter

  const CourtCreationPage({super.key, required this.userCity});

  @override
  _CourtCreationPageState createState() => _CourtCreationPageState();
}

class _CourtCreationPageState extends State<CourtCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final List<TimeSlot> _timeSlots = [];
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isCityValid = false;
  bool _isLoadingLocation = false;
  bool _locationFetchCompleted = false;
  String _location = ''; // Local location to override widget.userCity
// Track if user has set a location
  String? _selectedCourtType;
  final List<String> _courtTypes = ['Indoor', 'Outdoor', 'Synthetic'];
  final List<String> _validCities = [
    'hyderabad',
    'mumbai',
    'delhi',
    'bengaluru',
    'chennai',
    'kolkata',
    'pune',
    'ahmedabad',
    'jaipur',
    'lucknow',
  ];

  @override
  void initState() {
    super.initState();
    print('CourtCreationPage initialized with userCity: "${widget.userCity}"');
    _location = widget.userCity; // Initialize with passed userCity
    _cityController.text = widget.userCity; // Pre-fill city field
    _validateUserCity();
  }

  Future<void> _validateUserCity() async {
    setState(() {
    });
    final isValid = await _validateCity(widget.userCity);
    setState(() {
      _isCityValid = isValid;
    });
    print('User city validation result: $_isCityValid');
    if (!isValid && widget.userCity.isNotEmpty && widget.userCity.toLowerCase() != 'unknown') {
      toastification.show(
        context: context,
        type: ToastificationType.warning,
        title: const Text('Invalid City'),
        description: Text(
            'The city "${widget.userCity}" is invalid. Please select a valid city like Hyderabad, Mumbai, etc.'),
        autoCloseDuration: const Duration(seconds: 5),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        alignment: Alignment.bottomCenter,
      );
    }
  }

  Future<bool> _validateCity(String city) async {
    final trimmedCity = city.trim().toLowerCase();

    if (trimmedCity.isEmpty) return false;
    if (trimmedCity.length < 5) return false;

    if (!_validCities.contains(trimmedCity)) {
      print('City "$trimmedCity" not in valid cities list, proceeding with geocoding');
    }

    try {
      List<Location> locations = await locationFromAddress(city).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Timed out while validating city');
        },
      );
      if (locations.isEmpty) return false;

      List<Placemark> placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        throw Exception('Timed out while geocoding');
      });

      if (placemarks.isEmpty) return false;

      Placemark place = placemarks[0];
      final geocodedLocality = place.locality?.toLowerCase() ?? '';

      if (geocodedLocality != trimmedCity) {
        print('Geocoded locality "$geocodedLocality" does not exactly match input "$trimmedCity"');
        return false;
      }

      if (place.locality == null || place.country == null) return false;

      return true;
    } catch (e) {
      print('City validation error: $e');
      return false;
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final initialTime = TimeOfDay.fromDateTime(now);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (pickedTime != null) {
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      setState(() {
        if (isStart) {
          _startTime = selectedDateTime;
        } else {
          _endTime = selectedDateTime;
        }
      });
    }
  }

  void _showLocationSearchDialog() {
    final TextEditingController locationController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Set Location',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter city (e.g., Mumbai)',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final city = locationController.text.trim();
                          if (city.isNotEmpty) {
                            setState(() {
                              _isLoadingLocation = true;
                              _locationFetchCompleted = false;
                            });
                            final isValid = await _validateCity(city);
                            setState(() {
                              _isLoadingLocation = false;
                              _locationFetchCompleted = true;
                              if (isValid) {
                                _location = city;
                                _cityController.text = city;
                                _isCityValid = true;
                              } else {
                                _location = 'Invalid Location';
                                _isCityValid = false;
                                toastification.show(
                                  context: context,
                                  type: ToastificationType.warning,
                                  title: const Text('Invalid City'),
                                  description: Text(
                                      'The city "$city" is invalid. Please select a valid city like Hyderabad, Mumbai, etc.'),
                                  autoCloseDuration: const Duration(seconds: 5),
                                  backgroundColor: Colors.grey[800],
                                  foregroundColor: Colors.white,
                                  alignment: Alignment.bottomCenter,
                                );
                              }
                            });
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Set Location',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12,
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
        );
      },
    );
  }

  void _addTimeSlot() {
    if (_startTime != null && _endTime != null && _startTime!.isBefore(_endTime!)) {
      setState(() {
        _timeSlots.add(TimeSlot(
          startTime: _startTime!,
          endTime: _endTime!,
        ));
        _startTime = null;
        _endTime = null;
      });
    } else {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Invalid Time Slot'),
        description: const Text('Please select a valid start and end time.'),
        autoCloseDuration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      );
    }
  }

  void _createCourt() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Authentication Required'),
        description: const Text('Please log in to create a court.'),
        autoCloseDuration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      );
      return;
    }

    if (_formKey.currentState!.validate() && _timeSlots.isNotEmpty) {
      final court = Court(
        id: 'court_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        type: _selectedCourtType!,
        venue: _venueController.text,
        city: _cityController.text,
        latitude: null, // No longer storing latitude/longitude
        longitude: null,
        availableSlots: _timeSlots,
        createdBy: authState.user.uid,
        createdAt: DateTime.now(),
      );

      try {
        await CourtRepository().addCourt(court);

        toastification.show(
          context: context,
          type: ToastificationType.success,
          title: const Text('Court Created'),
          description: Text('Court ${_nameController.text} has been created.'),
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        );

        Navigator.pop(context);
      } catch (e) {
        toastification.show(
          context: context,
          type: ToastificationType.error,
          title: const Text('Creation Failed'),
          description: Text('Failed to create court: $e'),
          autoCloseDuration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        );
      }
    } else {
      toastification.show(
        context: context,
        type: ToastificationType.error,
        title: const Text('Creation Failed'),
        description: const Text('Please fill in all fields and add at least one time slot.'),
        autoCloseDuration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _venueController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF3A506B),
                Color(0xFF1C2541),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white70,
            size: 28,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Badminton Blitz',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 24,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: _showLocationSearchDialog,
              child: Row(
                children: [
                  Icon(Icons.location_pin, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  _isLoadingLocation && !_locationFetchCompleted
                      ? SizedBox(
                          width: 100,
                          height: 20,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                        )
                      : Flexible(
                          child: Text(
                            _location,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (!_isCityValid || _location.isEmpty || _location.toLowerCase() == 'unknown')
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off,
                        color: Colors.white70,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please set your location to create a court.',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _showLocationSearchDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey[700],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Set Location',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _location = 'Hyderabad';
                                _cityController.text = 'Hyderabad';
                                _isCityValid = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                'Use Default (Hyderabad)',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
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
            )
          else
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fill in the details to add a new court.',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _nameController,
                          label: 'Court Name',
                          hint: 'e.g., Central Park Court',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a court name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCourtType,
                          decoration: InputDecoration(
                            labelText: 'Court Type',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
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
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                          dropdownColor: const Color(0xFF1B263B),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          items: _courtTypes.map((type) {
                            return DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCourtType = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a court type';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _venueController,
                          label: 'Venue',
                          hint: 'e.g., Central Park',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a venue';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _cityController,
                          label: 'City',
                          hint: 'e.g., Mumbai',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a city';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Add Time Slots',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select available time slots for your court.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectTime(context, true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    _startTime != null
                                        ? DateFormat('h:mm a').format(_startTime!)
                                        : 'Select Start Time',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _selectTime(context, false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    _endTime != null
                                        ? DateFormat('h:mm a').format(_endTime!)
                                        : 'Select End Time',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
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
                              child: ElevatedButton(
                                onPressed: _addTimeSlot,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  backgroundColor: Colors.blue.withOpacity(0.8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  elevation: 5,
                                ),
                                child: Text(
                                  'Add Time Slot',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_timeSlots.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _timeSlots.map((slot) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${DateFormat('h:mm a').format(slot.startTime)} - ${DateFormat('h:mm a').format(slot.endTime)}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _timeSlots.remove(slot);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _createCourt,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.green.withOpacity(0.8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  shadowColor: Colors.black.withOpacity(0.3),
                                  elevation: 5,
                                ),
                                child: Text(
                                  'Create Court',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.poppins(
          color: Colors.white38,
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.2),
          ),
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
            color: Colors.blue,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 14,
      ),
      validator: validator,
    );
  }
}