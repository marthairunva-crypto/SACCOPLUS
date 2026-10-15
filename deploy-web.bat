@echo off
REM MBADIFA SACCO Web Deployment Script
REM Quick deploy to Firebase Hosting

echo.
echo ================================
echo  MBADIFA SACCO Web Deployment
echo ================================
echo.

echo [1/4] Installing dependencies...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to install dependencies
    exit /b 1
)

echo.
echo [2/4] Building Flutter web...
call flutter build web --release --web-renderer canvaskit
if errorlevel 1 (
    echo ERROR: Build failed
    exit /b 1
)

echo.
echo [3/4] Deploying to Firebase Hosting...
call firebase deploy --only hosting
if errorlevel 1 (
    echo ERROR: Deployment failed
    echo TIP: Run 'firebase login' first
    exit /b 1
)

echo.
echo ================================
echo  Deployment Successful!
echo ================================
echo.
echo Your app is live at:
echo   - https://mwiza-projects.web.app
echo   - https://mbadifa.infinitech.co.ug (after DNS)
echo.
echo See WEB_HOSTING_SETUP.md for details
echo.
pause
