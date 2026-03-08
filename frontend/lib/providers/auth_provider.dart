// Authentication Provider
// State management for authentication

import 'package:flutter/widgets.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  String? _errorMessage;
  Map<String, dynamic>? _currentUser;
  String? _token;
  String? _pendingUsername;

  // Getters
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get token => _token;
  String? get pendingUsername => _pendingUsername;
  String? get userRole => _currentUser?['role'];
  String? get userName => _currentUser?['full_name'];
  bool get requiresUnitConfirmation =>
      _currentUser?['role'] == 'station_commander' &&
      _currentUser?['unit_confirmed'] == false;

  bool get requiresPasswordChange =>
      _currentUser?['must_change_password'] == true;

  AuthProvider() {
    // Defer auth check until after the first frame to avoid double-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuthStatus());
  }

  /// Check if user is already authenticated on app start
  Future<void> _checkAuthStatus() async {
    _isAuthenticated = await _authService.isAuthenticated();
    if (_isAuthenticated) {
      _token = await _authService.getToken();
      _currentUser = await _authService.getUserData();
    }
    _isInitialized = true;
    notifyListeners();
  }

  /// Login with username and password
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(username, password);

      if (result['success']) {
        _pendingUsername = username;
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = result['message'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verify OTP code
  Future<bool> verifyOtp(String otp) async {
    if (_pendingUsername == null) {
      _errorMessage = 'No pending authentication';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.verifyOtp(_pendingUsername!, otp);

      if (result['success']) {
        _token = result['token'];
        _currentUser = result['user'];
        _isAuthenticated = true;
        _pendingUsername = null;
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = result['message'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Resend OTP code
  Future<bool> resendOtp() async {
    if (_pendingUsername == null) {
      _errorMessage = 'No pending authentication';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.resendOtp(_pendingUsername!);

      if (!result['success']) {
        _errorMessage = result['message'];
      }
      return result['success'];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();
      _isAuthenticated = false;
      _token = null;
      _currentUser = null;
      _pendingUsername = null;
      _errorMessage = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Confirm unit assignment
  Future<bool> confirmUnit() async {
    final unitId = _currentUser?['unit_id']?.toString();
    if (unitId == null) {
      _errorMessage = 'No unit assigned';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.confirmUnit(unitId);

      if (result['success']) {
        _currentUser?['unit_confirmed'] = true;
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = result['message'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Change password (for first login or password update)
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result =
          await _authService.changePassword(oldPassword, newPassword);

      if (result['success']) {
        // Update local user data
        _currentUser?['must_change_password'] = false;
        _errorMessage = null;
        return true;
      } else {
        _errorMessage = result['message'];
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
