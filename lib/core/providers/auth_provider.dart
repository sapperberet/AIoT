import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;

  User? _currentUser;
  UserModel? _userModel;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({required AuthService authService})
      : _authService = authService {
    _init();
  }

  User? get currentUser => _currentUser;
  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

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
}
