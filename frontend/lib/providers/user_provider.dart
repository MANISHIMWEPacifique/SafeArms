// User Provider - State management for user management
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();

  // State
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};

  // Filters
  String _roleFilter = 'all';
  String _statusFilter = 'all';
  String _unitFilter = 'all';
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;

  // Getters
  List<UserModel> get users => _users;
  UserModel? get selectedUser => _selectedUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get stats => _stats;

  String get roleFilter => _roleFilter;
  String get statusFilter => _statusFilter;
  String get unitFilter => _unitFilter;
  String get searchQuery => _searchQuery;

  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalItems => _totalItems;
  int get totalPages => (_totalItems / _itemsPerPage).ceil();

  // Computed getters for filtered/paginated users
  List<UserModel> get filteredUsers {
    var filtered = List<UserModel>.from(_users);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final query = _searchQuery.toLowerCase();
        return user.fullName.toLowerCase().contains(query) ||
            user.username.toLowerCase().contains(query) ||
            user.email.toLowerCase().contains(query) ||
            user.role.toLowerCase().contains(query);
      }).toList();
    }

    // Apply filters
    if (_roleFilter != 'all') {
      filtered = filtered.where((user) => user.role == _roleFilter).toList();
    }

    if (_statusFilter == 'active') {
      filtered = filtered.where((user) => user.isActive).toList();
    } else if (_statusFilter == 'inactive') {
      filtered = filtered.where((user) => !user.isActive).toList();
    }

    if (_unitFilter != 'all') {
      filtered = filtered.where((user) => user.unitId == _unitFilter).toList();
    }

    _totalItems = filtered.length;
    return filtered;
  }

  List<UserModel> get paginatedUsers {
    final filtered = filteredUsers;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filtered.length) return [];
    if (endIndex >= filtered.length) return filtered.sublist(startIndex);

    return filtered.sublist(startIndex, endIndex);
  }

  // Load all users
  Future<void> loadUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _users = await _userService.getAllUsers();
      _totalItems = _users.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load user statistics
  Future<void> loadStats() async {
    try {
      _stats = await _userService.getUserStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  // Create user
  Future<bool> createUser({
    required String username,
    required String password,
    required String fullName,
    required String email,
    required String phoneNumber,
    required String role,
    String? unitId,
    bool isActive = true,
    bool mustChangePassword = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newUser = await _userService.createUser(
        username: username,
        password: password,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        role: role,
        unitId: unitId,
        isActive: isActive,
        mustChangePassword: mustChangePassword,
      );

      _users.add(newUser);
      _totalItems = _users.length;
      _isLoading = false;
      notifyListeners();

      // Reload stats
      await loadStats();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update user
  Future<bool> updateUser({
    required String userId,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? role,
    String? unitId,
    bool? isActive,
    bool? mustChangePassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _userService.updateUser(
        userId: userId,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        role: role,
        unitId: unitId,
        isActive: isActive,
        mustChangePassword: mustChangePassword,
      );

      final index = _users.indexWhere((u) => u.userId == userId);
      if (index != -1) {
        _users[index] = updatedUser;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete user
  Future<bool> deleteUser(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _userService.deleteUser(userId);
      _users.removeWhere((u) => u.userId == userId);
      _totalItems = _users.length;
      _isLoading = false;
      notifyListeners();

      // Reload stats
      await loadStats();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Toggle user active status
  Future<bool> toggleUserStatus(String userId, bool isActive) async {
    try {
      final success = await updateUser(userId: userId, isActive: isActive);
      if (success) {
        await loadStats();
      }
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Select user for editing
  void selectUser(UserModel user) {
    _selectedUser = user;
    notifyListeners();
  }

  void clearSelectedUser() {
    _selectedUser = null;
    notifyListeners();
  }

  // Set filters
  void setRoleFilter(String role) {
    _roleFilter = role;
    _currentPage = 1; // Reset to first page
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    _currentPage = 1;
    notifyListeners();
  }

  void setUnitFilter(String unitId) {
    _unitFilter = unitId;
    _currentPage = 1;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    notifyListeners();
  }

  void clearFilters() {
    _roleFilter = 'all';
    _statusFilter = 'all';
    _unitFilter = 'all';
    _searchQuery = '';
    _currentPage = 1;
    notifyListeners();
  }

  // Pagination
  void setPage(int page) {
    if (page >= 1 && page <= totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  void nextPage() {
    if (_currentPage < totalPages) {
      _currentPage++;
      notifyListeners();
    }
  }

  void previousPage() {
    if (_currentPage > 1) {
      _currentPage--;
      notifyListeners();
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
