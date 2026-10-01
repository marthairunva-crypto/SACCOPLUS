@echo off
echo ========================================
echo   Mbadifa SACCO - Windows Installer
echo   Building MSIX Package...
echo ========================================
echo.

echo Step 1: Cleaning previous builds...
flutter clean

echo.
echo Step 2: Getting dependencies...
flutter pub get

echo.
echo Step 3: Building Windows Release...
flutter build windows --release

echo.
echo Step 4: Creating MSIX Installer...
flutter pub run msix:create

echo.
echo ========================================
echo   BUILD COMPLETE!
echo ========================================
echo.
echo Your installer is ready at:
echo build\windows\x64\runner\Release\mbadifa_sacco_pro.msix
echo.
echo Copy this file to USB and install on SACCO computer!
echo.
pause
