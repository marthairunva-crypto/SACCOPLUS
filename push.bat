@echo off
cd /d c:\SACCOPLUS
echo Adding files...
git add -A
echo Committing...
git commit -m "feat: modern responsive dashboard"
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
