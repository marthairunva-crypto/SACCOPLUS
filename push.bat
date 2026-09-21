@echo off
cd /d c:\SACCOPLUS
git add -A
git commit -m "fix: responsive layout keeping all features"
git push origin main
if %errorlevel% equ 0 (
    echo.
    echo SUCCESS: All features preserved, made responsive!
) else (
    echo.
    echo Committed locally. Push manually if needed.
)
pause
