import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/user.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Map<String, dynamic>> register({
    required String nama,
    required String email,
    required String password,
    required String telepon,
  }) async {
    try {
      // Check if email already exists
      final existingUser = await _dbHelper.getUserByEmail(email);
      if (existingUser != null) {
        return {'success': false, 'message': 'Email sudah terdaftar'};
      }

      final user = User(
        nama: nama,
        email: email,
        password: password,
        telepon: telepon,
      );

      await _dbHelper.insertUser(user);
      return {'success': true, 'message': 'Registrasi berhasil'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal registrasi: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _dbHelper.loginUser(email, password);
      if (user == null) {
        return {'success': false, 'message': 'Email atau password salah'};
      }

      // Save session
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setInt(_keyUserId, user.id!);

      return {'success': true, 'message': 'Login berhasil', 'user': user};
    } catch (e) {
      return {'success': false, 'message': 'Gagal login: $e'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    if (userId == null) return null;
    return await _dbHelper.getUserById(userId);
  }

  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String nama,
    required String email,
    required String telepon,
    String? profilePicture,
  }) async {
    try {
      final existingUser = await _dbHelper.getUserById(userId);
      if (existingUser == null) {
        return {'success': false, 'message': 'Pengguna tidak ditemukan'};
      }

      // Check if new email is already used by another user
      if (email != existingUser.email) {
        final emailUser = await _dbHelper.getUserByEmail(email);
        if (emailUser != null && emailUser.id != userId) {
          return {
            'success': false,
            'message': 'Email sudah digunakan pengguna lain'
          };
        }
      }

      final updatedUser = existingUser.copyWith(
        nama: nama,
        email: email,
        telepon: telepon,
        profilePicture: profilePicture,
      );

      await _dbHelper.updateUser(updatedUser);
      return {'success': true, 'message': 'Profil berhasil diperbarui'};
    } catch (e) {
      return {'success': false, 'message': 'Gagal memperbarui profil: $e'};
    }
  }
}
