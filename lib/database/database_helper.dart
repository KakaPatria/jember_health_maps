import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/faskes.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('jember_health_maps.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE users ADD COLUMN profile_picture TEXT');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        telepon TEXT NOT NULL,
        profile_picture TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE faskes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama TEXT NOT NULL,
        jenis TEXT NOT NULL,
        alamat TEXT NOT NULL,
        alamat_lengkap TEXT NOT NULL,
        telepon TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL
      )
    ''');
  }

  // ==================== USER OPERATIONS ====================

  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> loginUser(String email, String password) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  // ==================== FASKES OPERATIONS ====================

  Future<bool> isFaskesTableEmpty() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM faskes');
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count == 0;
  }

  Future<void> importFaskesFromJson() async {
    final db = await database;
    final isEmpty = await isFaskesTableEmpty();
    final rsCount = await getFaskesCountByJenis('Rumah Sakit');
    final klinikCount = await getFaskesCountByJenis('Klinik');
    
    // Jika tidak kosong, dan data RS serta Klinik sudah ada, maka tidak perlu import ulang
    if (!isEmpty && rsCount > 0 && klinikCount > 0) return;

    if (!isEmpty) {
      await db.delete('faskes');
    }

    final String jsonString =
        await rootBundle.loadString('assets/data/faskes.json');
    final List<dynamic> jsonData = json.decode(jsonString);

    final batch = db.batch();

    for (final item in jsonData) {
      final faskes = Faskes.fromJson(item as Map<String, dynamic>);
      batch.insert('faskes', faskes.toMap());
    }

    await batch.commit(noResult: true);
  }

  Future<List<Faskes>> getAllFaskes() async {
    final db = await database;
    final maps = await db.query('faskes');
    return maps.map((map) => Faskes.fromMap(map)).toList();
  }

  Future<List<Faskes>> getFaskesByJenis(String jenis) async {
    final db = await database;
    final maps = await db.query(
      'faskes',
      where: 'jenis = ?',
      whereArgs: [jenis],
    );
    return maps.map((map) => Faskes.fromMap(map)).toList();
  }

  Future<List<Faskes>> searchFaskes(String query) async {
    final db = await database;
    final maps = await db.query(
      'faskes',
      where:
          'nama LIKE ? OR jenis LIKE ? OR alamat LIKE ? OR alamat_lengkap LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
    );
    return maps.map((map) => Faskes.fromMap(map)).toList();
  }

  Future<Faskes?> getFaskesById(int id) async {
    final db = await database;
    final maps = await db.query(
      'faskes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Faskes.fromMap(maps.first);
    }
    return null;
  }

  Future<int> getFaskesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM faskes');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getFaskesCountByJenis(String jenis) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM faskes WHERE jenis = ?',
      [jenis],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
