import 'package:flutter/material.dart';

/// Вспомогательные методы навигации между экранами.
class AppNavigator {
  AppNavigator._();

  static Future<T?> push<T>(BuildContext context, Widget screen) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));

  static Future<T?> replace<T>(BuildContext context, Widget screen) =>
      Navigator.of(context)
          .pushReplacement<T, Object?>(MaterialPageRoute(builder: (_) => screen));

  /// Открыть экран и очистить историю (после входа / выхода).
  static Future<T?> resetTo<T>(BuildContext context, Widget screen) =>
      Navigator.of(context).pushAndRemoveUntil<T>(
          MaterialPageRoute(builder: (_) => screen), (_) => false);
}
