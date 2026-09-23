@echo off
echo.
echo ========================================
echo FIREBASE COMPOSITE INDEX REQUIRED
echo ========================================
echo.
echo Your Loan Applications screen needs a Firestore composite index.
echo.
echo Click this link to create the index:
echo.
echo https://console.firebase.google.com/project/_/firestore/indexes
echo.
echo Then create an index with these settings:
echo   Collection: saccoplus-loans
echo   Field 1: tenantId (Ascending)
echo   Field 2: createdAt (Descending)
echo.
echo The index will take 1-2 minutes to build.
echo.
echo ========================================
echo.
pause
