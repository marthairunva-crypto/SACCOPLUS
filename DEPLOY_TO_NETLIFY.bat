@echo off
echo ========================================
echo MBADIFA SACCO - Deploy to Netlify
echo ========================================
echo.
echo This will open File Explorer to your build folder.
echo.
echo IMPORTANT STEPS:
echo 1. Go to https://app.netlify.com in your browser
echo 2. Click on "mbadifainfinitech" site
echo 3. Look for "Deploys" tab
echo 4. Drag the ENTIRE "web" folder that will open
echo 5. NOT individual files - drag the whole "web" folder
echo.
echo Press any key to open the build folder...
pause > nul
explorer C:\SACCOPLUS\build
echo.
echo ========================================
echo Folder opened! Now drag "web" folder to Netlify
echo ========================================
pause
