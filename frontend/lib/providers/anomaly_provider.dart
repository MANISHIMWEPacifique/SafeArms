// Anomaly Provider
// State management for anomaly data

import 'package:flutter/foundation.dart';
import '../services/anomaly_service.dart';

class AnomalyProvider with ChangeNotifier {
  final AnomalyService _anomalyService = AnomalyService();

  List<Map<String, dynamic>> _anomalies = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get anomalies => _anomalies;
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
