import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Haversine;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database_helper.dart';
import '../models/faskes.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/haversine.dart';

class RouteInstruction {
  final String text;
  final double distance;
  final String modifier;
  RouteInstruction({required this.text, required this.distance, required this.modifier});
}

class RouteData {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;
  final List<RouteInstruction> instructions;
  
  RouteData({
    required this.points, 
    required this.distanceKm, 
    required this.durationMinutes,
    this.instructions = const [],
  });
}

class AppProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();

  AppProvider() {
    _initConnectivity();
  }

  // ─── Connectivity State ──────────────────────────────────────────────────────
  bool _hasInternet = true;
  bool get hasInternet => _hasInternet;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    _hasInternet = !result.contains(ConnectivityResult.none);
    
    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      _hasInternet = !results.contains(ConnectivityResult.none);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  // ─── User State ─────────────────────────────────────────────────────────────
  User? _currentUser;
  User? get currentUser => _currentUser;

  // ─── Faskes State ────────────────────────────────────────────────────────────
  List<Faskes> _allFaskes = [];
  List<Faskes> _filteredFaskes = [];
  List<Faskes> get allFaskes => _allFaskes;
  List<Faskes> get filteredFaskes => _filteredFaskes;

  String _selectedFilter = 'Semua';
  String get selectedFilter => _selectedFilter;

  String _searchQuery = '';
  
  // ─── Search History ──────────────────────────────────────────────────────────
  List<String> _searchHistory = [];
  List<String> get searchHistory => _searchHistory;
  static const String _historyKey = 'search_history';

  Future<void> loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _searchHistory = prefs.getStringList(_historyKey) ?? [];
    notifyListeners();
  }

  Future<void> addSearchHistory(String query) async {
    final trimQuery = query.trim();
    if (trimQuery.isEmpty) return;
    
    _searchHistory.remove(trimQuery);
    _searchHistory.insert(0, trimQuery);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, _searchHistory);
    notifyListeners();
  }

  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    notifyListeners();
  }

  // ─── Favorites ───────────────────────────────────────────────────────────────
  List<String> _favoriteFaskesIds = [];
  List<String> get favoriteFaskesIds => _favoriteFaskesIds;
  static const String _favKey = 'favorite_faskes';

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteFaskesIds = prefs.getStringList(_favKey) ?? [];
    notifyListeners();
  }

  Future<void> toggleFavorite(Faskes faskes) async {
    if (faskes.id == null) return;
    final idStr = faskes.id.toString();
    if (_favoriteFaskesIds.contains(idStr)) {
      _favoriteFaskesIds.remove(idStr);
    } else {
      _favoriteFaskesIds.add(idStr);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favKey, _favoriteFaskesIds);
    _applyFilter();
    notifyListeners();
  }

  bool isFavorite(Faskes faskes) {
    if (faskes.id == null) return false;
    return _favoriteFaskesIds.contains(faskes.id.toString());
  }

  // ─── Stats ───────────────────────────────────────────────────────────────────
  int _totalFaskes = 0;
  int _totalRumahSakit = 0;
  int _totalPuskesmas = 0;
  int _totalKlinik = 0;
  int _totalApotek = 0;
  int _totalLaboratorium = 0;
  int get totalFaskes => _totalFaskes;
  int get totalRumahSakit => _totalRumahSakit;
  int get totalPuskesmas => _totalPuskesmas;
  int get totalKlinik => _totalKlinik;
  int get totalApotek => _totalApotek;
  int get totalLaboratorium => _totalLaboratorium;

  // ─── Location State ──────────────────────────────────────────────────────────
  Position? _userPosition;
  Position? get userPosition => _userPosition;
  LatLng? get userLatLng => _userPosition != null
      ? LatLng(_userPosition!.latitude, _userPosition!.longitude)
      : null;

  bool _isFollowMode = false;
  bool get isFollowMode => _isFollowMode;

  double? _compassHeading;
  double? get compassHeading => _compassHeading;

  // Raw sensor state for compass computation
  double _ax = 0, _ay = 0, _az = 9.81;
  bool _hasAccel = false;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetSubscription;

  /// Start the compass sensor stream. Call this once at app startup.
  /// Uses raw accelerometer + magnetometer data (same algorithm as Android OS).
  void startCompass() {
    _accelSubscription?.cancel();
    _magnetSubscription?.cancel();

    try {
      // Listen to accelerometer (includes gravity)
      _accelSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen((event) {
        // Low-pass filter for stability
        _ax = _ax * 0.85 + event.x * 0.15;
        _ay = _ay * 0.85 + event.y * 0.15;
        _az = _az * 0.85 + event.z * 0.15;
        _hasAccel = true;
      }, onError: (e) {
        debugPrint('Accelerometer error: $e');
      });

      // Listen to magnetometer — compute heading on each update
      _magnetSubscription = magnetometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen((event) {
        if (!_hasAccel) return;
        final heading = _computeHeading(_ax, _ay, _az, event.x, event.y, event.z);
        if (heading != null) {
          // Only update if changed by more than 1° to reduce jitter
          if (_compassHeading == null || (heading - _compassHeading!).abs() > 3.0) {
            _compassHeading = heading;
            notifyListeners();
          }
        }
      }, onError: (e) {
        debugPrint('Magnetometer error: $e');
      });

      debugPrint('Compass started via sensors_plus (accelerometer + magnetometer)');
    } catch (e) {
      debugPrint('Failed to start compass sensors: $e');
    }
  }

  /// Compute compass heading from accelerometer + magnetometer.
  double? _computeHeading(
    double ax, double ay, double az,
    double mx, double my, double mz,
  ) {
    // Normalize accelerometer (A)
    double normA = sqrt(ax * ax + ay * ay + az * az);
    if (normA < 1.0) return null;
    ax /= normA; ay /= normA; az /= normA;

    // Normalize magnetometer (M)
    double normM = sqrt(mx * mx + my * my + mz * mz);
    if (normM < 1.0) return null;
    mx /= normM; my /= normM; mz /= normM;

    // East vector E = M x A
    double ex = my * az - mz * ay;
    double ey = mz * ax - mx * az;
    double ez = mx * ay - my * ax;

    double normE = sqrt(ex * ex + ey * ey + ez * ez);
    if (normE < 0.1) return null; // M and A are parallel (freefall or error)
    ex /= normE; ey /= normE; ez /= normE;

    // North vector N = A x E
    double ny = az * ex - ax * ez;
    double nz = ax * ey - ay * ex;

    // Determine heading based on how the phone is held.
    // If flat (|az| > |ay|), the Y-axis points forward.
    // If upright (|ay| > |az|), the -Z-axis (back camera) points forward.
    double azimuthRad;
    if (az.abs() > ay.abs()) {
      azimuthRad = atan2(ey, ny);
    } else {
      azimuthRad = atan2(-ez, -nz);
    }

    double azimuthDeg = azimuthRad * (180.0 / pi);
    if (azimuthDeg < 0) azimuthDeg += 360;
    return azimuthDeg;
  }

  void toggleFollowMode() {
    _isFollowMode = !_isFollowMode;
    notifyListeners();
  }

  void disableFollowMode() {
    if (_isFollowMode) {
      _isFollowMode = false;
      notifyListeners();
    }
  }

  // ─── Nearest Faskes ─────────────────────────────────────────────────────────
  List<Faskes> _nearestFaskes = [];
  List<Faskes> get nearestFaskes => _nearestFaskes;

  // ─── Route State ─────────────────────────────────────────────────────────────
  String _transportMode = 'motor'; // 'jalan_kaki', 'motor', 'mobil'
  String get transportMode => _transportMode;

  String _mapTheme = 'normal'; // 'normal', 'dark', 'satellite'
  String get mapTheme => _mapTheme;
  void setMapTheme(String theme) {
    _mapTheme = theme;
    notifyListeners();
  }

  List<RouteData> _allRouteOptions = [];
  int _selectedRouteIndex = 0;
  List<RouteData> get allRouteOptions => _allRouteOptions;
  int get selectedRouteIndex => _selectedRouteIndex;

  List<LatLng> get routePoints => _allRouteOptions.isNotEmpty ? _allRouteOptions[_selectedRouteIndex].points : [];
  double get routeDistanceKm => _allRouteOptions.isNotEmpty ? _allRouteOptions[_selectedRouteIndex].distanceKm : 0.0;
  double get routeDurationMinutes => _allRouteOptions.isNotEmpty ? _allRouteOptions[_selectedRouteIndex].durationMinutes : 0.0;
  
  LatLng? _routeDestination;
  LatLng? get routeDestination => _routeDestination;
  bool _isLoadingRoute = false;
  bool get isLoadingRoute => _isLoadingRoute;

  // ─── Loading ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── Main Tab State ────────────────────────────────────────────────────────
  int _mainTabIndex = 0;
  int get mainTabIndex => _mainTabIndex;

  void setMainTabIndex(int index) {
    _mainTabIndex = index;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  INIT
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Ensure default user exists for testing
      final defaultUser = await _dbHelper.getUserByEmail('kakapatria66@gmail.com');
      if (defaultUser == null) {
        await _dbHelper.insertUser(User(
          nama: 'Kaka Patria',
          email: 'kakapatria66@gmail.com',
          password: 'kakapatria',
          telepon: '08123456789',
        ));
      }

      await _dbHelper.importFaskesFromJson();
      await loadAllFaskes();
      await loadStats();
      await loadCurrentUser();
      await loadSearchHistory();
      await loadFavorites();
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  USER
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
  }

  Future<void> setCurrentUser(User user) async {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> logoutUser() async {
    await _authService.logout();
    _currentUser = null;
    _mainTabIndex = 0;
    _positionStreamSubscription?.cancel();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  FASKES
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> loadAllFaskes() async {
    _allFaskes = await _dbHelper.getAllFaskes();
    _applyFilter();
    notifyListeners();
  }

  void setFilter(String filter) {
    _selectedFilter = filter;
    _applyFilter();
    notifyListeners();
  }

  void setSearch(String query) {
    _searchQuery = query;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    List<Faskes> result = List.from(_allFaskes);

    if (_selectedFilter == 'Favorit') {
      result = result.where((f) => f.id != null && _favoriteFaskesIds.contains(f.id.toString())).toList();
    } else if (_selectedFilter != 'Semua') {
      result = result.where((f) => f.jenis == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      String q = _searchQuery.toLowerCase();
      // Translate abbreviations
      q = q.replaceAll(RegExp(r'\bpkm\b'), 'puskesmas');
      q = q.replaceAll(RegExp(r'\brs\b'), 'rumah sakit');
      q = q.replaceAll(RegExp(r'\blab\b'), 'laboratorium');

      result = result.where((f) {
        return f.nama.toLowerCase().contains(q) ||
            f.jenis.toLowerCase().contains(q) ||
            f.alamat.toLowerCase().contains(q) ||
            f.alamatLengkap.toLowerCase().contains(q);
      }).toList();
    }

    _filteredFaskes = result;
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  STATS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> loadStats() async {
    _totalFaskes = await _dbHelper.getFaskesCount();
    _totalRumahSakit = await _dbHelper.getFaskesCountByJenis('Rumah Sakit');
    _totalPuskesmas = await _dbHelper.getFaskesCountByJenis('Puskesmas');
    _totalKlinik = await _dbHelper.getFaskesCountByJenis('Klinik');
    _totalApotek = await _dbHelper.getFaskesCountByJenis('Apotek');
    _totalLaboratorium = await _dbHelper.getFaskesCountByJenis('Laboratorium');
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  LOCATION
  // ─────────────────────────────────────────────────────────────────────────────

  StreamSubscription<Position>? _positionStreamSubscription;

  bool _isSimulatedLocation = false;
  bool get isSimulatedLocation => _isSimulatedLocation;

  Future<bool> fetchUserLocation() async {
    _isSimulatedLocation = false;
    final position = await _locationService.getCurrentPosition();
    if (position == null) return false;
    
    _userPosition = position;
    computeNearestFaskes(filterJenis: _selectedFilter);
    notifyListeners();

    // Start real-time stream
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // update every 15 meters to save CPU & battery
      ),
    ).listen((newPosition) {
      if (!_isSimulatedLocation) {
        _userPosition = newPosition;
        computeNearestFaskes(filterJenis: _selectedFilter);
        notifyListeners();
      }
    });

    return true;
  }

  void setUserLocationManually(LatLng latLng) {
    _isSimulatedLocation = true;
    _positionStreamSubscription?.cancel(); // Stop real stream if manual
    _accelSubscription?.cancel();
    _magnetSubscription?.cancel();
    _userPosition = Position(
      longitude: latLng.longitude,
      latitude: latLng.latitude,
      timestamp: DateTime.now(),
      accuracy: 100.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
    computeNearestFaskes(filterJenis: _selectedFilter);
    if (_routeDestination != null) {
      // Automatically recalculate the active route using the new simulated location
      fetchRoute(origin: latLng, destination: _routeDestination!);
    }
    notifyListeners();
  }

  Future<void> resetToRealLocation() async {
    _isSimulatedLocation = false;
    startCompass();
    await fetchUserLocation();
    if (_userPosition != null && _routeDestination != null) {
      fetchRoute(origin: userLatLng!, destination: _routeDestination!);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  NEAREST FASKES
  // ─────────────────────────────────────────────────────────────────────────────

  void computeNearestFaskes({String? filterJenis}) {
    if (_userPosition == null) return;

    List<Faskes> source = List.from(_allFaskes);
    if (filterJenis != null && filterJenis != 'Semua') {
      source = source.where((f) => f.jenis == filterJenis).toList();
    }

    for (final f in source) {
      f.distance = Haversine.distanceKm(
        lat1: _userPosition!.latitude,
        lon1: _userPosition!.longitude,
        lat2: f.latitude,
        lon2: f.longitude,
      );
      f.isRouteDistance = false;
    }

    source.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    
    // Filter by logic: only consider it "nearest" if it is within 15 km radius
    final radiusLimited = source.where((f) => (f.distance ?? double.infinity) <= 15.0).toList();

    if (radiusLimited.isEmpty && source.isNotEmpty) {
      // If literally nothing is within 15 km, just show the absolute closest 1
      _nearestFaskes = [source.first];
    } else {
      // Limit to top 15 to prevent lag in nearest screen and bottom sheet
      _nearestFaskes = radiusLimited.take(15).toList();
    }
    notifyListeners();

    // Fire and forget: fetch real route distances for these top candidates
    _fetchRealDistancesForNearest();
  }

  Future<void> _fetchRealDistancesForNearest() async {
    if (_nearestFaskes.isEmpty || !_hasInternet || _userPosition == null) return;

    final origin = '${_userPosition!.longitude},${_userPosition!.latitude}';
    final destinations = _nearestFaskes.map((f) => '${f.longitude},${f.latitude}').join(';');
    
    // We use routed-bike as general optimal routing profile for short distances (especially in Indonesia)
    final url = 'https://routing.openstreetmap.de/routed-bike/table/v1/driving/$origin;$destinations?sources=0&annotations=distance';

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 'Ok' && data['distances'] != null && data['distances'].isNotEmpty) {
          final distances = data['distances'][0] as List;
          // distances[0] is distance from origin to origin (0)
          // distances[i+1] is distance from origin to destination i
          for (int i = 0; i < _nearestFaskes.length; i++) {
            if (i + 1 < distances.length && distances[i + 1] != null) {
              final double distMeters = (distances[i + 1] as num).toDouble();
              _nearestFaskes[i].distance = distMeters / 1000.0;
              _nearestFaskes[i].isRouteDistance = true;
            }
          }
          // Re-sort based on real route distance
          _nearestFaskes.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch table distances: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  ROUTING (OSRM)
  // ─────────────────────────────────────────────────────────────────────────────

  void setTransportMode(String mode) {
    if (_transportMode != mode) {
      _transportMode = mode;
      notifyListeners();
      if (_userPosition != null && _routeDestination != null) {
        fetchRoute(origin: userLatLng!, destination: _routeDestination!);
      }
    }
  }

  void selectRouteOption(int index) {
    if (index >= 0 && index < _allRouteOptions.length) {
      _selectedRouteIndex = index;
      notifyListeners();
    }
  }

  Future<bool> fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _isLoadingRoute = true;
    _allRouteOptions = [];
    _selectedRouteIndex = 0;
    _routeDestination = null;
    notifyListeners();

    if (!_hasInternet) {
      _isLoadingRoute = false;
      notifyListeners();
      return false;
    }

    try {
      String profile = 'routed-bike'; // Default to bike profile for both Motor and Jalan Kaki (more accurate in local areas)
      String osrmMode = 'driving'; 
      
      if (_transportMode == 'mobil') {
        profile = 'routed-car';
      }
      
      final url = 'https://routing.openstreetmap.de/$profile/route/v1/$osrmMode/'
            '${origin.longitude},${origin.latitude};'
            '${destination.longitude},${destination.latitude}'
            '?overview=full&geometries=geojson&alternatives=true&steps=true';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final List<RouteData> options = [];
          for (var route in routes) {
            final geometry = route['geometry'] as Map<String, dynamic>;
            final coordinates = geometry['coordinates'] as List<dynamic>;
            final List<LatLng> points = coordinates.map<LatLng>((coord) {
              final c = coord as List<dynamic>;
              return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
            }).toList();
            
            final distance = (route['distance'] as num).toDouble();
            final distanceKm = distance / 1000.0;
            double realisticDurationMinutes = 0;
            if (_transportMode == 'motor') {
              realisticDurationMinutes = distanceKm * 1.7; 
            } else if (_transportMode == 'mobil') {
              realisticDurationMinutes = distanceKm * 3.0; 
            } else if (_transportMode == 'jalan_kaki') {
              realisticDurationMinutes = distanceKm * 12.0; 
            }
            
            final List<RouteInstruction> instructions = [];
            final legs = route['legs'] as List<dynamic>?;
            if (legs != null && legs.isNotEmpty) {
              final steps = legs.first['steps'] as List<dynamic>?;
              if (steps != null) {
                for (var step in steps) {
                  final maneuver = step['maneuver'] as Map<String, dynamic>?;
                  final stepDist = (step['distance'] as num).toDouble();
                  final instruction = step['name']?.toString() ?? '';
                  final type = maneuver?['type']?.toString() ?? '';
                  final modifier = maneuver?['modifier']?.toString() ?? '';
                  
                  String text = '';
                  if (type == 'depart') {
                    text = 'Mulai perjalanan';
                  } else if (type == 'arrive') {
                    text = 'Tujuan Anda ada di dekat sini';
                  } else if (instruction.isEmpty) {
                    text = 'Terus melaju mengikuti jalan utama';
                  } else if (modifier.contains('left')) {
                    text = 'Belok Kiri ke $instruction';
                  } else if (modifier.contains('right')) {
                    text = 'Belok Kanan ke $instruction';
                  } else if (type == 'roundabout') {
                    text = 'Masuk bundaran menuju $instruction';
                  } else {
                    text = 'Lurus ke $instruction';
                  }

                  instructions.add(RouteInstruction(text: text, distance: stepDist, modifier: modifier));
                }
              }
            }
            
            options.add(RouteData(
              points: points,
              distanceKm: distanceKm,
              durationMinutes: realisticDurationMinutes,
              instructions: instructions,
            ));
          }

          _allRouteOptions = options;
          _selectedRouteIndex = 0;
          _routeDestination = destination;

          _isLoadingRoute = false;
          notifyListeners();
          return true;
        }
      }
    } catch (_) {
      // Request failed, no fallback straight line
    }

    _isLoadingRoute = false;
    notifyListeners();
    return false;
  }

  void clearRoute() {
    _allRouteOptions = [];
    _selectedRouteIndex = 0;
    _routeDestination = null;
    notifyListeners();
  }
}
