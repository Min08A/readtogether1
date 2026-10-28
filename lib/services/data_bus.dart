import 'package:flutter/widgets.dart';

/// Простая шина событий: репозитории сообщают об изменении данных в БД,
/// а открытые экраны перечитывают данные (например, после добавления книги
/// вкладка «Библиотека» обновляется без перезапуска).
class DataBus extends ChangeNotifier {
  DataBus._();
  static final DataBus instance = DataBus._();

  void changed() => notifyListeners();
}

/// Миксин для экранов, которые загружают данные из SQLite и должны
/// обновляться при любых изменениях.
mixin ReloadOnDataChange<T extends StatefulWidget> on State<T> {
  Future<void> load();

  @override
  void initState() {
    super.initState();
    DataBus.instance.addListener(_onChanged);
    load();
  }

  void _onChanged() {
    if (mounted) load();
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_onChanged);
    super.dispose();
  }
}
