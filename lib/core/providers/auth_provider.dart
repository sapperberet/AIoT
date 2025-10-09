import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/face_auth_service.dart';
import '../models/user_model.dart';
import '../models/face_auth_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final FaceAuthService? _faceAuthService;

  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  // Face authentication state
  FaceAuthStatus _faceAuthStatus = FaceAuthStatus.idle;
  FaceAuthBeacon? _discoveredBeacon;
  String? _faceAuthMessage;

  AuthProvider({
    required AuthService authService,
    FaceAuthService? faceAuthService,
  })  : _authService = authService,
        _faceAuthService = faceAuthService {
    _init();
  }

  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  // Face auth getters
  FaceAuthStatus get faceAuthStatus => _faceAuthStatus;
  FaceAuthBeacon? get discoveredBeacon => _discoveredBeacon;
  String? get faceAuthMessage => _faceAuthMessage;
  bool get isFaceAuthAvailable => _faceAuthService != null;

  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _currentUser = user;
      if (user != null) {
        _loadUserData();
      } else {
        _userModel = null;
      }
      notifyListeners();
    });

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
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      _userModel = await _authService.getUserData(_currentUser!.uid);
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
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
      // If error contains type cast, try getting user anyway (it may have succeeded)
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('type cast')) {
        debugPrint(
            'Type cast error caught, checking if login succeeded anyway...');
        _currentUser = _authService.currentUser;

        if (_currentUser != null) {
          // Login actually succeeded despite the error
          debugPrint('Login succeeded! User: ${_currentUser?.email}');
          await _loadUserData();
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

  Future<bool> register(
      String email, String password, String displayName) async {
    _isLoading = true;
    _errorMessage = null;
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
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // If error contains type cast, try getting user anyway (it may have succeeded)
      if (e.toString().contains('PigeonUserDetails') ||
          e.toString().contains('type cast')) {
        debugPrint(
            'Type cast error caught, checking if registration succeeded anyway...');
        _currentUser = _authService.currentUser;

        if (_currentUser != null) {
          // Registration actually succeeded despite the error
          debugPrint('Registration succeeded! User: ${_currentUser?.email}');
          await _loadUserData();
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

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _userModel = null;
    notifyListeners();
  }

  Future<void> sendEmailVerification() async {
    if (_currentUser != null && !_currentUser!.emailVerified) {
      await _currentUser!.sendEmailVerification();
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

  /// Discover face recognition beacon
  Future<bool> discoverFaceAuthBeacon() async {
    if (_faceAuthService == null) {
      _faceAuthMessage = 'Face authentication service not available';
      return false;
    }

    _isLoading = true;
    _faceAuthMessage = 'Searching for face recognition system...';
    notifyListeners();

    try {
      final beacon = await _faceAuthService!.discoverBeacon();

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

  /// Connect to face recognition broker
  Future<bool> connectToFaceBroker() async {
    if (_faceAuthService == null) {
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
      final connected = await _faceAuthService!.connectToFaceBroker(
        beacon: _discoveredBeacon,
      );

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
    if (_faceAuthService == null) {
      _faceAuthMessage = 'Face authentication service not available';
      return false;
    }

    _isLoading = true;
    _faceAuthMessage = 'Requesting face scan...';
    notifyListeners();

    try {
      final response = await _faceAuthService!.requestFaceAuth(
        userId: userId,
        metadata: {
          'timestamp': DateTime.now().toIso8601String(),
          'app_version': '1.0.0',
        },
      );

      _isLoading = false;

      if (response != null && response.success && response.isRecognized) {
        // Face recognized successfully
        _faceAuthMessage = 'Welcome, ${response.recognizedUserName ?? "User"}!';

        // Try to sign in with the recognized user
        // In a real implementation, you'd link face ID to Firebase user
        // For now, we'll just set a flag that face auth succeeded
        debugPrint('Face recognized: ${response.recognizedUserName}');
        debugPrint('User ID: ${response.recognizedUserId}');
        debugPrint('Confidence: ${response.confidence}');

        notifyListeners();
        return true;
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
    _faceAuthStatus = FaceAuthStatus.idle;
    _faceAuthMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Reset face auth state
  void resetFaceAuth() {
    _faceAuthService?.reset();
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
}
