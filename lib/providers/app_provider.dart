import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Haversine;
import '../database/database_helper.dart';
import '../models/faskes.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../utils/haversine.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();

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

  // ─── Nearest Faskes ─────────────────────────────────────────────────────────
  List<Faskes> _nearestFaskes = [];
  List<Faskes> get nearestFaskes => _nearestFaskes;

  // ─── Route State ─────────────────────────────────────────────────────────────
  List<LatLng> _routePoints = [];
  List<LatLng> get routePoints => _routePoints;
  LatLng? _routeDestination;
  LatLng? get routeDestination => _routeDestination;
  double _routeDistanceKm = 0.0;
  double get routeDistanceKm => _routeDistanceKm;
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

    if (_selectedFilter != 'Semua') {
      result = result.where((f) => f.jenis == _selectedFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
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

  Future<bool> fetchUserLocation() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) return false;
    _userPosition = position;
    notifyListeners();
    return true;
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
    }

    source.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    _nearestFaskes = source;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  //  ROUTING (OSRM)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<bool> fetchRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    _isLoadingRoute = true;
    _routePoints = [];
    _routeDistanceKm = 0.0;
    notifyListeners();

    try {
      final url =
          'https://router.project-osrm.org/route/v1/foot/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>;
        if (routes.isNotEmpty) {
          final route = routes.first as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>;
          final coordinates = geometry['coordinates'] as List<dynamic>;
          final distance = (route['distance'] as num).toDouble();

          final List<LatLng> points = coordinates.map<LatLng>((coord) {
            final c = coord as List<dynamic>;
            return LatLng(
                (c[1] as num).toDouble(), (c[0] as num).toDouble());
          }).toList();

          _routePoints = points;
          _routeDestination = destination;

          _routeDistanceKm = distance / 1000.0;
          _isLoadingRoute = false;
          notifyListeners();
          return true;
        }
      }
    } catch (_) {
      // fallback: garis lurus
      _routePoints = [origin, destination];
      _routeDistanceKm = Haversine.distanceKm(
        lat1: origin.latitude,
        lon1: origin.longitude,
        lat2: destination.latitude,
        lon2: destination.longitude,
      );
    }

    _isLoadingRoute = false;
    notifyListeners();
    return false;
  }

  void clearRoute() {
    _routePoints = [];
    _routeDestination = null;
    _routeDistanceKm = 0.0;
    notifyListeners();
  }
}
