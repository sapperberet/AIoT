# 🔧 Firebase Authentication Error Fix

## ❌ Current Error

```
E/RecaptchaCallWrapper: Initial task failed for action RecaptchaAction(action=signInWithPassword)
with exception - An internal error has occurred. [ API key not valid. Please pass a valid API key. ]
```

## 🎯 Root Cause

This error occurs because **Email/Password authentication is NOT enabled** in your Firebase Console.

## ✅ SOLUTION - Enable Authentication (REQUIRED)

### Step 1: Open Firebase Console Authentication Page

Click this link or paste in browser:
```
https://console.firebase.google.com/project/smart-home-aiot-app/authentication/providers
```

### Step 2: Enable Email/Password Authentication

1. **If you see "Get Started" button:**
   - Click **"Get started"** button
   - This will initialize Firebase Authentication

2. **Go to "Sign-in method" tab** (top of page)

3. **Find "Email/Password" in the providers list:**
   - Look for "Email/Password" (should be first in the Native providers section)
   - Click on it

4. **Enable the provider:**
   - Toggle the **"Enable"** switch to ON (it should turn blue/green)
   - Click **"Save"** button

5. **Verify it's enabled:**
   - "Email/Password" should now show "Enabled" status in green

### Step 3: Verify API Key (Should be automatic, but check)

1. Still in Firebase Console, go to Project Settings:
   ```
   https://console.firebase.google.com/project/smart-home-aiot-app/settings/general
   ```

2. Scroll to "Your apps" section

3. Find your Android app: `com.example.smart_home_app`

4. Verify the configuration matches your `firebase_options.dart`:
   - API Key: `AIzaSyBLThVFqJqaRa3v-KXyxHDqmtcFw4J0MkU`
   - App ID: `1:252920696155:android:a7a2e4cefffed00c419e7e`

### Step 4: Restart Your App

After enabling Email/Password authentication:

```powershell
# Stop the app (press 'q' in terminal or Ctrl+C)

# Hot restart won't work for this change
# You need to fully restart the app

flutter run
```

## 🔍 Visual Guide

### What "Sign-in method" tab looks like:

```
┌─────────────────────────────────────────────┐
│  Sign-in method    Templates    Usage      │
├─────────────────────────────────────────────┤
│                                             │
│  Native Providers                           │
│  ┌───────────────────────────────────────┐ │
│  │ Email/Password          [Enabled] ✓   │ │  ← Should show "Enabled"
│  └───────────────────────────────────────┘ │
│  ┌───────────────────────────────────────┐ │
│  │ Phone                   [Disabled]    │ │
│  └───────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

## ⚠️ Important Notes

1. **This is REQUIRED** - Your app cannot authenticate users without enabling this
2. **Takes effect immediately** - No need to rebuild or reconfigure
3. **Free tier** - Email/Password authentication is included in Firebase free plan
4. **No credit card needed** - This feature doesn't require billing

## 🧪 Test After Enabling

1. **Restart the app:**
   ```powershell
   flutter run
   ```

2. **Try to sign in again** with your email and password

3. **Expected behavior:**
   - No more "API key not valid" error
   - Either successful login OR "user not found" (if account doesn't exist yet)

4. **If user doesn't exist, register first:**
   - Tap "Create Account" or "Register"
   - Enter email and password
   - Submit registration
   - You'll receive verification email

## 🐛 Still Getting Errors?

### Error: "There is no user record corresponding to this identifier"
**Solution:** You need to register first
- Go to registration screen
- Create an account
- Then try logging in

### Error: "The password is invalid"
**Solution:** Wrong password
- Try registering a new account
- Use password reset feature

### Error: "Network error"
**Solution:** Check internet connection
- Ensure device/emulator has internet
- Check Firebase project is not paused/disabled

### Error: "Too many requests"
**Solution:** Firebase rate limiting
- Wait a few minutes
- Try again

## 📸 Screenshot Checklist

After enabling, verify in Firebase Console → Authentication → Users:
- Should show "0 users" initially (or registered users)
- When you register, new user should appear here

## 🎉 Next Steps

Once Email/Password is enabled:

1. ✅ Restart your app
2. ✅ Test registration (create new account)
3. ✅ Check email for verification
4. ✅ Test login with created account
5. ✅ Verify you're redirected to home screen

---

**CRITICAL:** You MUST enable Email/Password authentication in Firebase Console before the app can work!

**Direct Link:** https://console.firebase.google.com/project/smart-home-aiot-app/authentication/providers
