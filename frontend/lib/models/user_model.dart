// User Model
// Data model for user entities

class UserModel {
  final String userId;
  final String username;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String role;
  final String? unitId;
  final bool isActive;
  final bool mustChangePassword;
  final bool unitConfirmed;
  final DateTime? lastLogin;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.unitId,
    required this.isActive,
    required this.mustChangePassword,
    required this.unitConfirmed,
    this.lastLogin,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phone_number'],
      role: json['role'] ?? '',
      unitId: json['unit_id'],
      isActive: json['is_active'] ?? true,
      mustChangePassword: json['must_change_password'] ?? false,
      unitConfirmed: json['unit_confirmed'] ?? false,
      lastLogin: json['last_login'] != null
          ? DateTime.parse(json['last_login'])
          : null,
      createdBy: json['created_by'],
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
      'user_id': userId,
      'username': username,
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'role': role,
      'unit_id': unitId,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
      'unit_confirmed': unitConfirmed,
    };
  }
}
