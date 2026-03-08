// Custody Service - API calls for custody management
// SafeArms Frontend

import '../config/api_config.dart';
import 'api_client.dart';

class CustodyService {
  /// Build query string from optional filters
  String _buildQuery(Map<String, String?> params) {
    final filtered = params.entries
        .where(
            (e) => e.value != null && e.value!.isNotEmpty && e.value != 'all')
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return filtered.isEmpty ? '' : '?${filtered.join('&')}';
  }

  // Get all custody records with filters
  Future<List<Map<String, dynamic>>> getAllCustody({
    String? status,
    String? type,
    String? officerId,
    String? firearmId,
  }) async {
    try {
      final query = _buildQuery({
        'status': status,
        'custody_type': type,
        'officer_id': officerId,
        'firearm_id': firearmId,
      });
      final data = await ApiClient.get('${ApiConfig.custody}$query');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
    String? durationType,
    String? notes,
  }) async {
    try {
      final data = await ApiClient.post(
        '${ApiConfig.custody}/assign',
        body: {
          'firearm_id': firearmId,
          'officer_id': officerId,
          'custody_type': custodyType,
          'assignment_reason': assignmentReason,
          'expected_return_date': expectedReturnDate?.toIso8601String(),
          'duration_type': durationType,
          'notes': notes,
        },
      );
      return data['data'];
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
      final data = await ApiClient.post(
        '${ApiConfig.custody}/$custodyId/return',
        body: {
          'return_condition': returnCondition,
          'return_date': (returnDate ?? DateTime.now()).toIso8601String(),
          'notes': returnNotes,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error returning firearm: $e');
    }
  }

  // Get custody statistics
  Future<Map<String, dynamic>> getCustodyStats() async {
    try {
      final data = await ApiClient.get('${ApiConfig.custody}/stats');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching custody stats: $e');
    }
  }

  // Get custody for a specific unit
  Future<List<Map<String, dynamic>>> getUnitCustody({
    required String unitId,
    String? status,
    String? type,
  }) async {
    try {
      final query = _buildQuery({
        'status': status,
        'custody_type': type,
      });
      final data =
          await ApiClient.get('${ApiConfig.custody}/unit/$unitId$query');
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      String url;
      if (firearmId != null) {
        url = '${ApiConfig.custody}/firearm/$firearmId/history';
      } else if (officerId != null) {
        url = '${ApiConfig.custody}/officer/$officerId/history';
      } else {
        url = '${ApiConfig.custody}?status=returned';
      }

      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
    } catch (e) {
      throw Exception('Error fetching custody history: $e');
    }
  }

  // Get ML anomaly detection status
  Future<Map<String, dynamic>> getAnomalyStatus() async {
    try {
      final data = await ApiClient.get('${ApiConfig.custody}/anomalies/today');
      return data['data'] ?? {'count': 0, 'active': true};
    } catch (e) {
      return {'count': 0, 'active': true};
    }
  }
}
