import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:game_app/models/tournament.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:toastification/toastification.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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
  tz.TZDateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  tz.TZDateTime? _selectedEndDate;
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
  String _selectedTimezone = 'UTC'; // Default to UTC

  static const Map<String, String> _cityToTimezone = {
    'new york': 'America/New_York',
    'los angeles': 'America/Los_Angeles',
    'california': 'America/Los_Angeles',
    'san francisco': 'America/Los_Angeles',
    'chicago': 'America/Chicago',
    'houston': 'America/Chicago',
    'phoenix': 'America/Phoenix',
    'philadelphia': 'America/New_York',
    'san antonio': 'America/Chicago',
    'san diego': 'America/Los_Angeles',
    'dallas': 'America/Chicago',
    'austin': 'America/Chicago',
    'toronto': 'America/Toronto',
    'montreal': 'America/Toronto',
    'vancouver': 'America/Vancouver',
    'calgary': 'America/Edmonton',
    'ottawa': 'America/Toronto',
    'mexico city': 'America/Mexico_City',
    'tijuana': 'America/Tijuana',
    'monterrey': 'America/Monterrey',
    'london': 'Europe/London',
    'paris': 'Europe/Paris',
    'berlin': 'Europe/Berlin',
    'rome': 'Europe/Rome',
    'madrid': 'Europe/Madrid',
    'mumbai': 'Asia/Kolkata',
    'delhi': 'Asia/Kolkata',
    'bangalore': 'Asia/Kolkata',
    'hyderabad': 'Asia/Kolkata',
    'chennai': 'Asia/Kolkata',
    'kolkata': 'Asia/Kolkata',
    'singapore': 'Asia/Singapore',
    'tokyo': 'Asia/Tokyo',
    'beijing': 'Asia/Shanghai',
    'shanghai': 'Asia/Shanghai',
    'hong kong': 'Asia/Hong_Kong',
    'dubai': 'Asia/Dubai',
    'sydney': 'Australia/Sydney',
    'melbourne': 'Australia/Melbourne',
    'brisbane': 'Australia/Brisbane',
    'perth': 'Australia/Perth',
    'sao paulo': 'America/Sao_Paulo',
    'rio de janeiro': 'America/Sao_Paulo',
    'buenos aires': 'America/Argentina/Buenos_Aires',
    'lima': 'America/Lima',
    'cairo': 'Africa/Cairo',
    'nairobi': 'Africa/Nairobi',
    'lagos': 'Africa/Lagos',
    'johannesburg': 'Africa/Johannesburg',
  };

  static const List<String> _allTimezones = [
   'UTC',
    'Africa/Abidjan',
    'Africa/Accra',
    'Africa/Addis_Ababa',
    'Africa/Algiers',
    'Africa/Asmara',
    'Africa/Bamako',
    'Africa/Bangui',
    'Africa/Banjul',
    'Africa/Bissau',
    'Africa/Blantyre',
    'Africa/Brazzaville',
    'Africa/Bujumbura',
    'Africa/Cairo',
    'Africa/Casablanca',
    'Africa/Ceuta',
    'Africa/Conakry',
    'Africa/Dakar',
    'Africa/Dar_es_Salaam',
    'Africa/Djibouti',
    'Africa/Douala',
    'Africa/El_Aaiun',
    'Africa/Freetown',
    'Africa/Gaborone',
    'Africa/Harare',
    'Africa/Johannesburg',
    'Africa/Juba',
    'Africa/Kampala',
    'Africa/Khartoum',
    'Africa/Kigali',
    'Africa/Kinshasa',
    'Africa/Lagos',
    'Africa/Libreville',
    'Africa/Lome',
    'Africa/Luanda',
    'Africa/Lubumbashi',
    'Africa/Lusaka',
    'Africa/Malabo',
    'Africa/Maputo',
    'Africa/Maseru',
    'Africa/Mbabane',
    'Africa/Mogadishu',
    'Africa/Monrovia',
    'Africa/Nairobi',
    'Africa/Ndjamena',
    'Africa/Niamey',
    'Africa/Nouakchott',
    'Africa/Ouagadougou',
    'Africa/Porto-Novo',
    'Africa/Sao_Tome',
    'Africa/Tripoli',
    'Africa/Tunis',
    'Africa/Windhoek',
    'America/Adak',
    'America/Anchorage',
    'America/Anguilla',
    'America/Antigua',
    'America/Araguaina',
    'America/Argentina/Buenos_Aires',
    'America/Argentina/Catamarca',
    'America/Argentina/Cordoba',
    'America/Argentina/Jujuy',
    'America/Argentina/La_Rioja',
    'America/Argentina/Mendoza',
    'America/Argentina/Rio_Gallegos',
    'America/Argentina/Salta',
    'America/Argentina/San_Juan',
    'America/Argentina/San_Luis',
    'America/Argentina/Tucuman',
    'America/Argentina/Ushuaia',
    'America/Aruba',
    'America/Asuncion',
    'America/Atikokan',
    'America/Bahia',
    'America/Bahia_Banderas',
    'America/Barbados',
    'America/Belem',
    'America/Belize',
    'America/Blanc-Sablon',
    'America/Boa_Vista',
    'America/Bogota',
    'America/Boise',
    'America/Cambridge_Bay',
    'America/Campo_Grande',
    'America/Cancun',
    'America/Caracas',
    'America/Cayenne',
    'America/Cayman',
    'America/Chicago',
    'America/Chihuahua',
    'America/Costa_Rica',
    'America/Creston',
    'America/Cuiaba',
    'America/Curacao',
    'America/Danmarkshavn',
    'America/Dawson',
    'America/Dawson_Creek',
    'America/Denver',
    'America/Detroit',
    'America/Dominica',
    'America/Edmonton',
    'America/Eirunepe',
    'America/El_Salvador',
    'America/Fort_Nelson',
    'America/Fortaleza',
    'America/Glace_Bay',
    'America/Godthab',
    'America/Goose_Bay',
    'America/Grand_Turk',
    'America/Grenada',
    'America/Guadeloupe',
    'America/Guatemala',
    'America/Guayaquil',
    'America/Guyana',
    'America/Halifax',
    'America/Havana',
    'America/Hermosillo',
    'America/Indiana/Indianapolis',
    'America/Indiana/Knox',
    'America/Indiana/Marengo',
    'America/Indiana/Petersburg',
    'America/Indiana/Tell_City',
    'America/Indiana/Vevay',
    'America/Indiana/Vincennes',
    'America/Indiana/Winamac',
    'America/Inuvik',
    'America/Iqaluit',
    'America/Jamaica',
    'America/Juneau',
    'America/Kentucky/Louisville',
    'America/Kentucky/Monticello',
    'America/Kralendijk',
    'America/La_Paz',
    'America/Lima',
    'America/Los_Angeles',
    'America/Lower_Princes',
    'America/Maceio',
    'America/Managua',
    'America/Manaus',
    'America/Marigot',
    'America/Martinique',
    'America/Matamoros',
    'America/Mazatlan',
    'America/Menominee',
    'America/Merida',
    'America/Metlakatla',
    'America/Mexico_City',
    'America/Miquelon',
    'America/Moncton',
    'America/Monterrey',
    'America/Montevideo',
    'America/Montserrat',
    'America/Nassau',
    'America/New_York',
    'America/Nipigon',
    'America/Nome',
    'America/Noronha',
    'America/North_Dakota/Beulah',
    'America/North_Dakota/Center',
    'America/North_Dakota/New_Salem',
    'America/Ojinaga',
    'America/Panama',
    'America/Pangnirtung',
    'America/Paramaribo',
    'America/Phoenix',
    'America/Port-au-Prince',
    'America/Port_of_Spain',
    'America/Porto_Velho',
    'America/Puerto_Rico',
    'America/Punta_Arenas',
    'America/Rainy_River',
    'America/Rankin_Inlet',
    'America/Recife',
    'America/Regina',
    'America/Resolute',
    'America/Rio_Branco',
    'America/Santarem',
    'America/Santo_Domingo',
    'America/Sao_Paulo',
    'America/Scoresbysund',
    'America/Sitka',
    'America/St_Barthelemy',
    'America/St_Johns',
    'America/St_Kitts',
    'America/St_Lucia',
    'America/St_Thomas',
    'America/St_Vincent',
    'America/Swift_Current',
    'America/Tegucigalpa',
    'America/Thule',
    'America/Thunder_Bay',
    'America/Tijuana',
    'America/Toronto',
    'America/Tortola',
    'America/Vancouver',
    'America/Whitehorse',
    'America/Winnipeg',
    'America/Yakutat',
    'America/Yellowknife',
    'Antarctica/Casey',
    'Antarctica/Davis',
    'Antarctica/DumontDUrville',
    'Antarctica/Macquarie',
    'Antarctica/Mawson',
    'Antarctica/McMurdo',
    'Antarctica/Palmer',
    'Antarctica/Rothera',
    'Antarctica/Syowa',
    'Antarctica/Troll',
    'Antarctica/Vostok',
    'Asia/Almaty',
    'Asia/Amman',
    'Asia/Anadyr',
    'Asia/Aqtau',
    'Asia/Aqtobe',
    'Asia/Ashgabat',
    'Asia/Atyrau',
    'Asia/Baghdad',
    'Asia/Bahrain',
    'Asia/Baku',
    'Asia/Bangkok',
    'Asia/Barnaul',
    'Asia/Beirut',
    'Asia/Bishkek',
    'Asia/Brunei',
    'Asia/Chita',
    'Asia/Choibalsan',
    'Asia/Colombo',
    'Asia/Damascus',
    'Asia/Dhaka',
    'Asia/Dili',
    'Asia/Dubai',
    'Asia/Dushanbe',
    'Asia/Famagusta',
    'Asia/Gaza',
    'Asia/Hebron',
    'Asia/Ho_Chi_Minh',
    'Asia/Hong_Kong',
    'Asia/Hovd',
    'Asia/Irkutsk',
    'Asia/Jakarta',
    'Asia/Jayapura',
    'Asia/Jerusalem',
    'Asia/Kabul',
    'Asia/Kamchatka',
    'Asia/Karachi',
    'Asia/Kathmandu',
    'Asia/Khandyga',
    'Asia/Kolkata',
    'Asia/Krasnoyarsk',
    'Asia/Kuala_Lumpur',
    'Asia/Kuching',
    'Asia/Kuwait',
    'Asia/Macau',
    'Asia/Magadan',
    'Asia/Makassar',
    'Asia/Manila',
    'Asia/Muscat',
    'Asia/Nicosia',
    'Asia/Novokuznetsk',
    'Asia/Novosibirsk',
    'Asia/Omsk',
    'Asia/Oral',
    'Asia/Phnom_Penh',
    'Asia/Pontianak',
    'Asia/Pyongyang',
    'Asia/Qatar',
    'Asia/Qostanay',
    'Asia/Qyzylorda',
    'Asia/Riyadh',
    'Asia/Sakhalin',
    'Asia/Samarkand',
    'Asia/Seoul',
    'Asia/Shanghai',
    'Asia/Singapore',
    'Asia/Srednekolymsk',
    'Asia/Taipei',
    'Asia/Tashkent',
    'Asia/Tbilisi',
    'Asia/Tehran',
    'Asia/Thimphu',
    'Asia/Tokyo',
    'Asia/Tomsk',
    'Asia/Ulaanbaatar',
    'Asia/Urumqi',
    'Asia/Ust-Nera',
    'Asia/Vientiane',
    'Asia/Vladivostok',
    'Asia/Yakutsk',
    'Asia/Yangon',
    'Asia/Yekaterinburg',
    'Asia/Yerevan',
    'Atlantic/Azores',
    'Atlantic/Bermuda',
    'Atlantic/Canary',
    'Atlantic/Cape_Verde',
    'Atlantic/Faroe',
    'Atlantic/Madeira',
    'Atlantic/Reykjavik',
    'Atlantic/South_Georgia',
    'Atlantic/St_Helena',
    'Atlantic/Stanley',
    'Australia/Adelaide',
    'Australia/Brisbane',
    'Australia/Broken_Hill',
    'Australia/Currie',
    'Australia/Darwin',
    'Australia/Eucla',
    'Australia/Hobart',
    'Australia/Lindeman',
    'Australia/Lord_Howe',
    'Australia/Melbourne',
    'Australia/Perth',
    'Australia/Sydney',
    'Europe/Amsterdam',
    'Europe/Andorra',
    'Europe/Astrakhan',
    'Europe/Athens',
    'Europe/Belgrade',
    'Europe/Berlin',
    'Europe/Bratislava',
    'Europe/Brussels',
    'Europe/Bucharest',
    'Europe/Budapest',
    'Europe/Busingen',
    'Europe/Chisinau',
    'Europe/Copenhagen',
    'Europe/Dublin',
    'Europe/Gibraltar',
    'Europe/Guernsey',
    'Europe/Helsinki',
    'Europe/Isle_of_Man',
    'Europe/Istanbul',
    'Europe/Jersey',
    'Europe/Kaliningrad',
    'Europe/Kiev',
    'Europe/Kirov',
    'Europe/Lisbon',
    'Europe/Ljubljana',
    'Europe/London',
    'Europe/Luxembourg',
    'Europe/Madrid',
    'Europe/Malta',
    'Europe/Mariehamn',
    'Europe/Minsk',
    'Europe/Monaco',
    'Europe/Moscow',
    'Europe/Oslo',
    'Europe/Paris',
    'Europe/Podgorica',
    'Europe/Prague',
    'Europe/Riga',
    'Europe/Rome',
    'Europe/Samara',
    'Europe/San_Marino',
    'Europe/Sarajevo',
    'Europe/Saratov',
    'Europe/Simferopol',
    'Europe/Skopje',
    'Europe/Sofia',
    'Europe/Stockholm',
    'Europe/Tallinn',
    'Europe/Tirane',
    'Europe/Ulyanovsk',
    'Europe/Uzhgorod',
    'Europe/Vaduz',
    'Europe/Vatican',
    'Europe/Vienna',
    'Europe/Vilnius',
    'Europe/Volgograd',
    'Europe/Warsaw',
    'Europe/Zagreb',
    'Europe/Zaporozhye',
    'Europe/Zurich',
    'Indian/Antananarivo',
    'Indian/Chagos',
    'Indian/Christmas',
    'Indian/Cocos',
    'Indian/Comoro',
    'Indian/Kerguelen',
    'Indian/Mahe',
    'Indian/Maldives',
    'Indian/Mauritius',
    'Indian/Mayotte',
    'Indian/Reunion',
    'Pacific/Apia',
    'Pacific/Auckland',
    'Pacific/Bougainville',
    'Pacific/Chatham',
    'Pacific/Chuuk',
    'Pacific/Easter',
    'Pacific/Efate',
    'Pacific/Enderbury',
    'Pacific/Fakaofo',
    'Pacific/Fiji',
    'Pacific/Funafuti',
    'Pacific/Galapagos',
    'Pacific/Gambier',
    'Pacific/Guadalcanal',
    'Pacific/Guam',
    'Pacific/Honolulu',
    'Pacific/Kiritimati',
    'Pacific/Kosrae',
    'Pacific/Kwajalein',
    'Pacific/Majuro',
    'Pacific/Marquesas',
    'Pacific/Midway',
    'Pacific/Nauru',
    'Pacific/Niue',
    'Pacific/Norfolk',
    'Pacific/Noumea',
    'Pacific/Pago_Pago',
    'Pacific/Palau',
    'Pacific/Pitcairn',
    'Pacific/Pohnpei',
    'Pacific/Port_Moresby',
    'Pacific/Rarotonga',
    'Pacific/Saipan',
    'Pacific/Tahiti',
    'Pacific/Tarawa',
    'Pacific/Tongatapu',
    'Pacific/Wake',
    'Pacific/Wallis',
    'Etc/GMT',
    'Etc/GMT+1',
    'Etc/GMT+2',
    'Etc/GMT+3',
    'Etc/GMT+4',
    'Etc/GMT+5',
    'Etc/GMT+6',
    'Etc/GMT+7',
    'Etc/GMT+8',
    'Etc/GMT+9',
    'Etc/GMT+10',
    'Etc/GMT+11',
    'Etc/GMT+12',
    'Etc/GMT-1',
    'Etc/GMT-2',
    'Etc/GMT-3',
    'Etc/GMT-4',
    'Etc/GMT-5',
    'Etc/GMT-6',
    'Etc/GMT-7',
    'Etc/GMT-8',
    'Etc/GMT-9',
    'Etc/GMT-10',
    'Etc/GMT-11',
    'Etc/GMT-12',
    'Etc/GMT-13',
    'Etc/GMT-14',
    'Etc/UTC',
  ];

  @override
  void initState() {
    super.initState();
    _rulesController.text = _defaultRules();
    _initializeAnimations();
    _initLocationServices();
    tz.initializeTimeZones();
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

  Future<void> _validateCityWithGeocoding(String city) async {
    if (city.isEmpty) {
      setState(() {
        _isCityValid = false;
        _selectedTimezone = 'UTC';
      });
      return;
    }

    setState(() {
      _isValidatingCity = true;
    });

    final timezone = _getTimezoneForCity(city);
    try {
      tz.getLocation(timezone);
      setState(() {
        _isCityValid = true;
        _selectedTimezone = timezone;
        _isValidatingCity = false;
      });
    } catch (e) {
      try {
        final locations = await locationFromAddress(city);
        if (locations.isEmpty) {
          throw Exception('No location found');
        }

        final place = locations.first;
        final placemarks = await placemarkFromCoordinates(place.latitude, place.longitude);
        final countryCode = placemarks.first.isoCountryCode?.toLowerCase();
        final timezone = _getCountryTimezone(countryCode) ?? 'UTC';

        try {
          tz.getLocation(timezone);
          setState(() {
            _isCityValid = true;
            _selectedTimezone = timezone;
            _isValidatingCity = false;
          });
        } catch (e) {
          setState(() {
            _isCityValid = false;
            _selectedTimezone = 'UTC';
            _isValidatingCity = false;
          });
        }
      } catch (e) {
        setState(() {
          _isCityValid = false;
          _selectedTimezone = 'UTC';
          _isValidatingCity = false;
        });
      }
    }
  }

  String? _getCountryTimezone(String? countryCode) {
    const countryTimezones = {
      'in': 'Asia/Kolkata',
      'au': 'Australia/Sydney',
      'gb': 'Europe/London',
      'us': 'America/Los_Angeles',
      'jp': 'Asia/Tokyo',
      'cn': 'Asia/Shanghai',
      'sg': 'Asia/Singapore',
      'ae': 'Asia/Dubai',
      'ru': 'Europe/Moscow',
      'fr': 'Europe/Paris',
      'de': 'Europe/Berlin',
    };
    return countryCode != null ? countryTimezones[countryCode.toLowerCase()] : null;
  }

  String _getTimezoneForCity(String city) {
    final cityLower = city.toLowerCase().trim();
    if (_cityToTimezone.containsKey(cityLower)) {
      return _cityToTimezone[cityLower]!;
    }
    if (cityLower.contains('california') || 
        cityLower.contains('san francisco') || 
        cityLower.contains('los angeles') ||
        cityLower.contains('san diego')) {
      return 'America/Los_Angeles';
    }
    if (cityLower.contains('texas') || 
        cityLower.contains('houston') || 
        cityLower.contains('dallas') ||
        cityLower.contains('austin')) {
      return 'America/Chicago';
    }
    if (cityLower.contains('new york')) {
      return 'America/New_York';
    }
    final countryTimezone = _getCountryTimezone(cityLower);
    return countryTimezone ?? 'UTC';
  }

  Future<void> _selectDate(BuildContext context) async {
    final timeZone = tz.getLocation(_selectedTimezone);
    final now = tz.TZDateTime.now(timeZone);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: secondaryColor,
              onSurface: textPrimary,
            ),
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
        _selectedDate = tz.TZDateTime(
          timeZone,
          picked.year,
          picked.month,
          picked.day,
        );
      });
      debugPrint('Selected start date: $_selectedDate');
      await _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final timeZone = tz.getLocation(_selectedTimezone);
    final now = tz.TZDateTime.now(timeZone);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: accentColor,
              onPrimary: Colors.white,
              surface: secondaryColor,
              onSurface: textPrimary,
            ),
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
      debugPrint('Selected start time: $_selectedTime');
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    debugPrint('Opening end date picker');
    final timeZone = tz.getLocation(_selectedTimezone);
    final initialDate = _selectedDate ?? tz.TZDateTime.now(timeZone);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: initialDate,
      lastDate: tz.TZDateTime.now(timeZone).add(const Duration(days: 365 * 2)),
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
        _selectedEndDate = tz.TZDateTime(
          timeZone,
          picked.year,
          picked.month,
          picked.day,
        );
      });
      debugPrint('Selected end date: $_selectedEndDate');
    }
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
          final cityLower = city.toLowerCase();
          String timezoneName = _getTimezoneForCity(cityLower);
          try {
            tz.getLocation(timezoneName);
            setState(() {
              _fetchedCity = city;
              _isCityValid = true;
              _selectedTimezone = timezoneName;
            });
            debugPrint('Set city to $city with timezone $timezoneName');
          } catch (e) {
            debugPrint('Invalid timezone from location: $timezoneName, defaulting to UTC');
            setState(() {
              _fetchedCity = city;
              _isCityValid = true;
              _selectedTimezone = 'UTC';
            });
            _showErrorToast('Timezone Error', 'Could not determine timezone for $city, defaulting to UTC');
          }
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

  void _debounceCityValidation(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 2000), () {
      _validateCityWithGeocoding(value);
    });
  }

  Future<void> _createTournament() async {
    debugPrint('Starting tournament creation');
    if (!_formKey.currentState!.validate()) {
      debugPrint('Form validation failed');
      return;
    }

    // Validate required date/time fields
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
      _showErrorToast('Invalid City', 'Please enter a valid city');
      return;
    }

    // Get the selected timezone
    final timeZone = tz.getLocation(_selectedTimezone);

    // Combine date and time in the selected timezone
    final startDateTimeLocal = tz.TZDateTime(
      timeZone,
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // Convert to UTC for storage
    final startDateTimeUTC = startDateTimeLocal.toUtc();

    // Create end date at end of day in local timezone
    final endDateLocal = tz.TZDateTime(
      timeZone,
      _selectedEndDate!.year,
      _selectedEndDate!.month,
      _selectedEndDate!.day,
      23, 59, 59,
    );

    // Convert to UTC for storage
    final endDateUTC = endDateLocal.toUtc();

    // Validate date ranges
    if (endDateUTC.isBefore(startDateTimeUTC)) {
      debugPrint('Invalid date range: endDate $endDateUTC before startDateTime $startDateTimeUTC');
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
        startDate: startDateTimeUTC,
        endDate: endDateUTC,
        entryFee: double.tryParse(_entryFeeController.text.trim()) ?? 0.0,
        status: 'open',
        createdBy: widget.userId,
        createdAt: DateTime.now().toUtc(),
        participants: [],
        rules: _rulesController.text.trim().isNotEmpty ? _rulesController.text.trim() : null,
        maxParticipants: int.tryParse(_maxParticipantsController.text.trim()) ?? 1,
        gameFormat: _playStyle,
        gameType: _eventType,
        bringOwnEquipment: _bringOwnEquipment,
        costShared: _costShared,
        profileImage: null,
        timezone: _selectedTimezone,
      );

      final tournamentData = newTournament.toFirestore();
      debugPrint('Tournament data: $tournamentData');

      // Final validation
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
                          const SizedBox(height: 16),
                          _buildTimezoneSelector(),
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
                                  label: 'Entry Fee (\$)',
                                  hintText: '0 for free entry',
                                  icon: Icons.attach_money,
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

  Widget _buildTimezoneSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timezone',
          style: GoogleFonts.poppins(
            color: textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showTimezoneDialog(context),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: secondaryColor,
              border: Border.all(color: borderColor, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _selectedTimezone == 'Asia/Kolkata'
                        ? 'IST ($_selectedTimezone)'
                        : _selectedTimezone,
                    style: GoogleFonts.poppins(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: accentColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTimezoneDialog(BuildContext context) async {
    String searchQuery = '';
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredTimezones = _allTimezones
                .where((timezone) => timezone.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return AlertDialog(
              backgroundColor: secondaryColor,
              title: Text(
                'Select Timezone',
                style: GoogleFonts.poppins(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Search timezones...',
                        hintStyle: GoogleFonts.poppins(color: textSecondary),
                        prefixIcon: Icon(Icons.search, color: accentColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: accentColor),
                        ),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: filteredTimezones.length,
                        itemBuilder: (context, index) {
                          final timezone = filteredTimezones[index];
                          return ListTile(
                            title: Text(
                              timezone == 'Asia/Kolkata' ? 'IST ($timezone)' : timezone,
                              style: GoogleFonts.poppins(
                                color: textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedTimezone = timezone;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: accentColor),
                  ),
                ),
              ],
            );
          },
        );
      },
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
    final timeZone = tz.getLocation(_selectedTimezone);
    final startDateLocal = _selectedDate != null ? tz.TZDateTime.from(_selectedDate!, timeZone) : null;
    final startTime = _selectedTime ?? (startDateLocal != null
        ? TimeOfDay(hour: startDateLocal.hour, minute: startDateLocal.minute)
        : null);
    final endDateLocal = _selectedEndDate != null ? tz.TZDateTime.from(_selectedEndDate!, timeZone) : null;

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
                        startDateLocal == null
                            ? 'Start Date'
                            : DateFormat('MMM dd, yyyy').format(startDateLocal),
                        style: GoogleFonts.poppins(
                          color: startDateLocal == null ? textSecondary : textPrimary,
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
                        startTime == null ? 'Start Time' : startTime.format(context),
                        style: GoogleFonts.poppins(
                          color: startTime == null ? textSecondary : textPrimary,
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
                        endDateLocal == null
                            ? 'End Date'
                            : DateFormat('MMM dd, yyyy').format(endDateLocal),
                        style: GoogleFonts.poppins(
                          color: endDateLocal == null ? textSecondary : textPrimary,
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
        if (_selectedDate != null && _selectedTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Time in ${_selectedTimezone == 'Asia/Kolkata' ? 'IST' : _selectedTimezone}',
              style: GoogleFonts.poppins(
                color: textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
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
        initiallyExpanded: true,
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