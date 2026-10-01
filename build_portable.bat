@echo off
echo ========================================
echo   Mbadifa SACCO - Portable Version
echo   Building Portable EXE...
echo ========================================
echo.

echo Step 1: Building Windows Release...
flutter build windows --release

echo.
echo Step 2: Creating Portable Package...
cd build\windows\x64\runner\Release

echo Creating launcher script...
(
echo @echo off
echo cd /d "%%~dp0"
echo start "" "saccoplus_pro.exe"
echo exit
) > "Mbadifa SACCO.bat"

echo.
echo ========================================
echo   BUILD COMPLETE!
echo ========================================
echo.
echo Your portable app is ready at:
echo build\windows\x64\runner\Release\
echo.
echo To Install on SACCO:
echo 1. Copy the entire Release folder to USB
echo 2. Paste to SACCO computer
echo 3. Run "Mbadifa SACCO.bat"
echo 4. Create desktop shortcut
echo.
pause
