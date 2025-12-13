// Destruction Request Model
// Data model for destruction request entities

class DestructionRequestModel {
  final String destructionId;
  final String firearmId;
  final String unitId;
  final String requestedBy;
  final String destructionReason;
  final String? conditionDescription;
  final String? supportingDocuments;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewDate;
  final String? reviewNotes;
  final DateTime? actualDestructionDate;
  final String? destructionMethod;
  final String? witnesses;
  final DateTime? createdAt;

  DestructionRequestModel({
    required this.destructionId,
    required this.firearmId,
    required this.unitId,
    required this.requestedBy,
    required this.destructionReason,
    this.conditionDescription,
    this.supportingDocuments,
    required this.status,
    this.reviewedBy,
    this.reviewDate,
    this.reviewNotes,
    this.actualDestructionDate,
    this.destructionMethod,
    this.witnesses,
    this.createdAt,
  });

  factory DestructionRequestModel.fromJson(Map<String, dynamic> json) {
    return DestructionRequestModel(
      destructionId: json['destruction_id'] ?? '',
      firearmId: json['firearm_id'] ?? '',
      unitId: json['unit_id'] ?? '',
      requestedBy: json['requested_by'] ?? '',
      destructionReason: json['destruction_reason'] ?? '',
      conditionDescription: json['condition_description'],
      supportingDocuments: json['supporting_documents'],
      status: json['status'] ?? 'pending',
      reviewedBy: json['reviewed_by'],
      reviewDate: json['review_date'] != null
          ? DateTime.parse(json['review_date'])
          : null,
      reviewNotes: json['review_notes'],
      actualDestructionDate: json['actual_destruction_date'] != null
          ? DateTime.parse(json['actual_destruction_date'])
          : null,
      destructionMethod: json['destruction_method'],
      witnesses: json['witnesses'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'destruction_id': destructionId,
      'firearm_id': firearmId,
      'unit_id': unitId,
      'requested_by': requestedBy,
      'destruction_reason': destructionReason,
      'condition_description': conditionDescription,
      'supporting_documents': supportingDocuments,
      'status': status,
    };
  }
}
