// Unit Model
// Data model for police unit entities

class UnitModel {
  final String unitId;
  final String unitName;
  final String unitType;
  final String? location;
  final String? province;
  final String? district;
  final String? contactPhone;
  final String? contactEmail;
  final String? commanderName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UnitModel({
    required this.unitId,
    required this.unitName,
    required this.unitType,
    this.location,
    this.province,
    this.district,
    this.contactPhone,
    this.contactEmail,
    this.commanderName,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      unitId: json['unit_id'] ?? '',
      unitName: json['unit_name'] ?? '',
      unitType: json['unit_type'] ?? '',
      location: json['location'],
      province: json['province'],
      district: json['district'],
      contactPhone: json['contact_phone'],
      contactEmail: json['contact_email'],
      commanderName: json['commander_name'],
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
      'unit_id': unitId,
      'unit_name': unitName,
      'unit_type': unitType,
      'location': location,
      'province': province,
      'district': district,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'commander_name': commanderName,
      'is_active': isActive,
    };
  }
}
