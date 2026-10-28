/// Правила проверки полей ввода. Каждый метод возвращает текст ошибки
/// (показывается под полем) или null, если значение корректно.
class Validators {
  Validators._();

  static final RegExp _email =
      RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
  static final RegExp _name =
      RegExp(r"^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі' \-]+$");
  static final RegExp _hasLetter = RegExp(r'[A-Za-zА-Яа-яЁё]');
  static final RegExp _hasDigit = RegExp(r'\d');

  static String? requiredField(String? value, {String field = 'Поле'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field обязательно для заполнения';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите электронную почту';
    if (v.length > 100) return 'Email не может быть длиннее 100 символов';
    if (!_email.hasMatch(v)) {
      return 'Неверный формат email. Пример: name@example.com';
    }
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите имя';
    if (v.length < 2) return 'Имя должно содержать минимум 2 символа';
    if (v.length > 30) return 'Имя не может быть длиннее 30 символов';
    if (!_name.hasMatch(v)) {
      return 'Имя может содержать только буквы, пробел и дефис';
    }
    return null;
  }

  /// Пароль при регистрации / смене пароля.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Придумайте пароль';
    if (v.length < 8) return 'Пароль должен содержать минимум 8 символов';
    if (v.length > 64) return 'Пароль не может быть длиннее 64 символов';
    if (v.contains(' ')) return 'Пароль не должен содержать пробелы';
    if (!_hasLetter.hasMatch(v) || !_hasDigit.hasMatch(v)) {
      return 'Пароль должен содержать буквы и цифры';
    }
    return null;
  }

  /// Пароль на экране входа — только проверка на пустоту и длину.
  static String? loginPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Введите пароль';
    if (v.length < 6) return 'Пароль слишком короткий (минимум 6 символов)';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'Повторите пароль';
    if (value != original) return 'Пароли не совпадают';
    return null;
  }

  static String? bio(String? value) {
    if ((value ?? '').trim().length > 200) {
      return 'Био не может быть длиннее 200 символов';
    }
    return null;
  }

  static String? roomName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите название комнаты';
    if (v.length < 3) return 'Название должно содержать минимум 3 символа';
    if (v.length > 50) return 'Название не может быть длиннее 50 символов';
    return null;
  }

  static String? bookTitle(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите название книги';
    if (v.length > 100) return 'Название не может быть длиннее 100 символов';
    return null;
  }

  static String? bookAuthor(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Введите автора';
    if (v.length > 60) return 'Имя автора не может быть длиннее 60 символов';
    return null;
  }

  static String? noteText(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Текст заметки не может быть пустым';
    if (v.length > 500) return 'Заметка не может быть длиннее 500 символов';
    return null;
  }

  static String? message(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Нельзя отправить пустое сообщение';
    if (v.length > 500) return 'Сообщение не может быть длиннее 500 символов';
    return null;
  }

  /// Целое число в диапазоне [min, max] — номер страницы, главы.
  static String? intInRange(String? value, int min, int max,
      {String field = 'Значение'}) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '$field обязательно';
    final n = int.tryParse(v);
    if (n == null) return '$field должно быть целым числом';
    if (n < min || n > max) return '$field должно быть от $min до $max';
    return null;
  }
}
