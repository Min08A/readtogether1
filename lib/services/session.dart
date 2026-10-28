import 'package:shared_preferences/shared_preferences.dart';

/// Текущая сессия: id вошедшего пользователя и признак пройденного
/// Onboarding. Хранится в SharedPreferences, чтобы не входить заново
/// при каждом запуске.
class Session {
  Session._();
  static final Session instance = Session._();

  static const _keyUser = 'current_user_id';
  static const _keyOnboarding = 'onboarding_done';
  static const _keyDemo = 'demo_activity';

  SharedPreferences? _prefs;
  int? _userId;

  /// Жанры, выбранные на Onboarding до регистрации.
  List<String> pendingGenres = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _userId = _prefs!.getInt(_keyUser);
  }

  int? get userIdOrNull => _userId;

  /// id текущего пользователя (вызывается только после входа).
  int get userId {
    final id = _userId;
    if (id == null) throw StateError('Пользователь не авторизован');
    return id;
  }

  bool get isLoggedIn => _userId != null;

  bool get onboardingDone => _prefs?.getBool(_keyOnboarding) ?? false;

  Future<void> setOnboardingDone() async {
    await _prefs?.setBool(_keyOnboarding, true);
  }

  /// Демо-активность друзей (ответы в чатах, рост прогресса).
  /// Сервера нет, поэтому «живость» друзей имитируется локально.
  bool get demoActivity => _prefs?.getBool(_keyDemo) ?? true;

  Future<void> setDemoActivity(bool value) async {
    await _prefs?.setBool(_keyDemo, value);
  }

  Future<void> login(int userId) async {
    _userId = userId;
    await _prefs?.setInt(_keyUser, userId);
  }

  Future<void> logout() async {
    _userId = null;
    await _prefs?.remove(_keyUser);
  }
}
