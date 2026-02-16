// User Service - API calls for user management
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model.dart';
import './auth_service.dart';

class UserService {
  final AuthService _authService = AuthService();

  // Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated. Please log in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all users (Admin only)
  Future<List<UserModel>> getAllUsers({
    String? role,
    String? status,
    String? unitId,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = ApiConfig.users;

      // Build query parameters
      List<String> queryParams = [];
      if (role != null && role.isNotEmpty && role != 'all') {
        queryParams.add('role=$role');
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams.add('status=$status');
      }
      if (unitId != null && unitId.isNotEmpty && unitId != 'all') {
        queryParams.add('unit_id=$unitId');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> usersJson = data['data'] ?? [];
        return usersJson.map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }

  // Get user by ID
  Future<UserModel> getUserById(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.users}/$userId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data['data']);
      } else {
        throw Exception('Failed to load user: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user: $e');
    }
  }

  // Create new user (Admin only)
  Future<UserModel> createUser({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String role,
    String? unitId,
    bool isActive = true,
    bool mustChangePassword = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'username': username,
        'password': password,
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'role': role,
        'unit_id': unitId,
        'is_active': isActive,
        'must_change_password': mustChangePassword,
      });

      final response = await http
          .post(
            Uri.parse(ApiConfig.users),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create user');
      }
    } catch (e) {
      throw Exception('Error creating user: $e');
    }
  }

  // Update user (Admin only)
  Future<UserModel> updateUser({
    required String userId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    String? unitId,
    bool? isActive,
    bool? mustChangePassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> updates = {};

      if (fullName != null) updates['full_name'] = fullName;
      if (email != null) updates['email'] = email;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (role != null) updates['role'] = role;
      if (unitId != null) updates['unit_id'] = unitId;
      if (isActive != null) updates['is_active'] = isActive;
      if (mustChangePassword != null)
        updates['must_change_password'] = mustChangePassword;

      final response = await http
          .put(
            Uri.parse('${ApiConfig.users}/$userId'),
            headers: headers,
            body: json.encode(updates),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update user');
      }
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  // Delete user (Admin only)
  Future<void> deleteUser(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.users}/$userId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode != 200 && response.statusCode != 204) {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete user');
      }
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }

  // Get user statistics (Admin only)
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.users}/stats'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load user stats');
      }
    } catch (e) {
      throw Exception('Error fetching user stats: $e');
    }
  }

  // Search users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.users}/search?q=$query'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> usersJson = data['data'] ?? [];
        return usersJson.map((json) => UserModel.fromJson(json)).toList();
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching users: $e');
    }
  }
}
