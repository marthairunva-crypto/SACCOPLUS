@echo off
echo Stopping Flutter app...
taskkill /F /IM flutter.exe 2>nul
timeout /t 2 >nul

echo Cleaning build cache...
flutter clean

echo Getting dependencies...
flutter pub get

echo Starting app on Windows...
flutter run -d windows

pause
