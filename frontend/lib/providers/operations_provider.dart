// Operations Provider - State management for lifecycle requests
// SafeArms Frontend

import 'package:flutter/foundation.dart';
import '../services/operations_service.dart';

class OperationsProvider with ChangeNotifier {
  final OperationsService _operationsService = OperationsService();

  // State
  List<Map<String, dynamic>> _lossReports = [];
  List<Map<String, dynamic>> _destructionRequests = [];
  List<Map<String, dynamic>> _procurementRequests = [];
  Map<String, dynamic> _stats = {};
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Filters
  String _lossReportsFilter = 'all';
  String _destructionFilter = 'all';
  String _procurementFilter = 'all';

  // Getters
  List<Map<String, dynamic>> get lossReports => _lossReports;
  List<Map<String, dynamic>> get destructionRequests => _destructionRequests;
  List<Map<String, dynamic>> get procurementRequests => _procurementRequests;
  Map<String, dynamic> get stats => _stats;
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  
  String get lossReportsFilter => _lossReportsFilter;
  String get destructionFilter => _destructionFilter;
  String get procurementFilter => _procurementFilter;

  // Load loss reports
  Future<void> loadLossReports() async {
    _isLoading = true;
    notifyListeners();

    try {
      _lossReports = await _operationsService.getLossReports(
        status: _lossReportsFilter != 'all' ? _lossReportsFilter : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create loss report
  Future<bool> createLossReport({
    required String firearmId,
    required String lossType,
    required DateTime lossDate,
    required String lossLocation,
    required String circumstances,
    String? officerId,
    String? policeCaseNumber,
    String? lossTime,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _operationsService.createLossReport(
        firearmId: firearmId,
        lossType: lossType,
        lossDate: lossDate,
        lossLocation: lossLocation,
        circumstances: circumstances,
        officerId: officerId,
        policeCaseNumber: policeCaseNumber,
        lossTime: lossTime,
      );

      _successMessage = 'Loss report submitted successfully';
      _isLoading = false;
      notifyListeners();
      
      await loadLossReports();
      await loadStats();
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Withdraw loss report
  Future<bool> withdrawLossReport(String reportId) async {
    try {
      final success = await _operationsService.withdrawLossReport(reportId);
      if (success) {
        _successMessage = 'Loss report withdrawn';
        await loadLossReports();
      }
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // Load destruction requests
  Future<void> loadDestructionRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _destructionRequests = await _operationsService.getDestructionRequests(
        status: _destructionFilter != 'all' ? _destructionFilter : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create destruction request
  Future<bool> createDestructionRequest({
    required String firearmId,
    required String destructionReason,
    required String conditionDescription,
    String? priority,
    String? maintenanceHistory,
    String? operationalHistory,
    String? witness1,
    String? witness2,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _operationsService.createDestructionRequest(
        firearmId: firearmId,
        destructionReason: destructionReason,
        conditionDescription: conditionDescription,
        priority: priority,
        maintenanceHistory: maintenanceHistory,
        operationalHistory: operationalHistory,
        witness1: witness1,
        witness2: witness2,
      );

      _successMessage = 'Destruction request submitted successfully';
      _isLoading = false;
      notifyListeners();
      
      await loadDestructionRequests();
      await loadStats();
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load procurement requests
  Future<void> loadProcurementRequests() async {
    _isLoading = true;
    notifyListeners();

    try {
      _procurementRequests = await _operationsService.getProcurementRequests(
        status: _procurementFilter != 'all' ? _procurementFilter : null,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  // Create procurement request
  Future<bool> createProcurementRequest({
    required String firearmType,
    required String manufacturer,
    required String model,
    required String caliber,
    required int quantity,
    required double estimatedUnitCost,
    required String justification,
    String? priority,
    String? preferredSupplier,
    String? operationalContext,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _operationsService.createProcurementRequest(
        firearmType: firearmType,
        manufacturer: manufacturer,
        model: model,
        caliber: caliber,
        quantity: quantity,
        estimatedUnitCost: estimatedUnitCost,
        justification: justification,
        priority: priority,
        preferredSupplier: preferredSupplier,
        operationalContext: operationalContext,
      );

      _successMessage = 'Procurement request submitted successfully';
      _isLoading = false;
      notifyListeners();
      
      await loadProcurementRequests();
      await loadStats();
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load statistics
  Future<void> loadStats() async {
    try {
      _stats = await _operationsService.getOperationsStats();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  // Set filters
  void setLossReportsFilter(String filter) {
    _lossReportsFilter = filter;
    notifyListeners();
    loadLossReports();
  }

  void setDestructionFilter(String filter) {
    _destructionFilter = filter;
    notifyListeners();
    loadDestructionRequests();
  }

  void setProcurementFilter(String filter) {
    _procurementFilter = filter;
    notifyListeners();
    loadProcurementRequests();
  }

  // Clear messages
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
