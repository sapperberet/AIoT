# 🔒 Security Fix Guide - Firebase API Key Protection

## ⚠️ Security Issue Detected

GitHub has detected exposed Firebase API keys in your repository. This guide will help you secure them.

## 🛡️ What We've Done

1. ✅ Added `lib/firebase_options.dart` to `.gitignore`
2. ✅ Added `android/app/google-services.json` to `.gitignore`
3. ✅ Created `.env.example` template for environment variables
4. ✅ Updated app to use environment variables (optional for Firebase Web, not needed for Android)

## 🔧 Action Required

### Step 1: Remove Sensitive Files from Git History

The API key is already in your git history. You need to:

1. **Regenerate Firebase API Key** (Recommended):
   - Go to [Firebase Console](https://console.firebase.google.com/project/smart-home-aiot-app/settings/general)
   - Navigate to: Settings → General → Your apps
   - Delete the current Android app API key
   - Add a new Android app or regenerate the key

2. **Remove from Git History** (Required):

```powershell
# Install BFG Repo-Cleaner (if not installed)
# Download from: https://rtyley.github.io/bfg-repo-cleaner/

# Or use git filter-branch (built-in):
git filter-branch --force --index-filter `
  "git rm --cached --ignore-unmatch lib/firebase_options.dart" `
  --prune-empty --tag-name-filter cat -- --all

# Force push to GitHub
git push origin --force --all
git push origin --force --tags
```

### Step 2: Verify Files Are Ignored

```powershell
# Check that firebase_options.dart is now ignored
git status

# It should NOT appear in "Changes to be committed" or "Untracked files"
```

### Step 3: Regenerate Firebase Configuration

After securing your repo, regenerate the Firebase config:

```powershell
# Run FlutterFire CLI to regenerate firebase_options.dart
flutterfire configure --project=smart-home-aiot-app
```

This will create a new `firebase_options.dart` file that:
- ✅ Will be ignored by git (due to .gitignore)
- ✅ Contains fresh API keys
- ✅ Won't be committed to your repository

## 📋 Security Checklist

- [ ] Add `lib/firebase_options.dart` to `.gitignore` ✅ (Already done)
- [ ] Add `android/app/google-services.json` to `.gitignore` ✅ (Already done)
- [ ] Remove sensitive files from git history
- [ ] Regenerate Firebase API keys
- [ ] Regenerate `firebase_options.dart` using FlutterFire CLI
- [ ] Verify files are not tracked by git
- [ ] Force push cleaned repository
- [ ] Update Firebase Console security rules
- [ ] Enable Firebase App Check for additional security

## 🔐 Firebase Security Best Practices

### 1. Firebase API Keys for Android/iOS are Different

**Important Note**: For native mobile apps (Android/iOS), the Firebase API key in `firebase_options.dart` is **not a secret** in the traditional sense. It's meant to be bundled with your app.

**Real Security Comes From**:
- ✅ **Firebase Security Rules** (Firestore, Storage, etc.)
- ✅ **Firebase App Check** (prevents abuse)
- ✅ **Package name/Bundle ID restrictions**

### 2. Restrict API Key Usage

In [Google Cloud Console](https://console.cloud.google.com/apis/credentials?project=smart-home-aiot-app):

1. Find your API key
2. Click "Edit"
3. Under "Application restrictions":
   - Select "Android apps"
   - Add your package name: `com.example.smart_home_app`
   - Add SHA-1 fingerprint

### 3. Enable Firebase App Check

```powershell
# Add to pubspec.yaml
flutter pub add firebase_app_check

# Configure in your app
```

### 4. Strengthen Firestore Security Rules

The rules in `FIRESTORE_RULES.md` are good, but ensure they're published:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only allow authenticated users
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
    }
    
    match /devices/{deviceId} {
      allow read, write: if request.auth != null && 
                          resource.data.userId == request.auth.uid;
    }
  }
}
```

## ✅ Verification

After completing the steps:

1. Check GitHub Security Alerts:
   - Go to: https://github.com/sapperberet/AIoT/security
   - Verify alerts are resolved

2. Test your app:
   ```powershell
   flutter run
   ```

3. Verify Firestore access:
   - Login should work
   - Data should sync
   - Unauthorized access should be denied

## 📞 Need Help?

If you encounter issues:
- Check Firebase Console logs
- Review Firestore rules
- Test with Firebase Emulator locally first

## 🎯 Summary

- Firebase API keys for mobile apps are **safe to distribute** with your app
- **Real security** comes from Firebase Rules and App Check
- Git history cleaning is **recommended** for clean practices
- API key restrictions add an **extra layer of protection**

---

**Next Steps**: Follow Step 1-3 above, then continue with app development!
