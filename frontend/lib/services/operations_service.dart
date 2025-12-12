// Operations Service - API calls for firearm lifecycle requests
// SafeArms Frontend - Loss Reports, Destruction, Procurement

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

class OperationsService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ===== LOSS REPORTS =====
  
  Future<List<Map<String, dynamic>>> getLossReports({String? status}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/loss-reports';
      if (status != null && status != 'all') {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url), headers: headers).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load loss reports');
      }
    } catch (e) {
      throw Exception('Error fetching loss reports: $e');
    }
  }

  Future<Map<String, dynamic>> createLossReport({
    required String firearmId,
    required String lossType,
    required DateTime lossDate,
    required String lossLocation,
    required String circumstances,
    String? officerId,
    String? policeCaseNumber,
    String? lossTime,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'firearm_id': firearmId,
        'loss_type': lossType,
        'loss_date': lossDate.toIso8601String(),
        'loss_location': lossLocation,
        'circumstances': circumstances,
        'officer_id': officerId,
        'police_case_number': policeCaseNumber,
        'loss_time': lossTime,
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/loss-reports'),
        headers: headers,
        body: body,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create loss report');
      }
    } catch (e) {
      throw Exception('Error creating loss report: $e');
    }
  }

  Future<bool> withdrawLossReport(String reportId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/loss-reports/$reportId'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error withdrawing loss report: $e');
    }
  }

  // ===== DESTRUCTION REQUESTS =====
  
  Future<List<Map<String, dynamic>>> getDestructionRequests({String? status}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/destruction-requests';
      if (status != null && status != 'all') {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url), headers: headers).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load destruction requests');
      }
    } catch (e) {
      throw Exception('Error fetching destruction requests: $e');
    }
  }

  Future<Map<String, dynamic>> createDestructionRequest({
    required String firearmId,
    required String destructionReason,
    required String conditionDescription,
    String? priority,
    String? maintenanceHistory,
    String? operationalHistory,
    String? witness1,
    String? witness2,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'firearm_id': firearmId,
        'destruction_reason': destructionReason,
        'condition_description': conditionDescription,
        'priority': priority ?? 'medium',
        'maintenance_history': maintenanceHistory,
        'operational_history': operationalHistory,
        'witness_1': witness1,
        'witness_2': witness2,
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/destruction-requests'),
        headers: headers,
        body: body,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create destruction request');
      }
    } catch (e) {
      throw Exception('Error creating destruction request: $e');
    }
  }

  // ===== PROCUREMENT REQUESTS =====
  
  Future<List<Map<String, dynamic>>> getProcurementRequests({String? status}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}/api/procurement-requests';
      if (status != null && status != 'all') {
        url += '?status=$status';
      }

      final response = await http.get(Uri.parse(url), headers: headers).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load procurement requests');
      }
    } catch (e) {
      throw Exception('Error fetching procurement requests: $e');
    }
  }

  Future<Map<String, dynamic>> createProcurementRequest({
    required String firearmType,
    required String manufacturer,
    required String model,
    required String caliber,
    required int quantity,
    required double estimatedUnitCost,
    required String justification,
    String? priority,
    String? preferredSupplier,
    String? operationalContext,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'firearm_type': firearmType,
        'manufacturer': manufacturer,
        'model': model,
        'caliber': caliber,
        'quantity': quantity,
        'estimated_unit_cost': estimatedUnitCost,
        'justification': justification,
        'priority': priority ?? 'routine',
        'preferred_supplier': preferredSupplier,
        'operational_context': operationalContext,
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/procurement-requests'),
        headers: headers,
        body: body,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to create procurement request');
      }
    } catch (e) {
      throw Exception('Error creating procurement request: $e');
    }
  }

  // ===== STATISTICS =====
  
  Future<Map<String, dynamic>> getOperationsStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/operations/stats'),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load operations stats');
      }
    } catch (e) {
      throw Exception('Error fetching operations stats: $e');
    }
  }
}
