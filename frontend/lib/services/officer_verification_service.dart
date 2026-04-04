import '../config/api_config.dart';
import 'api_client.dart';

class OfficerVerificationService {
  String get _baseUrl => '${ApiConfig.apiBase}/officer-verification';

  Future<Map<String, dynamic>> generateEnrollmentPin(String officerId, String unitId) async {
    final response = await ApiClient.post(
      '${ApiConfig.apiBase}/enrollment/generate-pin',
      body: {
        'officer_id': officerId,
        'unit_id': unitId,
      },
    );

    if (response['success'] == true && response['data'] != null) {
      return response['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to parse pin response format.');
  }

  Future<Map<String, dynamic>> registerOfficerDevice({
    required String officerId,
    required String platform,
    String? deviceName,
    String? deviceFingerprint,
    String? appVersion,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await ApiClient.post(
        '$_baseUrl/devices/register',
        body: <String, dynamic>{
          'officer_id': officerId,
          'platform': platform,
          if (deviceName != null && deviceName.trim().isNotEmpty)
            'device_name': deviceName.trim(),
          if (deviceFingerprint != null && deviceFingerprint.trim().isNotEmpty)
            'device_fingerprint': deviceFingerprint.trim(),
          if (appVersion != null && appVersion.trim().isNotEmpty)
            'app_version': appVersion.trim(),
          if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        },
      );

      return Map<String, dynamic>.from(
          response['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
    } catch (e) {
      throw Exception('Error registering officer device: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOfficerDevices(
    String officerId, {
    bool includeRevoked = false,
  }) async {
    try {
      final response = await ApiClient.get(
        includeRevoked
            ? '$_baseUrl/devices/officer/$officerId?include_revoked=true'
            : '$_baseUrl/devices/officer/$officerId',
      );
      final rows = response['data'];
      if (rows is! List) {
        return <Map<String, dynamic>>[];
      }

      return rows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      throw Exception('Error loading officer devices: $e');
    }
  }

  Future<Map<String, dynamic>> removeOfficerDevice(String deviceKey) async {
    try {
      final response = await ApiClient.delete('$_baseUrl/devices/$deviceKey');

      return Map<String, dynamic>.from(
          response['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
    } catch (e) {
      throw Exception('Error removing device: $e');
    }
  }

  Future<Map<String, dynamic>> revokeOfficerDevice(String deviceKey) async {
    return removeOfficerDevice(deviceKey);
  }
}
