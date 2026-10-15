# 🚀 Quick Update Guide - Deploy Your Changes

## ✅ Changes Are Committed to GitHub!

Your code is already pushed to: https://github.com/marthairunva-crypto/SACCOPLUS

---

## 🎯 Option 1: Automatic One-Click Deploy

Just double-click this file:
```
DEPLOY_NOW.bat
```

It will:
1. Install all dependencies
2. Deploy Cloud Functions (for OTP on web)
3. Build web app
4. Deploy to Firebase Hosting

**Done! Your app will be live with OTP working!** 🎉

---

## 🎯 Option 2: Manual Step-by-Step

### Step 1: Install Dependencies

```powershell
# Flutter packages
flutter pub get

# Cloud Function packages
cd functions
npm install
cd ..
```

### Step 2: Deploy Cloud Functions (For OTP)

```powershell
firebase deploy --only functions
```

This takes 2-3 minutes. You'll see:
```
✔  functions: Finished running predeploy script.
✔  functions[sendSMS(us-central1)]: Successful create operation.
✔  Deploy complete!
```

### Step 3: Build Web App

```powershell
flutter build web --release
```

Wait for: `✓ Built build\web`

### Step 4: Deploy to Firebase Hosting

```powershell
firebase deploy --only hosting
```

You'll see:
```
✔  hosting: uploading files
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/mwiza-projects/overview
Hosting URL: https://mwiza-projects.web.app
```

---

## 🌐 Access Your Live App

After deployment, open in browser:
```
https://mwiza-projects.web.app
```

**Test OTP:**
1. Click "Register" or "Login"
2. Enter phone number
3. Click "Send OTP"
4. Check browser console (F12) for:
   - `📤 Sending SMS via Cloud Function (WEB)`
   - `✅ SMS sent successfully!`

---

## 📱 Custom Domain Setup

Want to use `mbadifa.infinitech.co.ug`?

### Firebase Console Steps:

1. **Go to Hosting:**
   https://console.firebase.google.com/project/mwiza-projects/hosting

2. **Click "Add custom domain"**

3. **Enter:** `mbadifa.infinitech.co.ug`

4. **Firebase shows DNS records:**
   ```
   Type: A
   Name: mbadifa
   Value: 151.101.1.195
   
   Type: A
   Name: mbadifa
   Value: 151.101.65.195
   ```

5. **Contact Infinitech IT** and give them:
   - Domain: `infinitech.co.ug`
   - Action: Add subdomain `mbadifa`
   - DNS Records: (the A records above)

6. **Wait 5-60 minutes** for DNS propagation

7. **Access at:** `https://mbadifa.infinitech.co.ug` 🎉

---

## 🔄 Updating After Code Changes

Whenever you make changes to the code:

```powershell
# 1. Commit changes
git add .
git commit -m "Your change description"
git push

# 2. Rebuild and redeploy
flutter build web --release
firebase deploy --only hosting
```

**That's it!** Changes will be live in 2-3 minutes.

---

## 🐛 Troubleshooting

### "Firebase command not found"

**Fix:** Install Firebase CLI
```powershell
npm install -g firebase-tools
```

### "Permission denied" when deploying

**Fix:** Login to Firebase
```powershell
firebase login
```

### "npm: command not found"

**Fix:** Install Node.js from https://nodejs.org/

### Web app deployed but OTP not working

**Fix:** Make sure Cloud Functions are deployed:
```powershell
firebase deploy --only functions
```

Check function logs:
```powershell
firebase functions:log --only sendSMS
```

### Changes not showing on web

**Fix:** Hard refresh browser:
- Chrome/Edge: `Ctrl + Shift + R`
- Firefox: `Ctrl + F5`

Or clear cache:
- Chrome: Settings → Privacy → Clear browsing data

---

## 📊 Check Deployment Status

### Check if functions are deployed:
```powershell
firebase functions:list
```

Should show: `sendSMS (us-central1)`

### Check hosting deployment:
```powershell
firebase hosting:sites:list
```

### View function logs:
```powershell
firebase functions:log --only sendSMS
```

### View hosting URLs:
Go to: https://console.firebase.google.com/project/mwiza-projects/hosting

---

## ⚡ Quick Commands Reference

```powershell
# Full deployment (everything)
DEPLOY_NOW.bat

# Or manually:
flutter pub get
cd functions && npm install && cd ..
firebase deploy

# Just update web app (after code changes)
flutter build web --release
firebase deploy --only hosting

# Just update cloud functions
firebase deploy --only functions

# View logs
firebase functions:log
```

---

## ✨ Summary

**To update your live web app right now:**

1. Double-click `DEPLOY_NOW.bat`
2. Wait 3-5 minutes
3. Open `https://mwiza-projects.web.app`
4. Test OTP functionality
5. Add custom domain if needed

**That's all! Your changes will be live!** 🚀

---

## 📞 Need Help?

Check these guides:
- `WEB_OTP_SETUP.md` - OTP troubleshooting
- `WEB_HOSTING_SETUP.md` - Hosting details
- `DEPLOY_MANUALLY.md` - Alternative methods

Firebase Console:
- https://console.firebase.google.com/project/mwiza-projects

GitHub Repository:
- https://github.com/marthairunva-crypto/SACCOPLUS
