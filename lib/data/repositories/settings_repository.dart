import 'package:sqflite/sqflite.dart';

import '../../models/settings.dart';
import '../../services/data_bus.dart';
import '../database_helper.dart';

/// Работа с таблицами privacy_settings, user_preferences, reader_settings.
class SettingsRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<PrivacySettings> privacy(int userId) async {
    final db = await _db;
    var rows = await db.query('privacy_settings',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) {
      await db.insert('privacy_settings', {'user_id': userId});
      rows = await db.query('privacy_settings',
          where: 'user_id = ?', whereArgs: [userId], limit: 1);
    }
    return PrivacySettings.fromMap(rows.first);
  }

  /// field — одно из: profile_visibility, library_visibility,
  /// activity_visibility, room_invites_from.
  Future<void> updatePrivacy(int userId, String field, Visibility3 value) async {
    await (await _db).update('privacy_settings', {field: value.dbValue},
        where: 'user_id = ?', whereArgs: [userId]);
    DataBus.instance.changed();
  }

  Future<UserPreferences> preferences(int userId) async {
    final db = await _db;
    var rows = await db.query('user_preferences',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) {
      await db.insert('user_preferences', {'user_id': userId});
      rows = await db.query('user_preferences',
          where: 'user_id = ?', whereArgs: [userId], limit: 1);
    }
    return UserPreferences.fromMap(rows.first);
  }

  Future<void> updatePreferences(int userId, Map<String, Object?> values) async {
    await (await _db).update('user_preferences', values,
        where: 'user_id = ?', whereArgs: [userId]);
    DataBus.instance.changed();
  }

  Future<ReaderSettings> readerSettings(int userId) async {
    final db = await _db;
    var rows = await db.query('reader_settings',
        where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (rows.isEmpty) {
      await db.insert('reader_settings', {'user_id': userId});
      rows = await db.query('reader_settings',
          where: 'user_id = ?', whereArgs: [userId], limit: 1);
    }
    return ReaderSettings.fromMap(rows.first);
  }

  /// Сохраняется без DataBus — настройки читалки применяются локально.
  Future<void> saveReaderSettings(ReaderSettings s) async {
    await (await _db).update(
      'reader_settings',
      {
        'font_family': s.fontFamily,
        'font_size': s.fontSize,
        'line_spacing': s.lineSpacing,
        'reader_theme': s.readerTheme.dbValue,
      },
      where: 'user_id = ?',
      whereArgs: [s.userId],
    );
  }
}
