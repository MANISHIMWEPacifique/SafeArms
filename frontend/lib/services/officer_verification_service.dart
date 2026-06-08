import '../config/api_config.dart';
import 'api_client.dart';

enum OfficerDeviceResolutionStatus {
  none,
  single,
  multiple,
}

class OfficerDeviceResolution {
  final OfficerDeviceResolutionStatus status;
  final String? deviceKey;
  final String? label;
  final String message;

  const OfficerDeviceResolution({
    required this.status,
    this.deviceKey,
    this.label,
    required this.message,
  });

  bool get hasSingleDevice => status == OfficerDeviceResolutionStatus.single;
  bool get hasMultipleDevices =>
      status == OfficerDeviceResolutionStatus.multiple;

  factory OfficerDeviceResolution.fromDevices(
    List<Map<String, dynamic>> devices,
  ) {
    if (devices.isEmpty) {
      return const OfficerDeviceResolution(
        status: OfficerDeviceResolutionStatus.none,
        message:
            'No active enrolled device found for this officer. Custody assignment can continue, but mobile verification request may not be delivered.',
      );
    }

    if (devices.length > 1) {
      return const OfficerDeviceResolution(
        status: OfficerDeviceResolutionStatus.multiple,
        message:
            'Multiple active devices detected. Remove extra devices before assignment.',
      );
    }

    final device = devices.first;
    final deviceKey = device['device_key']?.toString();
    if (deviceKey == null || deviceKey.trim().isEmpty) {
      return const OfficerDeviceResolution(
        status: OfficerDeviceResolutionStatus.none,
        message:
            'Active device enrollment is missing a device key. Remove and re-enroll this officer phone before assigning custody.',
      );
    }

    final deviceName = device['device_name']?.toString().trim() ?? '';
    final platform = device['platform']?.toString().toUpperCase() ?? 'UNKNOWN';
    final label = deviceName.isNotEmpty ? '$deviceName ($platform)' : deviceKey;

    return OfficerDeviceResolution(
      status: OfficerDeviceResolutionStatus.single,
      deviceKey: deviceKey,
      label: label,
      message: 'Active enrolled device resolved.',
    );
  }
}

class OfficerVerificationService {
  String get _baseUrl => '${ApiConfig.apiBase}/officer-verification';

  Future<Map<String, dynamic>> generateEnrollmentPin(
      String officerId, String unitId) async {
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

  Future<OfficerDeviceResolution> resolveAssignmentDevice(
    String officerId,
  ) async {
    final devices = await getOfficerDevices(officerId);
    return OfficerDeviceResolution.fromDevices(devices);
  }

  Future<List<Map<String, dynamic>>> getUnitOfficerDevices(
    String unitId, {
    bool includeRevoked = false,
  }) async {
    try {
      final response = await ApiClient.get(
        includeRevoked
            ? '$_baseUrl/devices/unit/$unitId?include_revoked=true'
            : '$_baseUrl/devices/unit/$unitId',
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
      throw Exception('Error loading unit officer devices: $e');
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
