@echo off
echo ========================================
echo SACCOPLUS - Windows Build Script
echo ========================================
echo.

echo [1/4] Cleaning previous builds...
call flutter clean
echo.

echo [2/4] Getting dependencies...
call flutter pub get
echo.

echo [3/4] Building Windows Release...
call flutter build windows --release
echo.

echo [4/4] Build Complete!
echo.
echo ========================================
echo Your EXE is ready at:
echo %CD%\build\windows\x64\runner\Release\saccoplus.exe
echo ========================================
echo.
echo Copy the entire "Release" folder to distribute your app.
echo.
pause
