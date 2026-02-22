// Authentication Service
// Handles login, OTP verification, and logout

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  // Storage keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _usernameKey = 'username';

  /// Login with username and password
  /// Returns username on success (OTP sent to email)
  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginUrl),
            headers: ApiConfig.defaultHeaders,
            body: json.encode({'username': username, 'password': password}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Store username for OTP verification
        await _storage.write(key: _usernameKey, value: username);
        return {
          'success': true,
          'message': data['message'] ?? 'OTP sent to your email',
          'username': username,
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Verify OTP code
  /// Returns user data and token on success
  Future<Map<String, dynamic>> verifyOtp(String username, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.verifyOtpUrl),
            headers: ApiConfig.defaultHeaders,
            body: json.encode({'username': username, 'otp': otp}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Backend returns data in 'data' wrapper
        final responseData = data['data'] ?? data;
        final token = responseData['token'];
        final user = responseData['user'];

        // Store token and user data
        await _storage.write(key: _tokenKey, value: token);
        await _storage.write(key: _userKey, value: json.encode(user));
        await _storage.delete(key: _usernameKey);

        return {'success': true, 'token': token, 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Invalid OTP code',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Resend OTP code
  Future<Map<String, dynamic>> resendOtp(String username) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.resendOtpUrl),
            headers: ApiConfig.defaultHeaders,
            body: json.encode({'username': username}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'New OTP sent to your email',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to resend OTP',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Get stored token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Get stored user data
  Future<Map<String, dynamic>?> getUserData() async {
    final userData = await _storage.read(key: _userKey);
    if (userData != null) {
      return json.decode(userData);
    }
    return null;
  }

  /// Get stored username (during OTP flow)
  Future<String?> getStoredUsername() async {
    return await _storage.read(key: _usernameKey);
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Confirm unit assignment (Station Commanders)
  Future<Map<String, dynamic>> confirmUnit(String unitId) async {
    final token = await getToken();
    if (token == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.confirmUnitUrl),
            headers: ApiConfig.authHeaders(token),
            body: json.encode({'unit_id': unitId}),
          )
          .timeout(ApiConfig.connectionTimeout);

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Update stored user data with unit_confirmed = true
        final userData = await getUserData();
        if (userData != null) {
          userData['unit_confirmed'] = true;
          await _storage.write(key: _userKey, value: json.encode(userData));
        }
        return {
          'success': true,
          'message': data['message'] ?? 'Unit confirmed'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to confirm unit',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Logout and clear stored data
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.logoutUrl),
          headers: ApiConfig.authHeaders(token),
        );
      }
    } catch (e) {
      // Continue with logout even if API call fails
    } finally {
      await _storage.deleteAll();
    }
  }
}
