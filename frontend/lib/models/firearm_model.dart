// Firearm Model
// Data model for firearm entities

class FirearmModel {
  final String firearmId;
  final String serialNumber;
  final String manufacturer;
  final String model;
  final String firearmType;
  final String? caliber;
  final int? manufactureYear;
  final DateTime acquisitionDate;
  final String? acquisitionSource;
  final String registrationLevel;
  final String registeredBy;
  final String? assignedUnitId;
  final String? assignedUnitName; // User-friendly unit name from backend join
  final String currentStatus;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FirearmModel({
    required this.firearmId,
    required this.serialNumber,
    required this.manufacturer,
    required this.model,
    required this.firearmType,
    this.caliber,
    this.manufactureYear,
    required this.acquisitionDate,
    this.acquisitionSource,
    required this.registrationLevel,
    required this.registeredBy,
    this.assignedUnitId,
    this.assignedUnitName,
    required this.currentStatus,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  /// Returns user-friendly unit display name (prefers unit_name over unit_id)
  String get unitDisplayName {
    if (assignedUnitName != null && assignedUnitName!.isNotEmpty) {
      return assignedUnitName!;
    }
    if (assignedUnitId != null && assignedUnitId!.isNotEmpty) {
      // Now we have user-friendly IDs like UNIT-NYA, so display them directly
      return assignedUnitId!;
    }
    return 'Unassigned';
  }

  factory FirearmModel.fromJson(Map<String, dynamic> json) {
    return FirearmModel(
      firearmId: json['firearm_id'] ?? '',
      serialNumber: json['serial_number'] ?? '',
      manufacturer: json['manufacturer'] ?? '',
      model: json['model'] ?? '',
      firearmType: json['firearm_type'] ?? '',
      caliber: json['caliber'],
      manufactureYear: json['manufacture_year'],
      acquisitionDate: json['acquisition_date'] != null
          ? DateTime.parse(json['acquisition_date'])
          : DateTime.now(),
      acquisitionSource: json['acquisition_source'],
      registrationLevel: json['registration_level'] ?? 'unit',
      registeredBy: json['registered_by'] ?? '',
      assignedUnitId: json['assigned_unit_id'],
      assignedUnitName: json['unit_name'], // From backend LEFT JOIN
      currentStatus: json['current_status'] ?? 'available',
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
      'firearm_id': firearmId,
      'serial_number': serialNumber,
      'manufacturer': manufacturer,
      'model': model,
      'firearm_type': firearmType,
      'caliber': caliber,
      'manufacture_year': manufactureYear,
      'acquisition_date': acquisitionDate.toIso8601String(),
      'acquisition_source': acquisitionSource,
      'registration_level': registrationLevel,
      'registered_by': registeredBy,
      'assigned_unit_id': assignedUnitId,
      'current_status': currentStatus,
      'is_active': isActive,
    };
  }
}
