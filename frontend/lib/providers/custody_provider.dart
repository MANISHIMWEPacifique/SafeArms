// Custody Provider - State management for custody operations
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../services/custody_service.dart';

class CustodyProvider with ChangeNotifier {
  final CustodyService _custodyService = CustodyService();

  // State
  List<Map<String, dynamic>> _custodyRecords = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _anomalyStatus = {'count': 0, 'active': true};

  // Filters
  String _statusFilter = 'active';
  String _typeFilter = 'all';
  String _searchQuery = '';

  // Getters
  List<Map<String, dynamic>> get custodyRecords => _custodyRecords;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get stats => _stats;
  Map<String, dynamic> get anomalyStatus => _anomalyStatus;

  String get statusFilter => _statusFilter;
  String get typeFilter => _typeFilter;
  String get searchQuery => _searchQuery;

  // Computed getters
  List<Map<String, dynamic>> get filteredCustodyRecords {
    var filtered = List<Map<String, dynamic>>.from(_custodyRecords);

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((record) {
        final query = _searchQuery.toLowerCase();
        final officerName =
            (record['officer_name'] ?? '').toString().toLowerCase();
        final firearmSerial =
            (record['firearm_serial'] ?? '').toString().toLowerCase();
        return officerName.contains(query) || firearmSerial.contains(query);
      }).toList();
    }

    // Apply filters
    if (_statusFilter != 'all') {
      filtered = filtered.where((r) => r['status'] == _statusFilter).toList();
    }

    if (_typeFilter != 'all') {
      filtered =
          filtered.where((r) => r['custody_type'] == _typeFilter).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> get activeCustodyRecords {
    return filteredCustodyRecords
        .where((r) => r['status'] == 'active')
        .toList();
  }

  // Load all custody records
  Future<void> loadCustody({
    String? status,
    String? type,
    String? officerId,
    String? firearmId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _custodyRecords = await _custodyService.getAllCustody(
        status: status ?? _statusFilter,
        type: type ?? (_typeFilter != 'all' ? _typeFilter : null),
        officerId: officerId,
        firearmId: firearmId,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load custody statistics
  Future<void> loadStats() async {
    try {
      _stats = await _custodyService.getCustodyStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  // Load anomaly detection status
  Future<void> loadAnomalyStatus() async {
    try {
      _anomalyStatus = await _custodyService.getAnomalyStatus();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading anomaly status: $e');
    }
  }

  // Assign custody
  Future<bool> assignCustody({
    required String firearmId,
    required String officerId,
    required String custodyType,
    required String assignmentReason,
    DateTime? expectedReturnDate,
    String? notes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _custodyService.assignCustody(
        firearmId: firearmId,
        officerId: officerId,
        custodyType: custodyType,
        assignmentReason: assignmentReason,
        expectedReturnDate: expectedReturnDate,
        notes: notes,
      );

      _isLoading = false;
      notifyListeners();

      // Reload data
      await loadCustody();
      await loadStats();
      await loadAnomalyStatus();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Return firearm
  Future<bool> returnFirearm({
    required String custodyId,
    required String returnCondition,
    DateTime? returnDate,
    String? returnNotes,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _custodyService.returnFirearm(
        custodyId: custodyId,
        returnCondition: returnCondition,
        returnDate: returnDate,
        returnNotes: returnNotes,
      );

      _isLoading = false;
      notifyListeners();

      // Reload data
      await loadCustody();
      await loadStats();

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load custody for specific unit (Station Commander use)
  Future<void> loadUnitCustody({required String unitId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _custodyRecords = await _custodyService.getUnitCustody(
        unitId: unitId,
        status: _statusFilter != 'all' ? _statusFilter : null,
        type: _typeFilter != 'all' ? _typeFilter : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set filters
  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setTypeFilter(String type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = 'active';
    _typeFilter = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
