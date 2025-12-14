import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/face_auth_service.dart';
import '../services/face_auth_http_service.dart';
import '../services/user_approval_service.dart';
import '../models/user_model.dart';
import '../models/face_auth_model.dart';
import '../models/access_level.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final BiometricAuthService? _biometricAuthService;
  final FaceAuthService? _faceAuthService;
  final FaceAuthHttpService? _faceAuthHttpService;
  final UserApprovalService _approvalService = UserApprovalService();

  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPendingApproval = false;

  // Biometric authentication state
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  String? _biometricDescription;

  // Face authentication state
  FaceAuthStatus _faceAuthStatus = FaceAuthStatus.idle;
  FaceAuthBeacon? _discoveredBeacon;
  String? _faceAuthMessage;

  AuthProvider({
    required AuthService authService,
    BiometricAuthService? biometricAuthService,
    FaceAuthService? faceAuthService,
    FaceAuthHttpService? faceAuthHttpService,
  })  : _authService = authService,
        _biometricAuthService = biometricAuthService,
        _faceAuthService = faceAuthService,
        _faceAuthHttpService = faceAuthHttpService {
    _init();
  }

  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isPendingApproval => _isPendingApproval;
  bool get isApproved => _userModel?.isApproved ?? false;
  AccessLevel get userAccessLevel =>
      _userModel?.accessLevel ?? AccessLevel.pending;
  bool get isAdmin => _userModel?.isAdmin ?? false;
  UserApprovalService get approvalService => _approvalService;

  // Biometric auth getters
  bool get isBiometricAvailable => _isBiometricAvailable;
  bool get isBiometricEnabled => _isBiometricEnabled;
  String? get biometricDescription => _biometricDescription;

  // Face auth getters
  FaceAuthStatus get faceAuthStatus => _faceAuthStatus;
  FaceAuthBeacon? get discoveredBeacon => _discoveredBeacon;
  String? get faceAuthMessage => _faceAuthMessage;
  bool get isFaceAuthAvailable =>
      _faceAuthService != null || _faceAuthHttpService != null;

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      _currentUser = user;
      if (user != null) {
        // Check if session is still valid
        final isValid = await _authService.isSessionValid();
        if (!isValid) {
          debugPrint('⚠️ Session expired, logging out...');
          await signOut();
          return;
        }
        await _loadUserData();
        await _checkBiometricStatus();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });

    // Check session validity on app start
    _checkSessionValidity();

    // Initialize biometric status
    _checkBiometricAvailability();

    // Initialize face auth listeners if available
    if (_faceAuthService != null) {
      _faceAuthService!.statusStream.listen((status) {
        _faceAuthStatus = status;
        _updateFaceAuthMessage(status);
        notifyListeners();
      });

      _faceAuthService!.beaconStream.listen((beacon) {
        _discoveredBeacon = beacon;
        notifyListeners();
      });
    }

    // Initialize HTTP-based face auth listeners if available
    if (_faceAuthHttpService != null) {
      _faceAuthHttpService!.statusStream.listen((status) {
        _faceAuthStatus = status;
        _updateFaceAuthMessage(status);
        notifyListeners();
      });

      _faceAuthHttpService!.beaconStream.listen((beacon) {
        _discoveredBeacon = beacon;
        notifyListeners();
      });
    }
  }

  Future<void> _checkSessionValidity() async {
    if (_currentUser != null) {
      await _authService.signOutIfSessionExpired();
    }
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      _userModel = await _authService.getUserData(_currentUser!.uid);
      debugPrint('📊 _loadUserData: displayName = ${_userModel?.displayName}');
      debugPrint('📊 _loadUserData: email = ${_userModel?.email}');
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _isPendingApproval = false;
    notifyListeners();

    try {
      // Sign in - don't capture UserCredential to avoid type cast error
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Get current user directly from auth instance
      _currentUser = _authService.currentUser;

      // Load user data from Firestore
      if (_currentUser != null) {
        await _loadUserData();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final errorStr = e.toString();

      // Handle USER_PENDING_APPROVAL - user exists but not approved yet
      if (errorStr == 'USER_PENDING_APPROVAL') {
        debugPrint('USER_PENDING_APPROVAL caught, user needs admin approval');
        _currentUser = _authService.currentUser;
        _isPendingApproval = true;
        if (_currentUser != null) {
          await _loadUserData();
        }
        _isLoading = false;
        notifyListeners();
        return false; // Return false but set isPendingApproval flag
      }

      // Handle PIGEON_ERROR_USER_AUTHENTICATED - sign-in succeeded but Pigeon API had issues
      if (errorStr == 'PIGEON_ERROR_USER_AUTHENTICATED') {
        debugPrint(
            'PIGEON_ERROR_USER_AUTHENTICATED caught, user is authenticated');
        _currentUser = _authService.currentUser;
        if (_currentUser != null) {
          debugPrint('Login succeeded! User: ${_currentUser?.email}');
          await _loadUserData();
          // Check if user is pending approval
          if (_userModel?.accessLevel == AccessLevel.pending ||
              !(_userModel?.isApproved ?? false)) {
            _isPendingApproval = true;
            _isLoading = false;
            notifyListeners();
            return false;
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      // If error contains type cast or Pigeon errors, try getting user anyway (it may have succeeded)
      if (errorStr.contains('PigeonUserDetails') ||
          errorStr.contains('PigeonUserInfo') ||
          errorStr.contains('List<Object?>') ||
          errorStr.contains('type cast') ||
          errorStr.contains('not a subtype') ||
          errorStr.contains('Pigeon')) {
        debugPrint(
            'Type cast/Pigeon error caught, checking if login succeeded anyway...');
        _currentUser = _authService.currentUser;

        if (_currentUser != null) {
          // Login actually succeeded despite the error
          debugPrint('Login succeeded! User: ${_currentUser?.email}');
          await _loadUserData();
          // Check if user is pending approval
          if (_userModel?.accessLevel == AccessLevel.pending ||
              !(_userModel?.isApproved ?? false)) {
            _isPendingApproval = true;
            _isLoading = false;
            notifyListeners();
            return false;
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _errorMessage = errorStr;
      _isLoading = false;
      _currentUser = null;
      _userModel = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
      String email, String password, String displayName) async {
    _isLoading = true;
    _errorMessage = null;
    _isPendingApproval = false;
    notifyListeners();

    try {
      // Register - don't capture UserCredential to avoid type cast error
      await _authService.registerWithEmailAndPassword(
        email: email,
        password: password,
        displayName: displayName,
      );

      // Get current user directly from auth instance
      _currentUser = _authService.currentUser;

      // Load user data from Firestore
      if (_currentUser != null) {
        await _loadUserData();

        // Check if this is the first admin (auto-approved) or pending approval
        if (_userModel?.accessLevel == AccessLevel.pending ||
            !(_userModel?.isApproved ?? false)) {
          _isPendingApproval = true;
          _isLoading = false;
          notifyListeners();
          return true; // Registration successful but pending approval
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final errorStr = e.toString();
      // Handle PIGEON_ERROR_USER_AUTHENTICATED - registration succeeded but Pigeon API had issues
      if (errorStr == 'PIGEON_ERROR_USER_AUTHENTICATED') {
        debugPrint(
            'PIGEON_ERROR_USER_AUTHENTICATED caught, user is authenticated');
        _currentUser = _authService.currentUser;
        if (_currentUser != null) {
          debugPrint('Registration succeeded! User: ${_currentUser?.email}');
          await _loadUserData();
          // Check if pending approval
          if (_userModel?.accessLevel == AccessLevel.pending ||
              !(_userModel?.isApproved ?? false)) {
            _isPendingApproval = true;
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      // If error contains type cast or Pigeon errors, try getting user anyway (it may have succeeded)
      if (errorStr.contains('PigeonUserDetails') ||
          errorStr.contains('PigeonUserInfo') ||
          errorStr.contains('List<Object?>') ||
          errorStr.contains('type cast') ||
          errorStr.contains('not a subtype') ||
          errorStr.contains('Pigeon')) {
        debugPrint(
            'Type cast/Pigeon error caught, checking if registration succeeded anyway...');
        _currentUser = _authService.currentUser;

        if (_currentUser != null) {
          // Registration actually succeeded despite the error
          debugPrint('Registration succeeded! User: ${_currentUser?.email}');
          await _loadUserData();
          // Check if pending approval
          if (_userModel?.accessLevel == AccessLevel.pending ||
              !(_userModel?.isApproved ?? false)) {
            _isPendingApproval = true;
          }
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _errorMessage = e.toString();
      _isLoading = false;
      _currentUser = null;
      _userModel = null;
      notifyListeners();
      return false;
    }
  }

  // Flag to track if app is in "locked" state (signed out but biometric can unlock)
  bool _isAppLocked = false;
  bool get isAppLocked => _isAppLocked;

  /// Sign out - if biometric is enabled, only "locks" the app instead of full sign out
  /// This allows biometric to unlock without re-entering credentials
  Future<void> signOut({bool forceFullSignOut = false}) async {
    // Check if biometric is enabled - if so, do a "soft" sign out (lock)
    final hasBiometricCredentials =
        await _biometricAuthService?.hasBiometricCredentials() ?? false;

    if (hasBiometricCredentials && !forceFullSignOut) {
      // Soft sign out - keep Firebase session, just "lock" the app
      debugPrint('🔒 Soft sign out - biometric enabled, keeping session');
      _isAppLocked = true;
      notifyListeners();
      return;
    }

    // Full sign out - clear everything including biometric
    await _authService.signOut();
    await _biometricAuthService?.disableBiometric();
    _currentUser = null;
    _userModel = null;
    _isPendingApproval = false;
    _isAppLocked = false;
    notifyListeners();
  }

  /// Force full sign out (clears biometric settings too)
  Future<void> forceSignOut() async {
    await signOut(forceFullSignOut: true);
  }

  /// Unlock the app after biometric verification (for soft sign out)
  void unlockApp() {
    _isAppLocked = false;
    notifyListeners();
  }

  Future<void> sendEmailVerification() async {
    if (_currentUser != null && !_currentUser!.emailVerified) {
      await _currentUser!.sendEmailVerification();
    }
  }

  // ========== BIOMETRIC AUTHENTICATION METHODS ==========

  /// Check if biometric authentication is available on device
  Future<void> _checkBiometricAvailability() async {
    if (_biometricAuthService == null) {
      _isBiometricAvailable = false;
      return;
    }

    try {
      final canCheck = await _biometricAuthService!.canCheckBiometrics();
      final isSupported = await _biometricAuthService!.isDeviceSupported();
      _isBiometricAvailable = canCheck && isSupported;

      if (_isBiometricAvailable) {
        _biometricDescription =
            await _biometricAuthService!.getBiometricsDescription();
        debugPrint('✅ Biometric available: $_biometricDescription');
      } else {
        debugPrint('⚠️ Biometric authentication not available');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error checking biometric availability: $e');
      _isBiometricAvailable = false;
    }
  }

  /// Check if biometric is enabled for current user
  Future<void> _checkBiometricStatus() async {
    if (_biometricAuthService == null || _currentUser == null) {
      _isBiometricEnabled = false;
      return;
    }

    try {
      _isBiometricEnabled = await _biometricAuthService!.isBiometricEnabled();
      final lastUser = await _biometricAuthService!.getLastBiometricUser();

      // Disable if it was enabled for a different user
      if (_isBiometricEnabled && lastUser != _currentUser!.uid) {
        _isBiometricEnabled = false;
        await _biometricAuthService!.disableBiometric();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error checking biometric status: $e');
      _isBiometricEnabled = false;
    }
  }

  /// Authenticate using biometric (fingerprint, face ID)
  /// SECURITY: Verifies Firebase Auth user still exists before allowing access
  /// Also handles "app locked" state when user did soft sign out with biometric enabled
  Future<bool> authenticateWithBiometric() async {
    if (_biometricAuthService == null) {
      _errorMessage = 'Biometric authentication not available';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // Check if biometric credentials are stored
      final hasBiometricCredentials =
          await _biometricAuthService!.hasBiometricCredentials();
      if (!hasBiometricCredentials) {
        _errorMessage =
            'Biometric login not set up. Please log in with your credentials first.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // SECURITY: Verify the Firebase Auth user still exists
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        // No session - this means full sign out happened or session expired
        _errorMessage = 'Session expired. Please log in again.';
        _isLoading = false;
        await _biometricAuthService!.disableBiometric();
        notifyListeners();
        return false;
      }

      // Try to reload the user to verify they still exist in Firebase Auth
      try {
        await firebaseUser.reload();
        // Get fresh user reference after reload
        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser == null) {
          // User was deleted from Firebase Auth
          _errorMessage =
              'Your account has been removed. Please contact an administrator.';
          _isLoading = false;
          await _biometricAuthService!.disableBiometric();
          await signOut(forceFullSignOut: true);
          notifyListeners();
          return false;
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        // Check for user-not-found or user-disabled errors
        if (errorStr.contains('user-not-found') ||
            errorStr.contains('user-disabled') ||
            errorStr.contains('user-token-expired') ||
            errorStr.contains('invalid-user-token')) {
          debugPrint('🚫 Firebase user no longer valid: $e');
          _errorMessage =
              'Your account is no longer valid. Please log in again.';
          _isLoading = false;
          await _biometricAuthService!.disableBiometric();
          await signOut(forceFullSignOut: true);
          notifyListeners();
          return false;
        }
        // For network errors, allow biometric if we have a cached user
        // (graceful offline handling)
        debugPrint('⚠️ Could not verify user, allowing cached session: $e');
      }

      // Now perform the actual biometric authentication
      final authenticated = await _biometricAuthService!.authenticate(
        localizedReason: 'Please authenticate to access your account',
      );

      if (authenticated) {
        // Unlock the app if it was locked
        _isAppLocked = false;

        // Reload user data to ensure we have latest info
        await _loadUserData();

        // Check if user is not approved (pending approval)
        if (_userModel != null && !_userModel!.isApproved) {
          _errorMessage = 'Your account is pending approval.';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        debugPrint('✅ Biometric authentication successful');
      }

      _isLoading = false;
      notifyListeners();

      return authenticated;
    } catch (e) {
      _errorMessage = 'Biometric authentication failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Enable biometric authentication for current user
  Future<bool> enableBiometric() async {
    if (_biometricAuthService == null || _currentUser == null) {
      _errorMessage = 'Cannot enable biometric authentication';
      notifyListeners();
      return false;
    }

    try {
      // First authenticate to confirm
      final authenticated = await _biometricAuthService!.authenticate(
        localizedReason: 'Authenticate to enable biometric login',
      );

      if (authenticated) {
        // Store both user ID and email for biometric login after sign out
        await _biometricAuthService!.enableBiometric(
          _currentUser!.uid,
          userEmail: _currentUser!.email,
        );
        _isBiometricEnabled = true;
        notifyListeners();
        debugPrint(
            '✅ Biometric authentication enabled for ${_currentUser!.email}');
        return true;
      } else {
        _errorMessage = 'Biometric authentication failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to enable biometric: $e';
      notifyListeners();
      return false;
    }
  }

  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    if (_biometricAuthService == null) return;

    try {
      await _biometricAuthService!.disableBiometric();
      _isBiometricEnabled = false;
      notifyListeners();
      debugPrint('✅ Biometric authentication disabled');
    } catch (e) {
      _errorMessage = 'Failed to disable biometric: $e';
      notifyListeners();
    }
  }

  Future<void> reloadUser() async {
    if (_currentUser != null) {
      try {
        await _currentUser!.reload();
        _currentUser = FirebaseAuth.instance.currentUser;
        notifyListeners();
      } catch (e) {
        // Catch the type cast error during reload, but still update user
        if (e.toString().contains('PigeonUserInfo') ||
            e.toString().contains('type cast')) {
          debugPrint(
              'Type cast error during reload, refreshing user anyway...');
          // Reload failed due to bug, but we can still get the current user
          _currentUser = FirebaseAuth.instance.currentUser;
          notifyListeners();
        } else {
          // Re-throw other errors
          rethrow;
        }
      }
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // === Face Authentication Methods ===

  /// Discover face recognition beacon (supports both MQTT and HTTP services)
  Future<bool> discoverFaceAuthBeacon() async {
    if (_faceAuthService == null && _faceAuthHttpService == null) {
      _faceAuthMessage = 'Face authentication service not available';
      return false;
    }

    _isLoading = true;
    _faceAuthMessage = 'Searching for face recognition system...';
    notifyListeners();

    try {
      FaceAuthBeacon? beacon;

      // Prefer HTTP service (new Docker backend)
      if (_faceAuthHttpService != null) {
        beacon = await _faceAuthHttpService!.discoverBeacon();
      } else if (_faceAuthService != null) {
        beacon = await _faceAuthService!.discoverBeacon();
      }

      _isLoading = false;

      if (beacon != null && beacon.isValid) {
        _discoveredBeacon = beacon;
        _faceAuthMessage = 'Face recognition system found';
        notifyListeners();
        return true;
      } else {
        _faceAuthMessage = 'Face recognition system not found';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _faceAuthMessage = 'Error discovering beacon: $e';
      notifyListeners();
      return false;
    }
  }

  /// Connect to face recognition broker/service
  Future<bool> connectToFaceBroker() async {
    if (_faceAuthService == null && _faceAuthHttpService == null) {
      _faceAuthMessage = 'Face authentication service not available';
      return false;
    }

    if (_discoveredBeacon == null) {
      _faceAuthMessage = 'No beacon discovered. Please scan first.';
      return false;
    }

    _isLoading = true;
    _faceAuthMessage = 'Connecting to face recognition system...';
    notifyListeners();

    try {
      bool connected = false;

      // Prefer HTTP service (new Docker backend)
      if (_faceAuthHttpService != null) {
        connected = await _faceAuthHttpService!.connectToFaceService(
          beacon: _discoveredBeacon,
        );
      } else if (_faceAuthService != null) {
        connected = await _faceAuthService!.connectToFaceBroker(
          beacon: _discoveredBeacon,
        );
      }

      _isLoading = false;

      if (connected) {
        _faceAuthMessage = 'Connected successfully';
        notifyListeners();
        return true;
      } else {
        _faceAuthMessage = 'Failed to connect';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _faceAuthMessage = 'Connection error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Authenticate using face recognition
  Future<bool> authenticateWithFace({String? userId}) async {
    if (_faceAuthService == null && _faceAuthHttpService == null) {
      _faceAuthMessage = 'Face authentication service not available';
      return false;
    }

    _isLoading = true;
    _faceAuthMessage = 'Requesting face scan...';
    notifyListeners();

    try {
      FaceAuthResponse? response;

      // Prefer HTTP service (new Docker backend)
      if (_faceAuthHttpService != null) {
        response = await _faceAuthHttpService!.requestFaceAuth(
          userId: userId,
          metadata: {
            'timestamp': DateTime.now().toIso8601String(),
            'app_version': '1.0.0',
          },
        );
      } else if (_faceAuthService != null) {
        response = await _faceAuthService!.requestFaceAuth(
          userId: userId,
          metadata: {
            'timestamp': DateTime.now().toIso8601String(),
            'app_version': '1.0.0',
          },
        );
      }

      _isLoading = false;

      if (response != null &&
          response.success &&
          response.recognizedUserName != null) {
        // Face recognized successfully
        final recognizedName = response.recognizedUserName!;
        _faceAuthMessage = 'Welcome, $recognizedName!';

        debugPrint('Face recognized: $recognizedName');
        debugPrint('User ID: ${response.recognizedUserId}');
        debugPrint('Confidence: ${response.confidence}');

        // Sign in to Firebase with the recognized user
        try {
          debugPrint('🔐 Signing in to Firebase as: $recognizedName');

          final credential = await _authService.signInWithFaceRecognition(
            recognizedName: recognizedName,
          );

          debugPrint(
              '🔍 signInWithFaceRecognition returned: ${credential != null}');
          debugPrint('🔍 credential.user: ${credential?.user?.email}');

          // Handle case where credential is null due to Pigeon errors but user is authenticated
          if (credential == null) {
            debugPrint('🔍 Credential is null, checking currentUser...');
            _currentUser = _authService.currentUser;
            if (_currentUser == null) {
              _faceAuthMessage = 'Failed to sign in to Firebase';
              notifyListeners();
              return false;
            }
            debugPrint(
                '✅ User authenticated via Pigeon workaround: ${_currentUser!.email}');
          } else {
            _currentUser = credential.user;
          }

          if (_currentUser != null) {
            // Reload user to get updated displayName from Firebase Auth
            try {
              await _currentUser!.reload();
              debugPrint('✅ User reload successful');
            } catch (e) {
              // Ignore Pigeon API errors (known Firebase bug)
              final errorStr = e.toString();
              if (errorStr.contains('Pigeon') ||
                  errorStr.contains('List<Object?>') ||
                  errorStr.contains('type cast') ||
                  errorStr.contains('not a subtype')) {
                debugPrint('⚠️ Pigeon API reload error (ignored): $e');
              } else {
                debugPrint('❌ User reload error (rethrowing): $e');
                rethrow;
              }
            }

            _currentUser =
                _authService.currentUser; // Get refreshed user instance

            // Force reload user data from Firestore (this updates _userModel with displayName)
            _userModel = await _authService.getUserData(_currentUser!.uid);

            // Additional debug to verify displayName
            debugPrint(
                '🔍 After reload - Firebase Auth displayName: ${_currentUser!.displayName}');
            debugPrint(
                '🔍 After reload - Firestore userModel displayName: ${_userModel?.displayName}');
            debugPrint(
                '🔍 After reload - userModel data: ${_userModel?.toJson()}');

            // If displayName is still missing, try one more reload
            if (_userModel?.displayName == null ||
                _userModel!.displayName!.isEmpty) {
              debugPrint(
                  '⚠️ DisplayName still missing, forcing another reload...');
              await Future.delayed(const Duration(milliseconds: 500));
              _userModel = await _authService.getUserData(_currentUser!.uid);
              debugPrint(
                  '🔍 Second attempt - userModel displayName: ${_userModel?.displayName}');
            }

            // Update last used timestamp for this face mapping
            await _authService.updateFaceMappingLastUsed(recognizedName);

            _faceAuthMessage =
                'Welcome, ${_currentUser!.displayName ?? recognizedName}!';
            debugPrint(
                '✅ Firebase sign-in successful for: ${_currentUser!.email}');
            debugPrint('✅ User display name: ${_currentUser!.displayName}');
            debugPrint('✅ User UID: ${_currentUser!.uid}');

            notifyListeners();
            return true;
          } else {
            _faceAuthMessage = 'Failed to sign in to Firebase';
            notifyListeners();
            return false;
          }
        } catch (e) {
          debugPrint('❌ Firebase sign-in error: $e');
          debugPrint('❌ Error type: ${e.runtimeType}');
          debugPrint('❌ Stack trace: ${StackTrace.current}');
          _faceAuthMessage = 'Authentication error: $e';
          notifyListeners();
          return false;
        }
      } else {
        _faceAuthMessage = response?.errorMessage ?? 'Face not recognized';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _faceAuthMessage = 'Authentication error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Cancel face authentication
  void cancelFaceAuth() {
    _faceAuthService?.cancelAuth();
    _faceAuthHttpService?.cancelAuth();
    _faceAuthStatus = FaceAuthStatus.idle;
    _faceAuthMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Reset face auth state
  void resetFaceAuth() {
    _faceAuthService?.reset();
    _faceAuthHttpService?.reset();
    _faceAuthStatus = FaceAuthStatus.idle;
    _discoveredBeacon = null;
    _faceAuthMessage = null;
    notifyListeners();
  }

  /// Update face auth message based on status
  void _updateFaceAuthMessage(FaceAuthStatus status) {
    switch (status) {
      case FaceAuthStatus.idle:
        _faceAuthMessage = null;
        break;
      case FaceAuthStatus.discovering:
        _faceAuthMessage = 'Searching for face recognition system...';
        break;
      case FaceAuthStatus.connecting:
        _faceAuthMessage = 'Connecting...';
        break;
      case FaceAuthStatus.requestingScan:
        _faceAuthMessage = 'Requesting face scan...';
        break;
      case FaceAuthStatus.initializing:
        _faceAuthMessage = 'Initializing camera system...';
        break;
      case FaceAuthStatus.scanning:
        _faceAuthMessage = 'Please look at the camera...';
        break;
      case FaceAuthStatus.processing:
        _faceAuthMessage = 'Processing...';
        break;
      case FaceAuthStatus.success:
        _faceAuthMessage = 'Authentication successful!';
        break;
      case FaceAuthStatus.failed:
        _faceAuthMessage = 'Face not recognized';
        break;
      case FaceAuthStatus.timeout:
        _faceAuthMessage = 'Request timed out';
        break;
      case FaceAuthStatus.error:
        _faceAuthMessage = 'An error occurred';
        break;
    }
  }

  // === Version 2 Features ===

  /// Get camera stream URL (Version 2)
  /// Returns the URL to view the live camera stream
  String? getCameraStreamUrl() {
    return _faceAuthHttpService?.getCameraFeedUrl();
  }

  /// Get RTSP stream URL (Version 2)
  /// Direct RTSP stream for media players
  String? getRtspStreamUrl() {
    return _faceAuthHttpService?.getRtspStreamUrl();
  }

  /// Get HLS stream URL (Version 2)
  /// HLS stream for web-based video players
  String? getHlsStreamUrl() {
    return _faceAuthHttpService?.getHlsStreamUrl();
  }

  /// Trigger door open (Version 2)
  /// Opens the door via n8n automation
  Future<bool> openDoor() async {
    if (_faceAuthHttpService == null) {
      _faceAuthMessage = 'Door control not available';
      return false;
    }

    try {
      final success = await _faceAuthHttpService!.openDoor();
      if (success) {
        _faceAuthMessage = 'Door opened successfully';
      } else {
        _faceAuthMessage = 'Failed to open door';
      }
      notifyListeners();
      return success;
    } catch (e) {
      _faceAuthMessage = 'Error opening door: $e';
      notifyListeners();
      return false;
    }
  }
}
