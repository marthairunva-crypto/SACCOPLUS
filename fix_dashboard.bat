@echo off
echo Reverting corrupted dashboard file...
git checkout HEAD -- lib/screens/farmer/farmer_dashboard.dart
echo Done! File reverted to last commit.
echo Now you can hot restart your Flutter app.
pause
