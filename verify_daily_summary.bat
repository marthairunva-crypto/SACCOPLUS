@echo off
echo.
echo ========================================
echo VERIFYING DAILY SUMMARY SETUP
echo ========================================
echo.

echo 1. Checking if Firestore composite index exists...
echo    Required: tenantId + timestamp
echo.
echo    Go to Firebase Console:
echo    https://console.firebase.google.com/project/saccoplus-c49af/firestore/indexes
echo.
echo    Ensure you have a composite index for collection 'tellerTransactions':
echo      - tenantId (Ascending)
echo      - timestamp (Ascending)
echo.

echo 2. Current test transaction details:
echo    - Timestamp: 2026-09-22 14:12:24
echo    - TenantId: saccoplus
echo    - Type: deposit
echo    - Amount: 1000
echo.

echo 3. Daily Summary query parameters:
echo    - Date: 2026-09-22
echo    - StartOfDay: 2026-09-22 00:00:00
echo    - EndOfDay: 2026-09-22 23:59:59
echo.

echo This should match the transaction!
echo.
echo If Daily Summary shows 0:
echo   a. Check Firestore indexes are deployed
echo   b. Wait 1-2 minutes for index to build
echo   c. Refresh the Daily Summary tab
echo.

pause
