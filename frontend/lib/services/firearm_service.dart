// Firearm Service - API calls for firearms management
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/firearm_model.dart';
import './auth_service.dart';

class FirearmService {
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

  // Get all firearms with filters
  Future<List<FirearmModel>> getAllFirearms({
    String? status,
    String? type,
    String? unitId,
    String? manufacturer,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = ApiConfig.firearms;

      List<String> queryParams = [];
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams.add('status=$status');
      }
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams.add('type=$type');
      }
      if (unitId != null && unitId.isNotEmpty && unitId != 'all') {
        queryParams.add('unit_id=$unitId');
      }
      if (manufacturer != null &&
          manufacturer.isNotEmpty &&
          manufacturer != 'all') {
        queryParams.add('manufacturer=$manufacturer');
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
        final List<dynamic> firearmsJson = data['data'] ?? [];
        return firearmsJson.map((json) => FirearmModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load firearms: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching firearms: $e');
    }
  }

  // Register new firearm (HQ level) with optional ballistic profile
  Future<FirearmModel> registerFirearm({
    required String serialNumber,
    required String manufacturer,
    required String model,
    required String firearmType,
    required String caliber,
    int? manufactureYear,
    required DateTime acquisitionDate,
    String? acquisitionSource,
    required String assignedUnitId,
    String? notes,
    Map<String, dynamic>? ballisticProfile,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'serial_number': serialNumber,
        'manufacturer': manufacturer,
        'model': model,
        'firearm_type': firearmType,
        'caliber': caliber,
        'manufacture_year': manufactureYear,
        'acquisition_date': acquisitionDate.toIso8601String(),
        'acquisition_source': acquisitionSource,
        'assigned_unit_id': assignedUnitId,
        'notes': notes,
        'registration_level': 'hq',
        if (ballisticProfile != null) 'ballistic_profile': ballisticProfile,
      });

      final response = await http
          .post(
            Uri.parse(ApiConfig.firearms),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return FirearmModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to register firearm');
      }
    } catch (e) {
      throw Exception('Error registering firearm: $e');
    }
  }

  // Get firearm statistics
  Future<Map<String, dynamic>> getFirearmStats({String? unitId}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.firearms}/stats';
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
        throw Exception('Failed to load firearm stats');
      }
    } catch (e) {
      throw Exception('Error fetching firearm stats: $e');
    }
  }

  // Search firearms
  Future<List<FirearmModel>> searchFirearms(String query) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.firearms}/search?q=$query'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> firearmsJson = data['data'] ?? [];
        return firearmsJson.map((json) => FirearmModel.fromJson(json)).toList();
      } else {
        throw Exception('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching firearms: $e');
    }
  }

  // Update firearm
  Future<FirearmModel> updateFirearm({
    required String firearmId,
    String? status,
    String? assignedUnitId,
    Map<String, dynamic>? updates,
  }) async {
    try {
      final headers = await _getHeaders();
      final Map<String, dynamic> updateData = updates ?? {};

      if (status != null) updateData['current_status'] = status;
      if (assignedUnitId != null)
        updateData['assigned_unit_id'] = assignedUnitId;

      final response = await http
          .put(
            Uri.parse('${ApiConfig.firearms}/$firearmId'),
            headers: headers,
            body: json.encode(updateData),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FirearmModel.fromJson(data['data']);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to update firearm');
      }
    } catch (e) {
      throw Exception('Error updating firearm: $e');
    }
  }

  // Get firearm by ID
  Future<FirearmModel> getFirearmById(String firearmId) async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.firearms}/$firearmId'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return FirearmModel.fromJson(data['data']);
      } else {
        throw Exception('Failed to load firearm: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching firearm: $e');
    }
  }

  // Get firearms for a specific unit (with unit-based access control)
  Future<List<FirearmModel>> getUnitFirearms({
    required String unitId,
    String? status,
    String? type,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.firearms}/unit/$unitId';

      List<String> queryParams = [];
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams.add('status=$status');
      }
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams.add('type=$type');
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
        final List<dynamic> firearmsJson = data['data'] ?? [];
        return firearmsJson.map((json) => FirearmModel.fromJson(json)).toList();
      } else if (response.statusCode == 403) {
        throw Exception(
            'Access denied: You can only view firearms from your unit');
      } else {
        throw Exception('Failed to load unit firearms: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unit firearms: $e');
    }
  }
}
