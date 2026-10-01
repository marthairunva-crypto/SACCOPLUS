# MBADIFA SACCO - Windows Installer Guide

## 📦 Automated Windows Build

Your app now has **GitHub Actions** configured to automatically build a professional Windows installer every time you push code to the `main` branch.

## 🚀 What Happens Automatically

When you push to GitHub:
1. GitHub Actions triggers the build workflow
2. Flutter builds the Windows release version
3. Inno Setup creates a professional installer
4. The installer is uploaded as an artifact
5. A GitHub Release is created with the installer attached

## 📥 How to Download the Installer

### Option 1: From GitHub Actions (Every Push)
1. Go to your repository: https://github.com/MOSEST4/SACCOPLUS
2. Click the **"Actions"** tab at the top
3. Click on the latest workflow run
4. Scroll down to **"Artifacts"** section
5. Download **"MBADIFA-SACCO-Installer"**
6. Extract the ZIP file
7. Run `MBADIFA_SACCO_Setup.exe`

### Option 2: From GitHub Releases (Version Releases)
1. Go to: https://github.com/MOSEST4/SACCOPLUS/releases
2. Click on the latest release
3. Download `MBADIFA_SACCO_Setup.exe`
4. Run the installer

## ✨ Installer Features

The installer includes:

### ✅ Desktop Shortcut
- Automatically creates a desktop icon
- Double-click to launch the app

### ✅ Start Menu Integration
- Appears in Windows Start Menu
- Search "MBADIFA SACCO" to find it

### ✅ Optional Features During Install
- [ ] Create desktop shortcut (checked by default)
- [ ] Create quick launch icon (Windows 7/8 only)
- [ ] Launch at Windows startup (optional)

### ✅ Clean Uninstall
- Uninstall from Windows Settings → Apps
- Option to keep or remove user data
- Removes all registry entries

## 🔧 Manual Build (If Needed)

If you want to build the installer locally:

```powershell
# 1. Install Inno Setup
choco install innosetup -y

# 2. Build Flutter Windows app
flutter build windows --release

# 3. Create installer
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "windows\installer\setup.iss"

# 4. Installer is created at:
# build\windows\installer\MBADIFA_SACCO_Setup.exe
```

## 📊 Build Status

Check the build status badge on your GitHub repository:
- 🟢 Green = Build successful
- 🔴 Red = Build failed (check logs in Actions tab)
- 🟡 Yellow = Build in progress

## 🎯 Current Version Format

Each build is automatically versioned as: `v1.0.<build_number>`

Example: `v1.0.123` (where 123 is the GitHub Actions run number)

## 📝 What Changed in This Build

This release includes:
- ✅ MBADIFA SACCO branding complete
- ✅ SMS notifications for deposits, withdrawals, and loan repayments
- ✅ Data reconciliation tool for fixing savings balances
- ✅ Professional Windows installer with desktop shortcut
- ✅ Optimized table layouts for better user experience
- ✅ Fixed dashboard type errors
- ✅ Firebase indexes deployed

## 🔗 Important Links

- **Repository**: https://github.com/MOSEST4/SACCOPLUS
- **Actions**: https://github.com/MOSEST4/SACCOPLUS/actions
- **Releases**: https://github.com/MOSEST4/SACCOPLUS/releases
- **Issues**: https://github.com/MOSEST4/SACCOPLUS/issues

## 🆘 Troubleshooting

### Build Failed?
1. Check the GitHub Actions log for errors
2. Look for the workflow run in the Actions tab
3. Click on the failed job to see detailed logs

### Installer Won't Run?
- Windows SmartScreen may block it (first-time apps)
- Click "More info" → "Run anyway"
- Or code-sign the installer for production use

### Missing DLLs?
- The installer includes all required DLLs
- If you get errors, try reinstalling

## 🎉 Next Steps

1. **Wait for the build** (~5-10 minutes)
2. **Download the installer** from Actions or Releases
3. **Install on any Windows PC**
4. **Create a desktop shortcut** during installation
5. **Launch and test** all features

---

**Made with ❤️ for MBADIFA SACCO**
*"Poverty Must Go"*
