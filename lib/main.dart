import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'app.dart';
import 'data/database_helper.dart';
import 'services/session.dart';
import 'data/repos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // На Windows / Linux / macOS SQLite работает через FFI.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    ffi.sqfliteFfiInit();
    ffi.databaseFactory = ffi.databaseFactoryFfi;
  }

  await Session.instance.init();
  // Открываем БД заранее: при первом запуске создаются таблицы и демо-данные.
  await DatabaseHelper.instance.database;

  // Если сохранённый пользователь больше не существует — выходим из сессии.
  final savedId = Session.instance.userIdOrNull;
  if (savedId != null && await Repos.auth.getUser(savedId) == null) {
    await Session.instance.logout();
  }

  runApp(const ReadTogetherApp());
}
