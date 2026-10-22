@echo off
cls
echo ╔════════════════════════════════════════════════╗
echo ║   MBADIFA SACCO - CORRECT DEPLOYMENT STEPS    ║
echo ╚════════════════════════════════════════════════╝
echo.
echo Current build time:
dir /T:W "C:\SACCOPLUS\build\web\index.html" | find "index.html"
echo.
echo ════════════════════════════════════════════════
echo STEP 1: Go to Netlify
echo ════════════════════════════════════════════════
echo.
echo Open in browser: https://app.netlify.com
echo Click on: mbadifainfinitech
echo Click on: Deploys tab
echo.
pause
echo.
echo ════════════════════════════════════════════════
echo STEP 2: Opening the CORRECT folder now...
echo ════════════════════════════════════════════════
echo.
echo I will open: C:\SACCOPLUS\build
echo.
echo YOU MUST SEE A FOLDER NAMED "web"
echo.
echo DRAG ONLY THE "web" FOLDER (not individual files!)
echo.
pause
start explorer "C:\SACCOPLUS\build"
echo.
echo ════════════════════════════════════════════════
echo VERIFICATION AFTER UPLOAD:
echo ════════════════════════════════════════════════
echo.
echo 1. Wait for "Site is live" on Netlify
echo 2. Open INCOGNITO: Ctrl+Shift+N
echo 3. Go to: https://mbadifa.infinitech.co.ug
echo 4. Try F12 - should NOT work
echo 5. Try right-click - should NOT work
echo 6. Console should be EMPTY (no Firebase links)
echo.
echo ════════════════════════════════════════════════
pause
