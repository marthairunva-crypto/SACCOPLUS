#!/usr/bin/env pwsh
# MBADIFA SACCO Web Deployment Script
# Quick deploy to Firebase Hosting

Write-Host "🚀 MBADIFA SACCO Web Deployment" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter not found. Please install Flutter first." -ForegroundColor Red
    exit 1
}

# Check if Firebase CLI is installed
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Firebase CLI not found." -ForegroundColor Red
    Write-Host "📦 Install with: npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
flutter pub get

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
    exit 1
}

Write-Host "🔨 Building Flutter web (release mode)..." -ForegroundColor Yellow
flutter build web --release --web-renderer canvaskit

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Build completed successfully!" -ForegroundColor Green
Write-Host ""

Write-Host "🌐 Deploying to Firebase Hosting..." -ForegroundColor Yellow
firebase deploy --only hosting

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deployment failed" -ForegroundColor Red
    Write-Host "💡 Make sure you're logged in: firebase login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "✅ Deployment successful! 🎉" -ForegroundColor Green
Write-Host ""
Write-Host "🌍 Your app is live at:" -ForegroundColor Cyan
Write-Host "   • https://mwiza-projects.web.app" -ForegroundColor White
Write-Host "   • https://mbadifa.infinitech.co.ug (after DNS setup)" -ForegroundColor White
Write-Host ""
Write-Host "📖 See WEB_HOSTING_SETUP.md for custom domain configuration" -ForegroundColor Yellow
