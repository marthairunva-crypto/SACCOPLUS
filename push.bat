@echo off
cd /d c:\SACCOPLUS
git add -A
git commit -m "feat: implement all admin screens + fix member 360 search + correct app name to Sacco Plus"
git push origin main
echo Done!
pause
