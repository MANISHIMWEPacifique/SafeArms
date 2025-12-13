// Procurement Request Model
// Data model for procurement request entities

class ProcurementRequestModel {
  final String procurementId;
  final String unitId;
  final String requestedBy;
  final String firearmType;
  final int quantity;
  final String justification;
  final String priority;
  final double? estimatedCost;
  final String? preferredSupplier;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewDate;
  final String? reviewNotes;
  final DateTime? createdAt;

  ProcurementRequestModel({
    required this.procurementId,
    required this.unitId,
    required this.requestedBy,
    required this.firearmType,
    required this.quantity,
    required this.justification,
    required this.priority,
    this.estimatedCost,
    this.preferredSupplier,
    required this.status,
    this.reviewedBy,
    this.reviewDate,
    this.reviewNotes,
    this.createdAt,
  });

  factory ProcurementRequestModel.fromJson(Map<String, dynamic> json) {
    return ProcurementRequestModel(
      procurementId: json['procurement_id'] ?? '',
      unitId: json['unit_id'] ?? '',
      requestedBy: json['requested_by'] ?? '',
      firearmType: json['firearm_type'] ?? '',
      quantity: json['quantity'] ?? 0,
      justification: json['justification'] ?? '',
      priority: json['priority'] ?? 'routine',
      estimatedCost: json['estimated_cost'] != null
          ? (json['estimated_cost'] as num).toDouble()
          : null,
      preferredSupplier: json['preferred_supplier'],
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
      'procurement_id': procurementId,
      'unit_id': unitId,
      'requested_by': requestedBy,
      'firearm_type': firearmType,
      'quantity': quantity,
      'justification': justification,
      'priority': priority,
      'estimated_cost': estimatedCost,
      'preferred_supplier': preferredSupplier,
      'status': status,
    };
  }
}
