// Anomaly Provider
// State management for anomaly data

import 'package:flutter/foundation.dart';
import '../services/anomaly_service.dart';

class AnomalyProvider with ChangeNotifier {
  final AnomalyService _anomalyService = AnomalyService();

  List<Map<String, dynamic>> _anomalies = [];
  List<Map<String, dynamic>> _investigationResults = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get anomalies => _anomalies;
  List<Map<String, dynamic>> get investigationResults => _investigationResults;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load all anomalies
  Future<void> loadAnomalies({
    int? limit,
    int? offset,
    String? severity,
    String? status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _anomalies = await _anomalyService.getAnomalies(
        limit: limit,
        offset: offset,
        severity: severity,
        status: status,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _anomalies = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load unit anomalies (for station commanders)
  Future<void> loadUnitAnomalies(
    String unitId, {
    int? limit,
    int? offset,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _anomalies = await _anomalyService.getUnitAnomalies(
        unitId,
        limit: limit,
        offset: offset,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _anomalies = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update anomaly
  Future<bool> updateAnomaly(String id, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _anomalyService.updateAnomaly(id, updates);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Start investigation
  Future<bool> investigateAnomaly(String id, {String? notes}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _anomalyService.investigateAnomaly(id, notes: notes);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Resolve anomaly
  Future<bool> resolveAnomaly(String id, {String? notes}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _anomalyService.resolveAnomaly(id, notes: notes);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Mark as false positive (feeds ML training data)
  Future<bool> markFalsePositive(String id, {String? notes}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _anomalyService.markFalsePositive(id, notes: notes);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Submit explanation for critical anomaly
  Future<bool> submitExplanation(String id, {required String message}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _anomalyService.submitExplanation(id, message: message);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Search anomalies for investigation
  Future<void> searchForInvestigation({
    String? unitId,
    String? startDate,
    String? endDate,
    String? severity,
    String? status,
    int? limit,
    int? offset,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _investigationResults = await _anomalyService.searchForInvestigation(
        unitId: unitId,
        startDate: startDate,
        endDate: endDate,
        severity: severity,
        status: status,
        limit: limit,
        offset: offset,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _investigationResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearInvestigationResults() {
    _investigationResults = [];
    notifyListeners();
  }
}
