import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Хеширование паролей: в БД хранится «соль$sha256(соль+пароль)»,
/// сам пароль никогда не сохраняется (поле users.password_hash).
class PasswordHasher {
  PasswordHasher._();

  static String hash(String password, {String? salt}) {
    final s = salt ?? _randomSalt();
    final digest = sha256.convert(utf8.encode('$s:$password'));
    return '$s\$${digest.toString()}';
  }

  static bool verify(String password, String stored) {
    final parts = stored.split(r'$');
    if (parts.length != 2) return false;
    return hash(password, salt: parts[0]) == stored;
  }

  static String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
