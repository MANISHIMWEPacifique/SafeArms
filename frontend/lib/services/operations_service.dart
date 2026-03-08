// Operations Service - API calls for firearm lifecycle requests
// SafeArms Frontend - Loss Reports, Destruction, Procurement

import '../config/api_config.dart';
import 'api_client.dart';

class OperationsService {
  // ===== LOSS REPORTS =====

  Future<List<Map<String, dynamic>>> getLossReports({String? status}) async {
    try {
      var url = '${ApiConfig.reportsUrl}/loss';
      if (status != null && status != 'all') url += '?status=$status';
      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      final data = await ApiClient.post(
        '${ApiConfig.reportsUrl}/loss',
        body: {
          'firearm_id': firearmId,
          'loss_type': lossType,
          'loss_date': lossDate.toIso8601String(),
          'loss_location': lossLocation,
          'circumstances': circumstances,
          'officer_id': officerId,
          'police_case_number': policeCaseNumber,
          'loss_time': lossTime,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error creating loss report: $e');
    }
  }

  Future<bool> withdrawLossReport(String reportId) async {
    try {
      await ApiClient.delete('${ApiConfig.reportsUrl}/loss/$reportId');
      return true;
    } catch (e) {
      throw Exception('Error withdrawing loss report: $e');
    }
  }

  // ===== DESTRUCTION REQUESTS =====

  Future<List<Map<String, dynamic>>> getDestructionRequests(
      {String? status}) async {
    try {
      var url = '${ApiConfig.reportsUrl}/destruction';
      if (status != null && status != 'all') url += '?status=$status';
      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      final data = await ApiClient.post(
        '${ApiConfig.reportsUrl}/destruction',
        body: {
          'firearm_id': firearmId,
          'destruction_reason': destructionReason,
          'condition_description': conditionDescription,
          'priority': priority ?? 'medium',
          'maintenance_history': maintenanceHistory,
          'operational_history': operationalHistory,
          'witness_1': witness1,
          'witness_2': witness2,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error creating destruction request: $e');
    }
  }

  // ===== PROCUREMENT REQUESTS =====

  Future<List<Map<String, dynamic>>> getProcurementRequests(
      {String? status}) async {
    try {
      var url = '${ApiConfig.reportsUrl}/procurement';
      if (status != null && status != 'all') url += '?status=$status';
      final data = await ApiClient.get(url);
      return List<Map<String, dynamic>>.from(data['data'] ?? []);
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
      final data = await ApiClient.post(
        '${ApiConfig.reportsUrl}/procurement',
        body: {
          'firearm_type': firearmType,
          'manufacturer': manufacturer,
          'model': model,
          'caliber': caliber,
          'quantity': quantity,
          'estimated_cost': estimatedUnitCost,
          'justification': justification,
          'priority': priority ?? 'routine',
          'preferred_supplier': preferredSupplier,
          'operational_context': operationalContext,
        },
      );
      return data['data'];
    } catch (e) {
      throw Exception('Error creating procurement request: $e');
    }
  }

  // ===== STATISTICS =====

  Future<Map<String, dynamic>> getOperationsStats() async {
    try {
      final data =
          await ApiClient.get('${ApiConfig.baseUrl}/api/operations/stats');
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching operations stats: $e');
    }
  }
}
