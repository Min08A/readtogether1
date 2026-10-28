import 'package:sqflite/sqflite.dart';

import '../../models/app_user.dart';
import '../../services/data_bus.dart';
import '../../utils/password_hasher.dart';
import '../database_helper.dart';

/// Email уже занят другим пользователем.
class EmailTakenException implements Exception {
  @override
  String toString() => 'Пользователь с таким email уже зарегистрирован';
}

/// Работа с таблицей users: регистрация, вход, профиль, пароль.
class AuthRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<AppUser?> getUser(int id) async {
    final rows = await (await _db)
        .query('users', where: 'user_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  Future<AppUser?> findByEmail(String email) async {
    final rows = await (await _db).query('users',
        where: 'LOWER(email) = ?',
        whereArgs: [email.trim().toLowerCase()],
        limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  /// Возвращает пользователя при верных email и пароле, иначе null.
  Future<AppUser?> login(String email, String password) async {
    final user = await findByEmail(email);
    if (user == null) return null;
    return PasswordHasher.verify(password, user.passwordHash) ? user : null;
  }

  /// Создаёт пользователя и записи настроек по умолчанию
  /// (privacy_settings, user_preferences, reader_settings) в одной транзакции.
  Future<int> register({
    required String name,
    required String email,
    required String password,
    required List<String> favoriteGenres,
  }) async {
    if (await findByEmail(email) != null) throw EmailTakenException();
    final db = await _db;
    final id = await db.transaction((txn) async {
      final userId = await txn.insert('users', {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'password_hash': PasswordHasher.hash(password),
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.insert('privacy_settings', {'user_id': userId});
      await txn.insert('user_preferences', {
        'user_id': userId,
        'favorite_genres': favoriteGenres.join(','),
      });
      await txn.insert('reader_settings', {'user_id': userId});
      return userId;
    });
    DataBus.instance.changed();
    return id;
  }

  Future<void> updateProfile({
    required int userId,
    required String name,
    required String email,
    String? bio,
  }) async {
    final other = await findByEmail(email);
    if (other != null && other.id != userId) throw EmailTakenException();
    await (await _db).update(
      'users',
      {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'bio': (bio == null || bio.trim().isEmpty) ? null : bio.trim(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    DataBus.instance.changed();
  }

  /// Сброс пароля (экран Forgot Password).
  Future<void> resetPassword(String email, String newPassword) async {
    await (await _db).update(
      'users',
      {'password_hash': PasswordHasher.hash(newPassword)},
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
    );
  }

  /// Смена пароля из настроек. false — если старый пароль неверный.
  Future<bool> changePassword(
      int userId, String oldPassword, String newPassword) async {
    final user = await getUser(userId);
    if (user == null || !PasswordHasher.verify(oldPassword, user.passwordHash)) {
      return false;
    }
    await (await _db).update(
      'users',
      {'password_hash': PasswordHasher.hash(newPassword)},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return true;
  }
}
