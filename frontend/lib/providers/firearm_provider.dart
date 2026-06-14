// Firearm Provider - State management for firearms registry
// SafeArms Frontend

import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/firearm_model.dart';
import '../services/firearm_service.dart';
import '../utils/auth_error_utils.dart';

class FirearmProvider with ChangeNotifier {
  final FirearmService _firearmService;

  FirearmProvider({FirearmService? firearmService})
      : _firearmService = firearmService ?? FirearmService();

  @override
  void notifyListeners() {
    _filteredCache = null; // Invalidate cache on any state change.
    super.notifyListeners();
  }

  // State
  List<FirearmModel> _firearms = [];
  FirearmModel? _selectedFirearm;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};
  String? _activeUnitId;

  // View mode
  bool _isGridView = true;

  // Filters
  String _statusFilter = 'all';
  String _typeFilter = 'all';
  String _unitFilter = 'all';
  String _manufacturerFilter = 'all';
  String _searchQuery = '';

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 12; // For grid view

  // Getters
  List<FirearmModel> get firearms => _firearms;
  FirearmModel? get selectedFirearm => _selectedFirearm;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get stats => _stats;
  bool get isGridView => _isGridView;
  String? get activeUnitId => _activeUnitId;

  String get statusFilter => _statusFilter;
  String get typeFilter => _typeFilter;
  String get unitFilter => _unitFilter;
  String get manufacturerFilter => _manufacturerFilter;
  String get searchQuery => _searchQuery;

  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalItems => filteredCount;
  int get filteredCount => filteredFirearms.length;
  int get unfilteredCount => _firearms.length;
  int get totalPages =>
      filteredCount == 0 ? 0 : (filteredCount / _itemsPerPage).ceil();
  bool get hasActiveFilters =>
      _statusFilter != 'all' ||
      _typeFilter != 'all' ||
      _unitFilter != 'all' ||
      _manufacturerFilter != 'all' ||
      _searchQuery.trim().isNotEmpty;
  bool get isFilteredEmpty => _firearms.isNotEmpty && filteredCount == 0;
  bool get isInventoryEmpty => _firearms.isEmpty;
  int get pageStartItem =>
      filteredCount == 0 ? 0 : ((_currentPage - 1) * _itemsPerPage) + 1;
  int get pageEndItem {
    if (filteredCount == 0) return 0;
    final end = _currentPage * _itemsPerPage;
    return end > filteredCount ? filteredCount : end;
  }

  String get paginationSummary {
    if (filteredCount == 0) {
      return hasActiveFilters
          ? 'Showing 0 matching firearms'
          : 'Showing 0 firearms';
    }

    final suffix = hasActiveFilters ? ' matching firearms' : ' firearms';
    return 'Showing $pageStartItem-$pageEndItem of $filteredCount$suffix';
  }

  // Cached filtered list — invalidated by notifyListeners().
  List<FirearmModel>? _filteredCache;

  // Computed getters
  List<FirearmModel> get filteredFirearms {
    if (_filteredCache != null) return _filteredCache!;

    var filtered = _firearms.where((firearm) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = firearm.serialNumber.toLowerCase().contains(q) ||
            firearm.manufacturer.toLowerCase().contains(q) ||
            firearm.model.toLowerCase().contains(q) ||
            (firearm.assignedUnitId?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_statusFilter != 'all' && firearm.currentStatus != _statusFilter) {
        return false;
      }
      if (_typeFilter != 'all' && firearm.firearmType != _typeFilter) {
        return false;
      }
      if (_unitFilter != 'all' && firearm.assignedUnitId != _unitFilter) {
        return false;
      }
      if (_manufacturerFilter != 'all' &&
          firearm.manufacturer != _manufacturerFilter) {
        return false;
      }
      return true;
    }).toList();

    _filteredCache = filtered;
    return filtered;
  }

  List<FirearmModel> get paginatedFirearms {
    final filtered = filteredFirearms;
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filtered.length) return [];
    if (endIndex >= filtered.length) return filtered.sublist(startIndex);

    return filtered.sublist(startIndex, endIndex);
  }

  void _clampCurrentPage() {
    _filteredCache = null;
    final pages = totalPages;
    if (pages == 0) {
      _currentPage = 1;
      return;
    }
    if (_currentPage > pages) {
      _currentPage = pages;
    } else if (_currentPage < 1) {
      _currentPage = 1;
    }
  }

  Future<void> loadRegistry({String? unitId}) async {
    _activeUnitId = unitId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final listFuture = unitId == null || unitId.isEmpty
          ? _firearmService.getAllFirearms()
          : _firearmService.getAllFirearms(unitId: unitId);
      final statsFuture = _firearmService.getFirearmStats(unitId: unitId);
      final results = await Future.wait<dynamic>([listFuture, statsFuture]);

      _firearms = (results[0] as List<FirearmModel>);
      _stats = (results[1] as Map<String, dynamic>);
      _clampCurrentPage();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      if (isAuthFailureError(e)) {
        _stats = {};
      }
      _clampCurrentPage();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load all firearms
  Future<void> loadFirearms({String? unitId}) async {
    _activeUnitId = unitId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _firearms = await _firearmService.getAllFirearms(
        unitId: unitId,
      );
      _clampCurrentPage();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load firearms for a specific unit (with RBAC enforcement)
  Future<void> loadUnitFirearms(String unitId) async {
    _activeUnitId = unitId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _firearms = await _firearmService.getUnitFirearms(
        unitId: unitId,
      );
      _clampCurrentPage();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load firearm statistics
  Future<void> loadStats({String? unitId}) async {
    try {
      _stats = await _firearmService.getFirearmStats(
          unitId: unitId ?? _activeUnitId);
      notifyListeners();
    } catch (e) {
      if (isAuthFailureError(e)) {
        _stats = {};
        notifyListeners();
        return;
      }

      debugPrint('Error loading stats: $e');
    }
  }

  void _refreshStatsInBackground({String? unitId}) {
    unawaited(loadStats(unitId: unitId));
  }

  // Register new firearm with optional ballistic profile
  Future<bool> registerFirearm({
    required String serialNumber,
    required String manufacturer,
    required String model,
    required String firearmType,
    required String caliber,
    int? manufactureYear,
    required DateTime acquisitionDate,
    String? acquisitionSource,
    required String assignedUnitId,
    String? notes,
    Map<String, dynamic>? ballisticProfile,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newFirearm = await _firearmService.registerFirearm(
        serialNumber: serialNumber,
        manufacturer: manufacturer,
        model: model,
        firearmType: firearmType,
        caliber: caliber,
        manufactureYear: manufactureYear,
        acquisitionDate: acquisitionDate,
        acquisitionSource: acquisitionSource,
        assignedUnitId: assignedUnitId,
        notes: notes,
        ballisticProfile: ballisticProfile,
      );

      _firearms = [..._firearms, newFirearm];
      _clampCurrentPage();
      _isLoading = false;
      notifyListeners();

      _refreshStatsInBackground(unitId: _activeUnitId);

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update firearm
  Future<bool> updateFirearm({
    required String firearmId,
    String? status,
    String? assignedUnitId,
    Map<String, dynamic>? updates,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedFirearm = await _firearmService.updateFirearm(
        firearmId: firearmId,
        status: status,
        assignedUnitId: assignedUnitId,
        updates: updates,
      );

      final index = _firearms.indexWhere((f) => f.firearmId == firearmId);
      if (index != -1) {
        _firearms[index] = updatedFirearm;
      }
      if (_selectedFirearm?.firearmId == firearmId) {
        _selectedFirearm = updatedFirearm;
      }
      _clampCurrentPage();

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

  Future<bool> uploadFirearmImage({
    required String firearmId,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedFirearm = await _firearmService.uploadFirearmImage(
        firearmId: firearmId,
        imageBytes: imageBytes,
        fileName: fileName,
      );

      final index = _firearms.indexWhere((f) => f.firearmId == firearmId);
      if (index != -1) {
        _firearms[index] = updatedFirearm;
      }

      if (_selectedFirearm?.firearmId == firearmId) {
        _selectedFirearm = updatedFirearm;
      }
      _clampCurrentPage();

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

  Future<bool> deleteFirearm(String firearmId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _firearmService.deleteFirearm(firearmId);

      _firearms.removeWhere((f) => f.firearmId == firearmId);
      if (_selectedFirearm?.firearmId == firearmId) {
        _selectedFirearm = null;
      }
      _clampCurrentPage();

      _isLoading = false;
      notifyListeners();
      _refreshStatsInBackground(unitId: _activeUnitId);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Select firearm
  void selectFirearm(FirearmModel firearm) {
    _selectedFirearm = firearm;
    notifyListeners();
  }

  void clearSelectedFirearm() {
    _selectedFirearm = null;
    notifyListeners();
  }

  // Toggle view mode
  void toggleViewMode() {
    _isGridView = !_isGridView;
    _itemsPerPage =
        _isGridView ? 12 : 25; // Adjust items per page based on view
    _clampCurrentPage();
    notifyListeners();
  }

  // Set filters
  void setStatusFilter(String status) {
    _statusFilter = status;
    _currentPage = 1;
    _clampCurrentPage();
    notifyListeners();
  }

  void setTypeFilter(String type) {
    _typeFilter = type;
    _currentPage = 1;
    _clampCurrentPage();
    notifyListeners();
  }

  void setUnitFilter(String unitId) {
    _unitFilter = unitId;
    _currentPage = 1;
    _clampCurrentPage();
    notifyListeners();
  }

  void setManufacturerFilter(String manufacturer) {
    _manufacturerFilter = manufacturer;
    _currentPage = 1;
    _clampCurrentPage();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _currentPage = 1;
    _clampCurrentPage();
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = 'all';
    _typeFilter = 'all';
    _unitFilter = 'all';
    _manufacturerFilter = 'all';
    _searchQuery = '';
    _currentPage = 1;
    _clampCurrentPage();
    notifyListeners();
  }

  // Pagination
  void setPage(int page) {
    _currentPage = page;
    _clampCurrentPage();
    notifyListeners();
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
