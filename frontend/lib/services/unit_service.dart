// Unit Service
// API calls for unit management

import '../config/api_config.dart';
import 'api_client.dart';

class UnitService {
  // Get all units
  Future<List<dynamic>> getAllUnits() async {
    try {
      final data = await ApiClient.get(ApiConfig.units);
      return data['data'] ?? [];
    } catch (e) {
      throw Exception('Error fetching units: $e');
    }
  }

  // Get unit by ID
  Future<dynamic> getUnitById(String unitId) async {
    try {
      final data = await ApiClient.get('${ApiConfig.units}/$unitId');
      return data['data'];
    } catch (e) {
      throw Exception('Error fetching unit: $e');
    }
  }

  // Create unit
  Future<dynamic> createUnit(Map<String, dynamic> unitData) async {
    try {
      final data = await ApiClient.post(ApiConfig.units, body: unitData);
      return data['data'];
    } catch (e) {
      throw Exception('Error creating unit: $e');
    }
  }

  // Update unit
  Future<dynamic> updateUnit(
      String unitId, Map<String, dynamic> updates) async {
    try {
      final data =
          await ApiClient.put('${ApiConfig.units}/$unitId', body: updates);
      return data['data'];
    } catch (e) {
      throw Exception('Error updating unit: $e');
    }
  }

  // Delete unit
  Future<bool> deleteUnit(String unitId) async {
    try {
      await ApiClient.delete('${ApiConfig.units}/$unitId');
      return true;
    } catch (e) {
      throw Exception('Error deleting unit: $e');
    }
  }
}
