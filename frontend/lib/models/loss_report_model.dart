// Loss Report Model
// Data model for loss report entities

class LossReportModel {
  final String lossId;
  final String firearmId;
  final String unitId;
  final String reportedBy;
  final String? officerId;
  final String lossType;
  final DateTime lossDate;
  final String? lossLocation;
  final String circumstances;
  final String? policeCaseNumber;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewDate;
  final String? reviewNotes;
  final DateTime? createdAt;

  LossReportModel({
    required this.lossId,
    required this.firearmId,
    required this.unitId,
    required this.reportedBy,
    this.officerId,
    required this.lossType,
    required this.lossDate,
    this.lossLocation,
    required this.circumstances,
    this.policeCaseNumber,
    required this.status,
    this.reviewedBy,
    this.reviewDate,
    this.reviewNotes,
    this.createdAt,
  });

  factory LossReportModel.fromJson(Map<String, dynamic> json) {
    return LossReportModel(
      lossId: json['loss_id'] ?? '',
      firearmId: json['firearm_id'] ?? '',
      unitId: json['unit_id'] ?? '',
      reportedBy: json['reported_by'] ?? '',
      officerId: json['officer_id'],
      lossType: json['loss_type'] ?? '',
      lossDate: json['loss_date'] != null
          ? DateTime.parse(json['loss_date'])
          : DateTime.now(),
      lossLocation: json['loss_location'],
      circumstances: json['circumstances'] ?? '',
      policeCaseNumber: json['police_case_number'],
      status: json['status'] ?? 'pending',
      reviewedBy: json['reviewed_by'],
      reviewDate: json['review_date'] != null
          ? DateTime.parse(json['review_date'])
          : null,
      reviewNotes: json['review_notes'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loss_id': lossId,
      'firearm_id': firearmId,
      'unit_id': unitId,
      'reported_by': reportedBy,
      'officer_id': officerId,
      'loss_type': lossType,
      'loss_date': lossDate.toIso8601String(),
      'loss_location': lossLocation,
      'circumstances': circumstances,
      'police_case_number': policeCaseNumber,
      'status': status,
    };
  }
}
