// Forensic Traceability Service
// API calls for chain-of-custody timeline, ballistic profiles, and access history
// SafeArms Frontend

import '../config/api_config.dart';
import 'api_client.dart';

/// Service for forensic traceability features
/// All views are READ-ONLY and present factual data only
class ForensicTraceabilityService {
  /// Get full forensic history for a firearm
  Future<Map<String, dynamic>> getFirearmFullHistory(
    String firearmId, {
    bool includeTimeline = true,
    int timelineLimit = 100,
  }) async {
    try {
      final url =
          '${ApiConfig.firearms}/$firearmId/full-history?include_timeline=$includeTimeline&timeline_limit=$timelineLimit';
      final data = await ApiClient.get(url);
      return data['data'] ?? {};
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        return {
          'access_denied': true,
          'message': 'Your role does not have access to this data',
        };
      }
      throw Exception('Failed to load firearm history: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching firearm history: $e');
    }
  }

  /// Get custody chain timeline for a firearm
  Future<Map<String, dynamic>> getCustodyTimeline(String firearmId) async {
    try {
      final data = await ApiClient.get(
          '${ApiConfig.custody}/firearm/$firearmId/timeline');
      return data['data'] ?? {};
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
      var url =
          '${ApiConfig.custody}/firearm/$firearmId/unified-timeline?limit=$limit';
      if (categories != null && categories.isNotEmpty) {
        url += '&categories=${categories.join(',')}';
      }
      final data = await ApiClient.get(url);
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching unified timeline: $e');
    }
  }

  /// Get ballistic profile for a firearm
  Future<Map<String, dynamic>?> getBallisticProfile(
    String firearmId, {
    String? accessReason,
  }) async {
    try {
      var url = '${ApiConfig.ballistic}/firearm/$firearmId';
      if (accessReason != null) {
        url += '?reason=${Uri.encodeComponent(accessReason)}';
      }
      final data = await ApiClient.get(url);
      return data['data'];
    } on ApiException catch (e) {
      if (e.statusCode == 403) return {'access_denied': true};
      if (e.statusCode == 404) return null;
      throw Exception('Failed to load ballistic profile: ${e.message}');
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
      final data = await ApiClient.get(
          '${ApiConfig.ballistic}/$ballisticId/access-history?limit=$limit');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } on ApiException catch (e) {
      if (e.statusCode == 403) return [];
      throw Exception('Failed to load access history: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching access history: $e');
    }
  }

  /// Get cross-unit transfers for a firearm
  Future<Map<String, dynamic>> getCrossUnitTransfers(String firearmId) async {
    try {
      final data = await ApiClient.get(
          '${ApiConfig.firearms}/$firearmId/cross-unit-transfers');
      return data['data'] ?? {};
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
      var url = '${ApiConfig.anomalies}?firearm_id=$firearmId';
      if (status != null) url += '&status=$status';
      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      return [];
    }
  }
}
