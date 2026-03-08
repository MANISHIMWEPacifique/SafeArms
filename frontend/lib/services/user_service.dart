// User Service - API calls for user management
// SafeArms Frontend

import '../config/api_config.dart';
import '../models/user_model.dart';
import 'api_client.dart';

class UserService {
  /// Build query string from optional filters
  String _buildQuery(Map<String, String?> params) {
    final filtered = params.entries
        .where(
            (e) => e.value != null && e.value!.isNotEmpty && e.value != 'all')
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return filtered.isEmpty ? '' : '?${filtered.join('&')}';
  }

  // Get all users (Admin only)
  Future<List<UserModel>> getAllUsers({
    String? role,
    String? status,
    String? unitId,
  }) async {
    try {
      final query = _buildQuery({
        'role': role,
        'status': status,
        'unit_id': unitId,
      });
      final data = await ApiClient.get('${ApiConfig.users}$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error fetching users: $e');
    }
  }

  // Get user by ID
  Future<UserModel> getUserById(String userId) async {
    try {
      final data = await ApiClient.get('${ApiConfig.users}/$userId');
      return UserModel.fromJson(data['data']);
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
      final data = await ApiClient.post(
        ApiConfig.users,
        body: {
          'username': username,
          'password': password,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'role': role,
          'unit_id': unitId,
          'is_active': isActive,
          'must_change_password': mustChangePassword,
        },
      );
      return UserModel.fromJson(data['data']);
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
      final Map<String, dynamic> updates = {};
      if (fullName != null) updates['full_name'] = fullName;
      if (email != null) updates['email'] = email;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (role != null) updates['role'] = role;
      if (unitId != null) updates['unit_id'] = unitId;
      if (isActive != null) updates['is_active'] = isActive;
      if (mustChangePassword != null) {
        updates['must_change_password'] = mustChangePassword;
      }

      final data = await ApiClient.put(
        '${ApiConfig.users}/$userId',
        body: updates,
      );
      return UserModel.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error updating user: $e');
    }
  }

  // Admin reset user password
  Future<bool> resetUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await ApiClient.post(
        '${ApiConfig.users}/$userId/reset-password',
        body: {'new_password': newPassword},
      );
      return true;
    } catch (e) {
      throw Exception('Error resetting password: $e');
    }
  }

  // Delete user (Admin only)
  Future<void> deleteUser(String userId) async {
    try {
      await ApiClient.delete('${ApiConfig.users}/$userId');
    } catch (e) {
      throw Exception('Error deleting user: $e');
    }
  }

  // Get user statistics (Admin only)
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final data = await ApiClient.get('${ApiConfig.users}/stats');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching user stats: $e');
    }
  }

  // Search users
  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final data = await ApiClient.get('${ApiConfig.users}/search?q=$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error searching users: $e');
    }
  }
}
