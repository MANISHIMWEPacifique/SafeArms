// Ballistic Profile Model
// Data model for ballistic profile entities

class BallisticProfileModel {
  final String ballisticId;
  final String firearmId;
  final DateTime testDate;
  final String? testLocation;
  final String? riflingCharacteristics;
  final String? firingPinImpression;
  final String? ejectorMarks;
  final String? extractorMarks;
  final String? chamberMarks;
  final String? testConductedBy;
  final String? forensicLab;
  final String? testAmmunition;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BallisticProfileModel({
    required this.ballisticId,
    required this.firearmId,
    required this.testDate,
    this.testLocation,
    this.riflingCharacteristics,
    this.firingPinImpression,
    this.ejectorMarks,
    this.extractorMarks,
    this.chamberMarks,
    this.testConductedBy,
    this.forensicLab,
    this.testAmmunition,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory BallisticProfileModel.fromJson(Map<String, dynamic> json) {
    return BallisticProfileModel(
      ballisticId: json['ballistic_id'] ?? '',
      firearmId: json['firearm_id'] ?? '',
      testDate: json['test_date'] != null
          ? DateTime.parse(json['test_date'])
          : DateTime.now(),
      testLocation: json['test_location'],
      riflingCharacteristics: json['rifling_characteristics'],
      firingPinImpression: json['firing_pin_impression'],
      ejectorMarks: json['ejector_marks'],
      extractorMarks: json['extractor_marks'],
      chamberMarks: json['chamber_marks'],
      testConductedBy: json['test_conducted_by'],
      forensicLab: json['forensic_lab'],
      testAmmunition: json['test_ammunition'],
      notes: json['notes'],
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
      'ballistic_id': ballisticId,
      'firearm_id': firearmId,
      'test_date': testDate.toIso8601String(),
      'test_location': testLocation,
      'rifling_characteristics': riflingCharacteristics,
      'firing_pin_impression': firingPinImpression,
      'ejector_marks': ejectorMarks,
      'extractor_marks': extractorMarks,
      'chamber_marks': chamberMarks,
      'test_conducted_by': testConductedBy,
      'forensic_lab': forensicLab,
      'test_ammunition': testAmmunition,
      'notes': notes,
    };
  }
}
