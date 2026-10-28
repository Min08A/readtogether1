// Модульные тесты вспомогательной логики (валидация, пароли, разбиение
// текста на страницы, склонения). Запуск: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:readtogether/utils/book_text.dart';
import 'package:readtogether/utils/date_format.dart';
import 'package:readtogether/utils/password_hasher.dart';
import 'package:readtogether/utils/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('amina@'), isNotNull);
      expect(Validators.email('amina@readtogether.club'), isNull);
    });

    test('name', () {
      expect(Validators.name('A'), isNotNull);
      expect(Validators.name('Amina1'), isNotNull);
      expect(Validators.name('Амина'), isNull);
      expect(Validators.name('Қанат'), isNull);
    });

    test('password', () {
      expect(Validators.newPassword('short1'), isNotNull);
      expect(Validators.newPassword('onlyletters'), isNotNull);
      expect(Validators.newPassword('amina2026'), isNull);
      expect(Validators.confirmPassword('a', 'b'), isNotNull);
    });

    test('number range', () {
      expect(Validators.intInRange('0', 1, 328), isNotNull);
      expect(Validators.intInRange('329', 1, 328), isNotNull);
      expect(Validators.intInRange('abc', 1, 328), isNotNull);
      expect(Validators.intInRange('87', 1, 328), isNull);
    });
  });

  test('PasswordHasher', () {
    final hash = PasswordHasher.hash('amina2026');
    expect(PasswordHasher.verify('amina2026', hash), isTrue);
    expect(PasswordHasher.verify('wrong', hash), isFalse);
  });

  test('BookContent.splitIntoPages', () {
    final text = List.generate(20, (i) => 'Абзац $i. ${'слово ' * 30}').join('\n\n');
    final pages = BookContent.splitIntoPages(text);
    expect(pages.length, greaterThan(1));
    expect(BookContent.chapterOf(87), 7);
  });

  test('DateFormatRu.plural', () {
    expect(DateFormatRu.plural(1, 'друг', 'друга', 'друзей'), 'друг');
    expect(DateFormatRu.plural(3, 'друг', 'друга', 'друзей'), 'друга');
    expect(DateFormatRu.plural(11, 'друг', 'друга', 'друзей'), 'друзей');
  });
}
