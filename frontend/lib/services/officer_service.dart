// Officer Service - API calls for officer management
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/officer_model.dart';
import './auth_service.dart';

class OfficerService {
  final AuthService _authService = AuthService();

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

  // Get all officers with filters
  Future<List<OfficerModel>> getAllOfficers({
    String? unitId,
    String? rank,
    String? activeStatus,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = ApiConfig.officers;

      List<String> queryParams = [];
      if (unitId != null && unitId.isNotEmpty && unitId != 'all') {
        queryParams.add('unit_id=$unitId');
      }
      if (rank != null && rank.isNotEmpty && rank != 'all') {
        queryParams.add('rank=$rank');
      }
      if (activeStatus != null &&
          activeStatus.isNotEmpty &&
          activeStatus != 'all') {
        queryParams.add('is_active=$activeStatus');
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
        final List<dynamic> officersJson = data['data'] ?? [];
        return officersJson.map((json) => OfficerModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load officers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching officers: $e');
    }
  }

  // Get officer by ID
  Future<OfficerModel> getOfficerById(String officerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.officers}/$officerId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OfficerModel.fromJson(data['data']);
      } else {
        throw Exception('Failed to load officer: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching officer: $e');
    }
  }

  // Create new officer
  Future<OfficerModel> createOfficer({
    required String officerNumber,
    required String fullName,
    required String rank,
    required String unitId,
    required String phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    DateTime? employmentDate,
    String? photoUrl,
    bool isActive = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'officer_number': officerNumber,
        'full_name': fullName,
        'rank': rank,
        'unit_id': unitId,
        'phone_number': phoneNumber,
        'email': email,
        'date_of_birth': dateOfBirth?.toIso8601String(),
        'employment_date': (employmentDate ?? DateTime.now()).toIso8601String(),
        'photo_url': photoUrl,
        'is_active': isActive,
      });

      final response = await http
          .post(
            Uri.parse(ApiConfig.officers),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return OfficerModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create officer');
      }
    } catch (e) {
      throw Exception('Error creating officer: $e');
    }
  }

  // Update officer
  Future<OfficerModel> updateOfficer({
    required String officerId,
    String? fullName,
    String? rank,
    String? unitId,
    String? phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    String? photoUrl,
    bool? isActive,
  }) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> updateData = {};

      if (fullName != null) updateData['full_name'] = fullName;
      if (rank != null) updateData['rank'] = rank;
      if (unitId != null) updateData['unit_id'] = unitId;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (email != null) updateData['email'] = email;
      if (dateOfBirth != null)
        updateData['date_of_birth'] = dateOfBirth.toIso8601String();
      if (photoUrl != null) updateData['photo_url'] = photoUrl;
      if (isActive != null) updateData['is_active'] = isActive;

      final response = await http
          .put(
            Uri.parse('${ApiConfig.officers}/$officerId'),
            headers: headers,
            body: json.encode(updateData),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OfficerModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update officer');
      }
    } catch (e) {
      throw Exception('Error updating officer: $e');
    }
  }

  // Delete officer
  Future<bool> deleteOfficer(String officerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.officers}/$officerId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      throw Exception('Error deleting officer: $e');
    }
  }

  // Get officer statistics
  Future<Map<String, dynamic>> getOfficerStats({String? unitId}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.officers}/stats';
      if (unitId != null && unitId.isNotEmpty) {
        url += '?unit_id=$unitId';
      }

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load officer stats');
      }
    } catch (e) {
      throw Exception('Error fetching officer stats: $e');
    }
  }

  // Search officers
  Future<List<OfficerModel>> searchOfficers(String query) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.officers}/search?q=$query'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> officersJson = data['data'] ?? [];
        return officersJson.map((json) => OfficerModel.fromJson(json)).toList();
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching officers: $e');
    }
  }

  // Get custody history for an officer
  Future<List<Map<String, dynamic>>> getCustodyHistory(String officerId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.custody}?officer_id=$officerId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load custody history');
      }
    } catch (e) {
      throw Exception('Error fetching custody history: $e');
    }
  }

  // Get officers for a specific unit (with RBAC enforcement)
  Future<List<OfficerModel>> getUnitOfficers({
    required String unitId,
    String? rank,
    String? activeStatus,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.officers}/unit/$unitId';

      List<String> queryParams = [];
      if (rank != null && rank.isNotEmpty && rank != 'all') {
        queryParams.add('rank=$rank');
      }
      if (activeStatus != null &&
          activeStatus.isNotEmpty &&
          activeStatus != 'all') {
        queryParams.add('is_active=$activeStatus');
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
        final List<dynamic> officersJson = data['data'] ?? [];
        return officersJson.map((json) => OfficerModel.fromJson(json)).toList();
      } else if (response.statusCode == 403) {
        throw Exception(
            'Access denied: You can only view officers from your unit');
      } else {
        throw Exception('Failed to load unit officers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unit officers: $e');
    }
  }
}
