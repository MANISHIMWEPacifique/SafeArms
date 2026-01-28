// Forensic Traceability Service
// API calls for chain-of-custody timeline, ballistic profiles, and access history
// SafeArms Frontend

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import './auth_service.dart';

/// Service for forensic traceability features
/// All views are READ-ONLY and present factual data only
class ForensicTraceabilityService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Get full forensic history for a firearm
  /// Includes custody chain, ballistic profile, and access history
  Future<Map<String, dynamic>> getFirearmFullHistory(
    String firearmId, {
    bool includeTimeline = true,
    int timelineLimit = 100,
  }) async {
    try {
      final headers = await _getHeaders();
      final url =
          '${ApiConfig.firearms}/$firearmId/full-history?include_timeline=$includeTimeline&timeline_limit=$timelineLimit';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else if (response.statusCode == 403) {
        // Access denied - return limited data structure
        return {
          'access_denied': true,
          'message': 'Your role does not have access to this data',
        };
      } else {
        throw Exception(
            'Failed to load firearm history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching firearm history: $e');
    }
  }

  /// Get custody chain timeline for a firearm
  /// Returns chronological list of custody events
  Future<Map<String, dynamic>> getCustodyTimeline(String firearmId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.custody}/firearm/$firearmId/timeline';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception(
            'Failed to load custody timeline: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching custody timeline: $e');
    }
  }

  /// Get unified timeline (custody + ballistic access events)
  Future<Map<String, dynamic>> getUnifiedTimeline(
    String firearmId, {
    List<String>? categories,
    int limit = 100,
  }) async {
    try {
      final headers = await _getHeaders();
      var url =
          '${ApiConfig.custody}/firearm/$firearmId/unified-timeline?limit=$limit';
      if (categories != null && categories.isNotEmpty) {
        url += '&categories=${categories.join(',')}';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception(
            'Failed to load unified timeline: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching unified timeline: $e');
    }
  }

  /// Get ballistic profile for a firearm
  /// Logs access for audit purposes
  Future<Map<String, dynamic>?> getBallisticProfile(
    String firearmId, {
    String? accessReason,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.ballistic}/firearm/$firearmId';
      if (accessReason != null) {
        url += '?reason=${Uri.encodeComponent(accessReason)}';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      } else if (response.statusCode == 403) {
        return {'access_denied': true};
      } else if (response.statusCode == 404) {
        return null; // No profile exists
      } else {
        throw Exception(
            'Failed to load ballistic profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching ballistic profile: $e');
    }
  }

  /// Get ballistic access history for a profile
  Future<List<Map<String, dynamic>>> getBallisticAccessHistory(
    String ballisticId, {
    int limit = 50,
  }) async {
    try {
      final headers = await _getHeaders();
      final url =
          '${ApiConfig.ballistic}/$ballisticId/access-history?limit=$limit';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else if (response.statusCode == 403) {
        return []; // No access
      } else {
        throw Exception(
            'Failed to load access history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching access history: $e');
    }
  }

  /// Get cross-unit transfers for a firearm
  Future<Map<String, dynamic>> getCrossUnitTransfers(String firearmId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.firearms}/$firearmId/cross-unit-transfers';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] ?? {};
      } else {
        throw Exception('Failed to load transfers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching transfers: $e');
    }
  }

  /// Check if firearm has pending anomalies requiring review
  Future<List<Map<String, dynamic>>> getFirearmAnomalies(
    String firearmId, {
    String? status,
  }) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.anomalies}?firearm_id=$firearmId';
      if (status != null) {
        url += '&status=$status';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
