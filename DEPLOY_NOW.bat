@echo off
echo ========================================
echo  DEPLOY WEB APP WITH OTP FIX
echo ========================================
echo.

echo [1/5] Installing Flutter dependencies...
call flutter pub get
if errorlevel 1 goto error

echo.
echo [2/5] Installing Cloud Function dependencies...
cd functions
call npm install
if errorlevel 1 (
    cd ..
    goto error
)
cd ..

echo.
echo [3/5] Deploying Cloud Functions to Firebase...
call firebase deploy --only functions
if errorlevel 1 goto error

echo.
echo [4/5] Building Flutter Web (Production)...
call flutter build web --release
if errorlevel 1 goto error

echo.
echo [5/5] Deploying Web App to Firebase Hosting...
call firebase deploy --only hosting
if errorlevel 1 goto error

echo.
echo ========================================
echo  DEPLOYMENT SUCCESSFUL!
echo ========================================
echo.
echo Your web app is now live at:
echo   https://mwiza-projects.web.app
echo.
echo OTP/SMS now works on web via Cloud Functions!
echo.
echo Custom domain setup:
echo   1. Go to Firebase Console
echo   2. Add custom domain: mbadifa.infinitech.co.ug
echo   3. Update DNS records with Infinitech IT
echo.
pause
goto end

:error
echo.
echo ========================================
echo  DEPLOYMENT FAILED!
echo ========================================
echo.
echo Check the error messages above.
echo.
echo Common issues:
echo   - Firebase CLI not installed (npm install -g firebase-tools)
echo   - Not logged in (firebase login)
echo   - Node.js not installed
echo.
pause

:end
