@echo off
chcp 65001 >nul
REM Генерирует платформенные папки (android, ios, windows) и скачивает пакеты.
REM Существующие файлы (lib, pubspec.yaml, assets) НЕ перезаписываются.
flutter create . --project-name readtogether --org kz.readtogether --platforms android,ios,windows
flutter pub get
echo.
echo Готово. Подключите телефон/эмулятор и выполните: flutter run
pause
