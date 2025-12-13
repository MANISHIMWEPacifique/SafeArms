// Custody Record Model
// Data model for custody record entities

class CustodyRecordModel {
  final String custodyId;
  final String firearmId;
  final String officerId;
  final String unitId;
  final String custodyType;
  final DateTime issuedAt;
  final String issuedBy;
  final DateTime? expectedReturnDate;
  final DateTime? returnedAt;
  final String? returnedTo;
  final String? returnCondition;
  final String? assignmentReason;
  final String? notes;
  final int? custodyDurationSeconds;
  final int? issueHour;
  final int? issueDayOfWeek;
  final bool? isNightIssue;
  final bool? isWeekendIssue;
  final DateTime? createdAt;

  CustodyRecordModel({
    required this.custodyId,
    required this.firearmId,
    required this.officerId,
    required this.unitId,
    required this.custodyType,
    required this.issuedAt,
    required this.issuedBy,
    this.expectedReturnDate,
    this.returnedAt,
    this.returnedTo,
    this.returnCondition,
    this.assignmentReason,
    this.notes,
    this.custodyDurationSeconds,
    this.issueHour,
    this.issueDayOfWeek,
    this.isNightIssue,
    this.isWeekendIssue,
    this.createdAt,
  });

  factory CustodyRecordModel.fromJson(Map<String, dynamic> json) {
    return CustodyRecordModel(
      custodyId: json['custody_id'] ?? '',
      firearmId: json['firearm_id'] ?? '',
      officerId: json['officer_id'] ?? '',
      unitId: json['unit_id'] ?? '',
      custodyType: json['custody_type'] ?? '',
      issuedAt: json['issued_at'] != null
          ? DateTime.parse(json['issued_at'])
          : DateTime.now(),
      issuedBy: json['issued_by'] ?? '',
      expectedReturnDate: json['expected_return_date'] != null
          ? DateTime.parse(json['expected_return_date'])
          : null,
      returnedAt: json['returned_at'] != null
          ? DateTime.parse(json['returned_at'])
          : null,
      returnedTo: json['returned_to'],
      returnCondition: json['return_condition'],
      assignmentReason: json['assignment_reason'],
      notes: json['notes'],
      custodyDurationSeconds: json['custody_duration_seconds'],
      issueHour: json['issue_hour'],
      issueDayOfWeek: json['issue_day_of_week'],
      isNightIssue: json['is_night_issue'],
      isWeekendIssue: json['is_weekend_issue'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'custody_id': custodyId,
      'firearm_id': firearmId,
      'officer_id': officerId,
      'unit_id': unitId,
      'custody_type': custodyType,
      'issued_at': issuedAt.toIso8601String(),
      'issued_by': issuedBy,
      'expected_return_date': expectedReturnDate?.toIso8601String(),
      'assignment_reason': assignmentReason,
      'notes': notes,
    };
  }
}
