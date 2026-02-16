// Unit Service
// API calls for unit management
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

class UnitService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all units
  Future<List<dynamic>> getAllUnits() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(ApiConfig.units),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? [];
      } else {
        throw Exception('Failed to load units: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching units: $e');
    }
  }

  // Get unit by ID
  Future<dynamic> getUnitById(String unitId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.units}/$unitId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        throw Exception('Failed to load unit: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unit: $e');
    }
  }

  // Create unit
  Future<dynamic> createUnit(Map<String, dynamic> unitData) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse(ApiConfig.units),
            headers: headers,
            body: json.encode(unitData),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create unit');
      }
    } catch (e) {
      throw Exception('Error creating unit: $e');
    }
  }

  // Update unit
  Future<dynamic> updateUnit(
      String unitId, Map<String, dynamic> updates) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .put(
            Uri.parse('${ApiConfig.units}/$unitId'),
            headers: headers,
            body: json.encode(updates),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update unit');
      }
    } catch (e) {
      throw Exception('Error updating unit: $e');
    }
  }

  // Delete unit (soft delete)
  Future<bool> deleteUnit(String unitId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.units}/$unitId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete unit');
      }
    } catch (e) {
      throw Exception('Error deleting unit: $e');
    }
  }
}
