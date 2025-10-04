# Firestore Security Rules

Add these security rules to your Firebase project:

1. Go to Firebase Console
2. Navigate to Firestore Database
3. Click on "Rules" tab
4. Replace with the following:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isSignedIn() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the resource
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      // Allow users to read their own data
      allow read: if isOwner(userId);
      
      // Allow users to create their own document
      allow create: if isSignedIn() && request.auth.uid == userId;
      
      // Allow users to update their own document
      allow update: if isOwner(userId);
      
      // Devices sub-collection
      match /devices/{deviceId} {
        allow read, write: if isOwner(userId);
        
        // Commands sub-collection
        match /commands/{commandId} {
          allow read, write: if isOwner(userId);
        }
      }
      
      // Alarms sub-collection
      match /alarms/{alarmId} {
        allow read, write: if isOwner(userId);
      }
      
      // Logs sub-collection
      match /logs/{logId} {
        allow read, write: if isOwner(userId);
      }
    }
  }
}
```

## Initial Test Mode Rules (Development Only)

For testing during development, you can temporarily use:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2025, 12, 31);
    }
  }
}
```

⚠️ **Warning**: Replace with proper rules before production deployment!

## Storage Rules (if using Firebase Storage)

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```
