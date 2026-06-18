import '../database/database_helper.dart';
import '../models/user.dart';

class AuthService {
  // Use memory variable instead of SharedPreferences so session expires when app closes
  static int? _currentUserId;

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

      // Save session in memory only (will expire when app closes)
      _currentUserId = user.id;

      return {'success': true, 'message': 'Login berhasil', 'user': user};
    } catch (e) {
      return {'success': false, 'message': 'Gagal login: $e'};
    }
  }

  Future<void> logout() async {
    _currentUserId = null;
  }

  Future<bool> isLoggedIn() async {
    return _currentUserId != null;
  }

  Future<User?> getCurrentUser() async {
    if (_currentUserId == null) return null;
    return await _dbHelper.getUserById(_currentUserId!);
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
