import '../config/api_config.dart';
import 'api_client.dart';

class OfficerVerificationService {
  String get _baseUrl => '${ApiConfig.apiBase}/officer-verification';

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

  Future<List<Map<String, dynamic>>> getOfficerDevices(String officerId) async {
    try {
      final response = await ApiClient.get('$_baseUrl/devices/officer/$officerId');
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

  Future<Map<String, dynamic>> revokeOfficerDevice(String deviceKey) async {
    try {
      final response = await ApiClient.patch(
        '$_baseUrl/devices/$deviceKey/revoke',
        body: <String, dynamic>{},
      );

      return Map<String, dynamic>.from(
          response['data'] as Map<String, dynamic>? ?? <String, dynamic>{});
    } catch (e) {
      throw Exception('Error revoking device: $e');
    }
  }
}
