// Officer Provider - State management for officer registry
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../models/officer_model.dart';
import '../services/officer_service.dart';

class OfficerProvider with ChangeNotifier {
  final OfficerService _officerService = OfficerService();

  // State
  List<OfficerModel> _officers = [];
  OfficerModel? _selectedOfficer;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};

  // Filters
  String _unitFilter = 'all';
  String _rankFilter = 'all';
  String _activeFilter = 'all';
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 25;
  int _totalItems = 0;

  // Getters
  List<OfficerModel> get officers => _officers;
  OfficerModel? get selectedOfficer => _selectedOfficer;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get stats => _stats;
  
  String get unitFilter => _unitFilter;
  String get rankFilter => _rankFilter;
  String get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;
  
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalItems => _totalItems;
  int get totalPages => (_totalItems / _itemsPerPage).ceil();

  // Computed getters
  List<OfficerModel> get filteredOfficers {
    var filtered = List<OfficerModel>.from(_officers);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((officer) {
        final query = _searchQuery.toLowerCase();
        return officer.fullName.toLowerCase().contains(query) ||
               officer.officerNumber.toLowerCase().contains(query) ||
               officer.rank.toLowerCase().contains(query) ||
               (officer.phoneNumber?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply filters
    if (_unitFilter != 'all') {
      filtered = filtered.where((o) => o.unitId == _unitFilter).toList();
    }

    if (_rankFilter != 'all') {
      filtered = filtered.where((o) => o.rank == _rankFilter).toList();
    }

    if (_activeFilter != 'all') {
      final isActive = _activeFilter == 'active';
      filtered = filtered.where((o) => o.isActive == isActive).toList();
    }

    _totalItems = filtered.length;
    return filtered;
  }

  List<OfficerModel> get paginatedOfficers {
    final filtered = filteredOfficers;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    
    if (startIndex >= filtered.length) return [];
    if (endIndex >= filtered.length) return filtered.sublist(startIndex);
    
    return filtered.sublist(startIndex, endIndex);
  }

  // Load all officers
  Future<void> loadOfficers({String? unitId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _officers = await _officerService.getAllOfficers(
        unitId: unitId ?? (_unitFilter != 'all' ? _unitFilter : null),
        rank: _rankFilter != 'all' ? _rankFilter : null,
        activeStatus: _activeFilter != 'all' ? _activeFilter : null,
      );
      _totalItems = _officers.length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load officer statistics
  Future<void> loadStats({String? unitId}) async {
    try {
      _stats = await _officerService.getOfficerStats(unitId: unitId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  // Create new officer
  Future<bool> createOfficer({
    required String officerNumber,
    required String fullName,
    required String rank,
    required String unitId,
    required String phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    DateTime? employmentDate,
    String? photoUrl,
    bool isActive = true,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newOfficer = await _officerService.createOfficer(
        officerNumber: officerNumber,
        fullName: fullName,
        rank: rank,
        unitId: unitId,
        phoneNumber: phoneNumber,
        email: email,
        dateOfBirth: dateOfBirth,
        employmentDate: employmentDate,
        photoUrl: photoUrl,
        isActive: isActive,
      );

      _officers.add(newOfficer);
      _totalItems = _officers.length;
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

  // Update officer
  Future<bool> updateOfficer({
    required String officerId,
    String? fullName,
    String? rank,
    String? unitId,
    String? phoneNumber,
    String? email,
    DateTime? dateOfBirth,
    String? photoUrl,
    bool? isActive,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedOfficer = await _officerService.updateOfficer(
        officerId: officerId,
        fullName: fullName,
        rank: rank,
        unitId: unitId,
        phoneNumber: phoneNumber,
        email: email,
        dateOfBirth: dateOfBirth,
        photoUrl: photoUrl,
        isActive: isActive,
      );

      final index = _officers.indexWhere((o) => o.officerId == officerId);
      if (index != -1) {
        _officers[index] = updatedOfficer;
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

  // Delete officer
  Future<bool> deleteOfficer(String officerId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _officerService.deleteOfficer(officerId);
      
      if (success) {
        _officers.removeWhere((o) => o.officerId == officerId);
        _totalItems = _officers.length;
        await loadStats();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Select officer
  void selectOfficer(OfficerModel officer) {
    _selectedOfficer = officer;
    notifyListeners();
  }

  void clearSelectedOfficer() {
    _selectedOfficer = null;
    notifyListeners();
  }

  // Set filters
  void setUnitFilter(String unitId) {
    _unitFilter = unitId;
    _currentPage = 1;
    notifyListeners();
  }

  void setRankFilter(String rank) {
    _rankFilter = rank;
    _currentPage = 1;
    notifyListeners();
  }

  void setActiveFilter(String status) {
    _activeFilter = status;
    _currentPage = 1;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    notifyListeners();
  }

  void clearFilters() {
    _unitFilter = 'all';
    _rankFilter = 'all';
    _activeFilter = 'all';
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
