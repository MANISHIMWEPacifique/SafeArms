class ApprovalRequest {
  const ApprovalRequest({
    required this.requestId,
    required this.custodyId,
    required this.challengeCode,
    required this.firearmSerial,
    required this.firearmModel,
    required this.requestedBy,
    required this.unitName,
    required this.reason,
    required this.requestedAt,
    required this.expiresAt,
    required this.requestType,
  });

  final String requestId;
  final String custodyId;
  final String challengeCode;
  final String firearmSerial;
  final String firearmModel;
  final String requestedBy;
  final String unitName;
  final String reason;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final String requestType;

  factory ApprovalRequest.fromApi(Map<String, dynamic> json) {
    final metadata = _asMap(json['metadata']);
    final firearmModel = _composeFirearmModel(
      manufacturer: json['manufacturer']?.toString(),
      model: json['model']?.toString(),
    );

    return ApprovalRequest(
      requestId: _stringValue(json['verification_id'], fallback: 'VRQ-UNKNOWN'),
      custodyId: _stringValue(json['custody_id'], fallback: 'CUS-UNKNOWN'),
      challengeCode: _stringValue(json['challenge_code']),
      firearmSerial: _stringValue(json['firearm_serial'], fallback: 'UNKNOWN'),
      firearmModel: firearmModel,
      requestedBy: _stringValue(
        json['requested_by_name'],
        fallback: _stringValue(
          json['requested_by'],
          fallback: 'Unknown Commander',
        ),
      ),
      unitName: _stringValue(json['unit_name'], fallback: 'Unknown Unit'),
      reason: _stringValue(
        metadata['assignment_reason'],
        fallback: _stringValue(
          json['reason'],
          fallback: 'Custody return verification',
        ),
      ),
      requestedAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      expiresAt:
          _parseDateTime(json['expires_at']) ??
          DateTime.now().add(const Duration(minutes: 5)),
      requestType: _stringValue(
        json['request_type'],
        fallback: 'custody_return',
      ),
    );
  }

  factory ApprovalRequest.sample() {
    return ApprovalRequest(
      requestId: 'VRQ-000047',
      custodyId: 'CUS-047',
      challengeCode: '482917',
      firearmSerial: 'RNP-SW-728144',
      firearmModel: 'Glock 17 Gen5',
      requestedBy: 'Commander Aline Niyonzima',
      unitName: 'Kigali Central Station',
      reason: 'Morning duty firearm issuance',
      requestedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 6)),
      requestType: 'custody_return',
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const {};
  }

  static String _composeFirearmModel({String? manufacturer, String? model}) {
    final cleanManufacturer = (manufacturer ?? '').trim();
    final cleanModel = (model ?? '').trim();

    if (cleanManufacturer.isNotEmpty && cleanModel.isNotEmpty) {
      return '$cleanManufacturer $cleanModel';
    }

    if (cleanModel.isNotEmpty) {
      return cleanModel;
    }

    if (cleanManufacturer.isNotEmpty) {
      return cleanManufacturer;
    }

    return 'Unknown Model';
  }
}
