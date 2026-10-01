# PowerShell script to open the Firestore index creation link
# This link is from the error message in your app

$indexUrl = "https://console.firebase.google.com/v1/r/project/mwiza-projects/firestore/indexes?create_composite=CmRwcm9qZWN0cy9td2l6YS1wcm9qZWN0cy9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvc2FjY29wbHVzLWxvYW5zL2luZGV4ZXMvXxABGg4KCHR5cGVJZBgBGAEKCgoGc3RhdHVzEAEaCAoEc3RhdHVzEAEqDAoEdHlwZRABGgQKBHR5cGUSBAoEdHlwZRgB"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Opening Firestore Index Creation Link..." -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will open your browser to create the missing index." -ForegroundColor Yellow
Write-Host "Click 'CREATE INDEX' button in the Firebase Console." -ForegroundColor Yellow
Write-Host ""

# Open the URL in default browser
Start-Process $indexUrl

Write-Host ""
Write-Host "✓ Browser opened!" -ForegroundColor Green
Write-Host "After creating the index, wait a few minutes for it to build," -ForegroundColor Yellow
Write-Host "then refresh your app." -ForegroundColor Yellow
Write-Host ""
