// Firearm Service - API calls for firearms management
// SafeArms Frontend

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/firearm_model.dart';
import 'api_client.dart';

class FirearmService {
  /// Build query string from optional filters
  String _buildQuery(Map<String, String?> params) {
    final filtered = params.entries
        .where(
            (e) => e.value != null && e.value!.isNotEmpty && e.value != 'all')
        .map((e) => '${e.key}=${e.value}')
        .toList();
    return filtered.isEmpty ? '' : '?${filtered.join('&')}';
  }

  // Get all firearms with filters
  Future<List<FirearmModel>> getAllFirearms({
    String? status,
    String? type,
    String? unitId,
    String? manufacturer,
  }) async {
    try {
      final query = _buildQuery({
        'status': status,
        'type': type,
        'unit_id': unitId,
        'manufacturer': manufacturer,
      });
      final data = await ApiClient.get('${ApiConfig.firearms}$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => FirearmModel.fromJson(json)).toList();
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
      final data = await ApiClient.post(
        ApiConfig.firearms,
        body: {
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
        },
      );
      return FirearmModel.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error registering firearm: $e');
    }
  }

  // Get firearm statistics
  Future<Map<String, dynamic>> getFirearmStats({String? unitId}) async {
    try {
      var url = '${ApiConfig.firearms}/stats';
      if (unitId != null && unitId.isNotEmpty) {
        url += '?unit_id=$unitId';
      }
      final data = await ApiClient.get(url);
      return data['data'] ?? {};
    } catch (e) {
      throw Exception('Error fetching firearm stats: $e');
    }
  }

  // Search firearms
  Future<List<FirearmModel>> searchFirearms(String query) async {
    try {
      final data = await ApiClient.get('${ApiConfig.firearms}/search?q=$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => FirearmModel.fromJson(json)).toList();
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
      final Map<String, dynamic> updateData = updates ?? {};
      if (status != null) updateData['current_status'] = status;
      if (assignedUnitId != null) {
        updateData['assigned_unit_id'] = assignedUnitId;
      }

      final data = await ApiClient.put(
        '${ApiConfig.firearms}/$firearmId',
        body: updateData,
      );
      return FirearmModel.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error updating firearm: $e');
    }
  }

  // Upload or replace firearm image
  Future<FirearmModel> uploadFirearmImage({
    required String firearmId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final token = await ApiClient.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.firearms}/$firearmId/image'),
      );

      request.headers['Accept'] = 'application/json';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
      ));

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final responseBody = await streamedResponse.stream.bytesToString();
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        return FirearmModel.fromJson(decoded['data']);
      }

      final message = decoded['message']?.toString() ?? 'Image upload failed';
      throw ApiException(
          statusCode: streamedResponse.statusCode, message: message);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Error uploading firearm image: $e');
    }
  }

  Future<void> deleteFirearm(String firearmId) async {
    try {
      await ApiClient.post(
        '${ApiConfig.firearms}/$firearmId/delete',
        body: const {},
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw Exception(e.message);
      }
      throw Exception('Error deleting firearm: ${e.message}');
    } catch (e) {
      throw Exception('Error deleting firearm: $e');
    }
  }

  // Get firearm by ID
  Future<FirearmModel> getFirearmById(String firearmId) async {
    try {
      final data = await ApiClient.get('${ApiConfig.firearms}/$firearmId');
      return FirearmModel.fromJson(data['data']);
    } catch (e) {
      throw Exception('Error fetching firearm: $e');
    }
  }

  // Get firearms for a specific unit
  Future<List<FirearmModel>> getUnitFirearms({
    required String unitId,
    String? status,
    String? type,
  }) async {
    try {
      final query = _buildQuery({'status': status, 'type': type});
      final data =
          await ApiClient.get('${ApiConfig.firearms}/unit/$unitId$query');
      final List<dynamic> items = data['data'] ?? [];
      return items.map((json) => FirearmModel.fromJson(json)).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw Exception(
            'Access denied: You can only view firearms from your unit');
      }
      throw Exception('Error fetching unit firearms: ${e.message}');
    } catch (e) {
      throw Exception('Error fetching unit firearms: $e');
    }
  }
}
