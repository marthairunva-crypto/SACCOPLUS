# How to Create Windows Icon for SACCOPLUS

## Option 1: Online Converter (Easiest)

1. Go to: https://convertio.co/png-ico/
2. Upload `assets/images/logo2.png`
3. Download the converted `.ico` file
4. Replace `windows/runner/resources/app_icon.ico` with the downloaded file
5. Commit and push:
   ```
   git add windows/runner/resources/app_icon.ico
   git commit -m "Update Windows app icon"
   git push
   ```

## Option 2: Using GIMP (Free Software)

1. Download GIMP: https://www.gimp.org/downloads/
2. Open `assets/images/logo2.png` in GIMP
3. File → Export As → Save as `app_icon.ico`
4. Replace `windows/runner/resources/app_icon.ico`
5. Commit and push

## Option 3: Using Python (If Installed)

```bash
pip install Pillow
python create_icon.py
git add windows/runner/resources/app_icon.ico
git commit -m "Update Windows app icon"
git push
```

## Current Status

✅ App name changed from `agri_loan.exe` to `saccoplus.exe`
⏳ Icon needs to be updated (currently using Flutter default)

After updating the icon and pushing, GitHub Actions will rebuild with:
- Correct name: **saccoplus.exe**
- Your custom icon from logo2.png
