// Custody Service - API calls for custody management
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

class CustodyService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Get all custody records with filters
  Future<List<Map<String, dynamic>>> getAllCustody({
    String? status,
    String? type,
    String? officerId,
    String? firearmId,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = ApiConfig.custody;

      List<String> queryParams = [];
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams.add('status=$status');
      }
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams.add('custody_type=$type');
      }
      if (officerId != null && officerId.isNotEmpty) {
        queryParams.add('officer_id=$officerId');
      }
      if (firearmId != null && firearmId.isNotEmpty) {
        queryParams.add('firearm_id=$firearmId');
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
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception(
            'Failed to load custody records: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching custody records: $e');
    }
  }

  // Assign custody
  Future<Map<String, dynamic>> assignCustody({
    required String firearmId,
    required String officerId,
    required String custodyType,
    required String assignmentReason,
    DateTime? expectedReturnDate,
    String? notes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'firearm_id': firearmId,
        'officer_id': officerId,
        'custody_type': custodyType,
        'assignment_reason': assignmentReason,
        'expected_return_date': expectedReturnDate?.toIso8601String(),
        'notes': notes,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.custody}/assign'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to assign custody');
      }
    } catch (e) {
      throw Exception('Error assigning custody: $e');
    }
  }

  // Return firearm
  Future<Map<String, dynamic>> returnFirearm({
    required String custodyId,
    required String returnCondition,
    DateTime? returnDate,
    String? returnNotes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'return_condition': returnCondition,
        'return_date': (returnDate ?? DateTime.now()).toIso8601String(),
        'return_notes': returnNotes,
      });

      final response = await http
          .post(
            Uri.parse('${ApiConfig.custody}/$custodyId/return'),
            headers: headers,
            body: body,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else {
        final error = json.decode(response.body);
        throw Exception(error['message'] ?? 'Failed to return firearm');
      }
    } catch (e) {
      throw Exception('Error returning firearm: $e');
    }
  }

  // Get custody statistics
  Future<Map<String, dynamic>> getCustodyStats() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.custody}/stats'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load custody stats');
      }
    } catch (e) {
      throw Exception('Error fetching custody stats: $e');
    }
  }

  // Get custody for a specific unit (Station Commander use)
  Future<List<Map<String, dynamic>>> getUnitCustody({
    required String unitId,
    String? status,
    String? type,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.custody}/unit/$unitId';

      List<String> queryParams = [];
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams.add('status=$status');
      }
      if (type != null && type.isNotEmpty && type != 'all') {
        queryParams.add('custody_type=$type');
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
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception(
            'Failed to load unit custody records: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unit custody: $e');
    }
  }

  // Get custody history
  Future<List<Map<String, dynamic>>> getCustodyHistory({
    String? officerId,
    String? firearmId,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.custody}/history';

      List<String> queryParams = [];
      if (officerId != null) queryParams.add('officer_id=$officerId');
      if (firearmId != null) queryParams.add('firearm_id=$firearmId');

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
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('Failed to load custody history');
      }
    } catch (e) {
      throw Exception('Error fetching custody history: $e');
    }
  }

  // Get ML anomaly detection status
  Future<Map<String, dynamic>> getAnomalyStatus() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.custody}/anomalies/today'),
            headers: headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {'count': 0, 'active': true};
      } else {
        return {'count': 0, 'active': true};
      }
    } catch (e) {
      return {'count': 0, 'active': true};
    }
  }
}
