// Officer Service - API calls for officer management
// SafeArms Frontend

import '../config/api_config.dart';
import '../models/officer_model.dart';
import 'api_client.dart';

class OfficerService {
  /// Build query string from optional filters
  String _buildQuery(Map<String, String?> params) {
    final filtered = params.entries
        .where(
            (e) => e.value != null && e.value!.isNotEmpty && e.value != 'all')
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return filtered.isEmpty ? '' : '?${filtered.join('&')}';
  }

  // Get all officers with filters
  Future<List<OfficerModel>> getAllOfficers({
    String? unitId,
    String? rank,
    String? activeStatus,
  }) async {
    try {
      final query = _buildQuery({
        'unit_id': unitId,
        'rank': rank,
        'is_active': activeStatus,
      });
      final data = await ApiClient.get('${ApiConfig.officers}$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => OfficerModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error fetching officers: $e');
    }
  }

  // Get officer by ID
  Future<OfficerModel> getOfficerById(String officerId) async {
    try {
      final data = await ApiClient.get('${ApiConfig.officers}/$officerId');
      return OfficerModel.fromJson(data['data']);
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
      final data = await ApiClient.post(
        ApiConfig.officers,
        body: {
          'officer_number': officerNumber,
          'full_name': fullName,
          'rank': rank,
          'unit_id': unitId,
          'phone_number': phoneNumber,
          'email': email,
          'date_of_birth': dateOfBirth?.toIso8601String(),
          'employment_date':
              (employmentDate ?? DateTime.now()).toIso8601String(),
          'photo_url': photoUrl,
          'is_active': isActive,
        },
      );
      return OfficerModel.fromJson(data['data']);
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
      final Map<String, dynamic> updateData = {};
      if (fullName != null) updateData['full_name'] = fullName;
      if (rank != null) updateData['rank'] = rank;
      if (unitId != null) updateData['unit_id'] = unitId;
      if (phoneNumber != null) updateData['phone_number'] = phoneNumber;
      if (email != null) updateData['email'] = email;
      if (dateOfBirth != null) {
        updateData['date_of_birth'] = dateOfBirth.toIso8601String();
      }
      if (photoUrl != null) updateData['photo_url'] = photoUrl;
      if (isActive != null) updateData['is_active'] = isActive;

      final data = await ApiClient.put(
        '${ApiConfig.officers}/$officerId',
        body: updateData,
      );
      return OfficerModel.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error updating officer: $e');
    }
  }

  // Delete officer
  Future<bool> deleteOfficer(String officerId) async {
    try {
      await ApiClient.delete('${ApiConfig.officers}/$officerId');
      return true;
    } catch (e) {
      throw Exception('Error deleting officer: $e');
    }
  }

  // Get officer statistics
  Future<Map<String, dynamic>> getOfficerStats({String? unitId}) async {
    try {
      var url = '${ApiConfig.officers}/stats';
      if (unitId != null && unitId.isNotEmpty) {
        url += '?unit_id=$unitId';
      }
      final data = await ApiClient.get(url);
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching officer stats: $e');
    }
  }

  // Search officers
  Future<List<OfficerModel>> searchOfficers(String query) async {
    try {
      final data = await ApiClient.get('${ApiConfig.officers}/search?q=$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => OfficerModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error searching officers: $e');
    }
  }

  // Get custody history for an officer
  Future<List<Map<String, dynamic>>> getCustodyHistory(String officerId) async {
    try {
      final data =
          await ApiClient.get('${ApiConfig.custody}?officer_id=$officerId');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching custody history: $e');
    }
  }

  // Get officers for a specific unit
  Future<List<OfficerModel>> getUnitOfficers({
    required String unitId,
    String? rank,
    String? activeStatus,
  }) async {
    try {
      final query = _buildQuery({
        'rank': rank,
        'is_active': activeStatus,
      });
      final data =
          await ApiClient.get('${ApiConfig.officers}/unit/$unitId$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => OfficerModel.fromJson(json)).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw Exception(
            'Access denied: You can only view officers from your unit');
      }
      throw Exception('Error fetching unit officers: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching unit officers: $e');
    }
  }
}
