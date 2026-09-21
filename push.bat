@echo off
cd /d c:\SACCOPLUS
echo Adding files...
git add .
echo Committing...
git commit -m "fix: use saccoplus- prefix for all Firebase collections"
echo Pushing to GitHub...
git push origin main
if %errorlevel% equ 0 (
    echo.
    echo ✓ Successfully pushed to GitHub!
    echo.
    echo Check the build at: https://github.com/MOSEST4/SACCOPLUS/actions
) else (
    echo.
    echo × Push failed. Check your internet connection.
)
echo.
pause
