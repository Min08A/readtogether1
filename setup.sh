#!/usr/bin/env bash
# Генерирует платформенные папки (android, ios, macos, linux) и скачивает пакеты.
# Существующие файлы (lib, pubspec.yaml, assets) НЕ перезаписываются.
set -e
cd "$(dirname "$0")"
flutter create . --project-name readtogether --org kz.readtogether --platforms android,ios,macos,linux
flutter pub get

# macOS: разрешаем приложению открывать выбранные пользователем файлы
# (нужно для кнопки «Выбрать файл» на экране «Добавить книгу»).
if [ "$(uname)" = "Darwin" ]; then
  for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
    if [ -f "$f" ]; then
      /usr/libexec/PlistBuddy -c "Add :com.apple.security.files.user-selected.read-only bool true" "$f" 2>/dev/null || true
    fi
  done
fi
echo
echo "Готово. Подключите телефон/эмулятор и выполните: flutter run"
