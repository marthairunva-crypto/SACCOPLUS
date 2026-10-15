# 🌐 MBADIFA SACCO Web Hosting Setup

Deploy your Flutter app to **mbadifa.infinitech.co.ug**

---

## 📋 Prerequisites

1. ✅ Firebase project: `mwiza-projects` (already configured)
2. ✅ Flutter app ready (already built)
3. 🔧 Firebase CLI installed
4. 🌍 Domain access: `mbadifa.infinitech.co.ug`

---

## 🚀 Quick Deployment (Local)

### Step 1: Install Firebase CLI

```powershell
# Install Firebase Tools globally
npm install -g firebase-tools

# Or if you don't have npm, download from:
# https://firebase.google.com/docs/cli
```

### Step 2: Login to Firebase

```powershell
firebase login
```

### Step 3: Build Flutter Web

```powershell
# Build optimized web version
flutter build web --release --web-renderer canvaskit

# This creates: build/web/ folder
```

### Step 4: Initialize Firebase Hosting (First time only)

```powershell
firebase init hosting

# When prompted:
# - Select: "Use an existing project"
# - Choose: "mwiza-projects (staging)"
# - Public directory: build/web
# - Configure as single-page app: Yes
# - Set up automatic builds: No
# - Overwrite index.html: No
```

### Step 5: Deploy to Firebase

```powershell
firebase deploy --only hosting
```

You'll get a URL like: `https://mwiza-projects.web.app`

---

## 🔗 Setup Custom Domain (mbadifa.infinitech.co.ug)

### Step 1: Add Custom Domain in Firebase Console

1. Go to: https://console.firebase.google.com/project/mwiza-projects/hosting
2. Click **"Add custom domain"**
3. Enter: `mbadifa.infinitech.co.ug`
4. Firebase will provide DNS records

### Step 2: Configure DNS Records

You'll need to add these records to your domain DNS (contact your domain provider or Infinitech IT):

**If using A records:**
```
Type: A
Name: mbadifa
Value: 151.101.1.195
Value: 151.101.65.195
```

**If using CNAME (recommended):**
```
Type: CNAME
Name: mbadifa
Value: mwiza-projects.web.app
```

### Step 3: Verify Domain

Firebase will automatically verify and provision SSL certificate (takes 5-60 minutes).

---

## ⚡ Automatic Deployment via GitHub Actions

Already configured! Every push to `main` branch will:
1. Build Flutter web automatically
2. Deploy to Firebase Hosting
3. Update mbadifa.infinitech.co.ug

### Setup GitHub Secret

1. Generate Firebase service account:
```powershell
firebase login:ci
# Copy the token
```

2. Add to GitHub repository:
   - Go to: https://github.com/marthairunva-crypto/SACCOPLUS/settings/secrets/actions
   - Click **"New repository secret"**
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: Paste the entire service account JSON

---

## 🧪 Testing

### Local Testing

```powershell
# Test web build locally
flutter run -d chrome --release

# Or serve the built files
firebase serve --only hosting
# Opens at: http://localhost:5000
```

### Production Testing

After deployment, test at:
- Firebase URL: `https://mwiza-projects.web.app`
- Custom domain: `https://mbadifa.infinitech.co.ug`

---

## 📱 Mobile vs Web Considerations

Some features may need web-specific handling:

### ✅ Works on Web
- Firebase Auth, Firestore, Storage
- All SACCO operations (savings, loans, statements)
- PDF generation and downloads
- CSV exports
- Admin dashboard

### ⚠️ Needs Attention
- `image_picker` - Works but shows file dialog instead of camera
- `path_provider` - Use web-compatible alternatives
- SMS sending - Works (backend API call)
- Printing - Uses browser print dialog

---

## 🔧 Web-Specific Configuration

### Enable Web Platform

```powershell
# Already done, but for reference:
flutter create --platforms=web .
```

### Update index.html (if needed)

Edit `web/index.html` for:
- App title
- Meta tags
- Favicon
- Loading screen

---

## 📊 Performance Optimization

### Already Applied
- ✅ CanvasKit renderer (better performance)
- ✅ Release build optimization
- ✅ Asset caching headers
- ✅ CDN via Firebase Hosting

### Additional Options

```powershell
# Use HTML renderer (smaller, faster initial load)
flutter build web --release --web-renderer html

# Use auto renderer (chooses best for device)
flutter build web --release --web-renderer auto
```

---

## 🛡️ Security

### Firebase Hosting Security Rules

Already configured:
- ✅ HTTPS enforced
- ✅ Free SSL certificate
- ✅ DDoS protection via Firebase CDN
- ✅ Firestore security rules (separate file)

### Update Firestore Rules

Make sure web domain is allowed in `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Your existing rules here
  }
}
```

---

## 🔄 Deployment Commands Cheat Sheet

```powershell
# Full rebuild and deploy
flutter build web --release && firebase deploy --only hosting

# Deploy only (if build exists)
firebase deploy --only hosting

# Deploy to preview channel (test before live)
firebase hosting:channel:deploy preview

# View deployment history
firebase hosting:sites:list

# Rollback to previous version
firebase hosting:clone SOURCE_SITE:SOURCE_CHANNEL SITE:live
```

---

## 🐛 Troubleshooting

### Issue: "Firebase not initialized"

Check `lib/main.dart` has web initialization:

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}
```

### Issue: "Routes not working"

Fixed by `firebase.json` rewrites - all routes go to `index.html`.

### Issue: "Images not loading"

Check `pubspec.yaml` assets are declared and run:
```powershell
flutter clean
flutter pub get
flutter build web --release
```

### Issue: "Custom domain not connecting"

1. Verify DNS propagation: `nslookup mbadifa.infinitech.co.ug`
2. Check Firebase console for verification status
3. DNS changes can take 24-48 hours to propagate globally

---

## 📞 Support

**Firebase Console:**
https://console.firebase.google.com/project/mwiza-projects

**Domain DNS Management:**
Contact: Infinitech IT Team

**GitHub Actions Status:**
https://github.com/marthairunva-crypto/SACCOPLUS/actions

---

## ✨ Quick Start (TL;DR)

```powershell
# 1. Build
flutter build web --release

# 2. Deploy
firebase deploy --only hosting

# 3. Add custom domain in Firebase Console
# 4. Update DNS records with your provider
# 5. Wait for SSL verification (5-60 mins)
# 6. Access at https://mbadifa.infinitech.co.ug
```

---

**That's it! Your SACCO app will be live on the web! 🎉**
