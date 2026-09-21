@echo off
color 0A
echo.
echo ╔═══════════════════════════════════════════════════╗
echo ║         SACCOPLUS - Pushing to GitHub            ║
echo ╚═══════════════════════════════════════════════════╝
echo.
cd /d c:\SACCOPLUS
git push origin main
echo.
if %errorlevel% equ 0 (
    color 0A
    echo ✓✓✓ SUCCESS! Code pushed to GitHub!
    echo.
    echo Check your build at:
    echo https://github.com/MOSEST4/SACCOPLUS/actions
) else (
    color 0C
    echo ✗✗✗ FAILED! Check your internet connection.
)
echo.
echo.
pause
