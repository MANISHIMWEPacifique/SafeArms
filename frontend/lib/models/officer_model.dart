// Officer Model
// Data model for police officer entities
//
// IMPORTANT: Officers are NOT system users
// - Officers CANNOT authenticate (no username/password)
// - Officers do NOT have roles (roles are for system users only)
// - Officers receive firearm custody assignments from Station Commanders
// - Officers are filtered by their assigned unit_id
//
// System users (Admin, HQ Commander, Station Commander, Investigator)
// are represented by the User model with authentication capabilities.

class OfficerModel {
  final String officerId;
  final String officerNumber;
  final String fullName;
  final String rank;
  final String unitId;
  final String? phoneNumber;
  final String? email;
  final DateTime? dateOfBirth;
  final DateTime? employmentDate;
  final bool firearmCertified;
  final DateTime? certificationDate;
  final DateTime? certificationExpiry;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OfficerModel({
    required this.officerId,
    required this.officerNumber,
    required this.fullName,
    required this.rank,
    required this.unitId,
    this.phoneNumber,
    this.email,
    this.dateOfBirth,
    this.employmentDate,
    required this.firearmCertified,
    this.certificationDate,
    this.certificationExpiry,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory OfficerModel.fromJson(Map<String, dynamic> json) {
    return OfficerModel(
      officerId: json['officer_id'] ?? '',
      officerNumber: json['officer_number'] ?? '',
      fullName: json['full_name'] ?? '',
      rank: json['rank'] ?? '',
      unitId: json['unit_id'] ?? '',
      phoneNumber: json['phone_number'],
      email: json['email'],
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.parse(json['date_of_birth'])
          : null,
      employmentDate: json['employment_date'] != null
          ? DateTime.parse(json['employment_date'])
          : null,
      firearmCertified: json['firearm_certified'] ?? false,
      certificationDate: json['certification_date'] != null
          ? DateTime.parse(json['certification_date'])
          : null,
      certificationExpiry: json['certification_expiry'] != null
          ? DateTime.parse(json['certification_expiry'])
          : null,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'officer_id': officerId,
      'officer_number': officerNumber,
      'full_name': fullName,
      'rank': rank,
      'unit_id': unitId,
      'phone_number': phoneNumber,
      'email': email,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'employment_date': employmentDate?.toIso8601String(),
      'firearm_certified': firearmCertified,
      'certification_date': certificationDate?.toIso8601String(),
      'certification_expiry': certificationExpiry?.toIso8601String(),
      'is_active': isActive,
    };
  }
}
