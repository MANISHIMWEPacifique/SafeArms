// Anomaly Model
// Data model for anomaly detection entities

class AnomalyModel {
  final String anomalyId;
  final String custodyRecordId;
  final String firearmId;
  final String officerId;
  final String unitId;
  final double anomalyScore;
  final String anomalyType;
  final String detectionMethod;
  final String? modelId;
  final String severity;
  final double? confidenceLevel;
  final Map<String, dynamic>? contributingFactors;
  final Map<String, dynamic>? featureImportance;
  final String status;
  final String? investigatedBy;
  final String? investigationNotes;
  final DateTime? resolutionDate;
  final bool autoNotificationSent;
  final DateTime? notificationSentAt;
  final List<String>? notifiedUsers;
  final DateTime detectedAt;
  final DateTime? updatedAt;

  AnomalyModel({
    required this.anomalyId,
    required this.custodyRecordId,
    required this.firearmId,
    required this.officerId,
    required this.unitId,
    required this.anomalyScore,
    required this.anomalyType,
    required this.detectionMethod,
    this.modelId,
    required this.severity,
    this.confidenceLevel,
    this.contributingFactors,
    this.featureImportance,
    required this.status,
    this.investigatedBy,
    this.investigationNotes,
    this.resolutionDate,
    required this.autoNotificationSent,
    this.notificationSentAt,
    this.notifiedUsers,
    required this.detectedAt,
    this.updatedAt,
  });

  /// Safely parse a numeric value that may come as String from PostgreSQL DECIMAL columns
  static double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  factory AnomalyModel.fromJson(Map<String, dynamic> json) {
    return AnomalyModel(
      anomalyId: json['anomaly_id'] ?? '',
      custodyRecordId: json['custody_record_id'] ?? '',
      firearmId: json['firearm_id'] ?? '',
      officerId: json['officer_id'] ?? '',
      unitId: json['unit_id'] ?? '',
      anomalyScore: _parseDouble(json['anomaly_score']),
      anomalyType: json['anomaly_type'] ?? '',
      detectionMethod: json['detection_method'] ?? '',
      modelId: json['model_id'],
      severity: json['severity'] ?? 'medium',
      confidenceLevel: json['confidence_level'] != null
          ? _parseDouble(json['confidence_level'])
          : null,
      contributingFactors:
          json['contributing_factors'] as Map<String, dynamic>?,
      featureImportance: json['feature_importance'] as Map<String, dynamic>?,
      status: json['status'] ?? 'open',
      investigatedBy: json['investigated_by'],
      investigationNotes: json['investigation_notes'],
      resolutionDate: json['resolution_date'] != null
          ? DateTime.parse(json['resolution_date'])
          : null,
      autoNotificationSent: json['auto_notification_sent'] ?? false,
      notificationSentAt: json['notification_sent_at'] != null
          ? DateTime.parse(json['notification_sent_at'])
          : null,
      notifiedUsers: json['notified_users'] != null
          ? List<String>.from(json['notified_users'])
          : null,
      detectedAt: json['detected_at'] != null
          ? DateTime.parse(json['detected_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'anomaly_id': anomalyId,
      'custody_record_id': custodyRecordId,
      'firearm_id': firearmId,
      'officer_id': officerId,
      'unit_id': unitId,
      'anomaly_score': anomalyScore,
      'anomaly_type': anomalyType,
      'detection_method': detectionMethod,
      'model_id': modelId,
      'severity': severity,
      'confidence_level': confidenceLevel,
      'contributing_factors': contributingFactors,
      'feature_importance': featureImportance,
      'status': status,
      'investigated_by': investigatedBy,
      'investigation_notes': investigationNotes,
    };
  }
}
