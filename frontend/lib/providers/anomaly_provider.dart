// Anomaly Provider
// State management for anomaly data

import 'package:flutter/foundation.dart';
import '../services/anomaly_service.dart';

class AnomalyProvider with ChangeNotifier {
  final AnomalyService _anomalyService = AnomalyService();
  static const Duration _anomalyCacheTtl = Duration(seconds: 15);

  List<Map<String, dynamic>> _anomalies = [];
  List<Map<String, dynamic>> _investigationResults = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadedAt;
  String? _lastCacheKey;
  Future<void>? _loadFuture;

  List<Map<String, dynamic>> get anomalies => _anomalies;
  List<Map<String, dynamic>> get investigationResults => _investigationResults;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _isCacheValid(String cacheKey) {
    return _lastCacheKey == cacheKey &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < _anomalyCacheTtl;
  }

  void _invalidateAnomalyCache() {
    _lastLoadedAt = null;
    _lastCacheKey = null;
  }

  Future<void> _loadAnomaliesWithCache({
    required String cacheKey,
    required Future<List<Map<String, dynamic>>> Function() loader,
    bool force = false,
  }) async {
    if (_loadFuture != null) {
      await _loadFuture;
      if (!force && _isCacheValid(cacheKey)) {
        return;
      }
    }

    if (!force && _isCacheValid(cacheKey)) {
      return;
    }

    final loadFuture = _executeLoad(cacheKey, loader);
    _loadFuture = loadFuture;

    try {
      await loadFuture;
    } finally {
      if (identical(_loadFuture, loadFuture)) {
        _loadFuture = null;
      }
    }
  }

  Future<void> _executeLoad(
    String cacheKey,
    Future<List<Map<String, dynamic>>> Function() loader,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _anomalies = await loader();
      _error = null;
      _lastCacheKey = cacheKey;
      _lastLoadedAt = DateTime.now();
    } catch (e) {
      _error = e.toString();
      _anomalies = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load all anomalies
  Future<void> loadAnomalies({
    int? limit,
    int? offset,
    String? severity,
    String? status,
    bool force = false,
  }) async {
    final cacheKey =
        'all:${limit ?? ''}:${offset ?? ''}:${severity ?? ''}:${status ?? ''}';

    await _loadAnomaliesWithCache(
      cacheKey: cacheKey,
      force: force,
      loader: () => _anomalyService.getAnomalies(
        limit: limit,
        offset: offset,
        severity: severity,
        status: status,
      ),
    );
  }

  // Load unit anomalies (for station commanders)
  Future<void> loadUnitAnomalies(
    String unitId, {
    int? limit,
    int? offset,
    bool force = false,
  }) async {
    final cacheKey = 'unit:$unitId:${limit ?? ''}:${offset ?? ''}';

    await _loadAnomaliesWithCache(
      cacheKey: cacheKey,
      force: force,
      loader: () => _anomalyService.getUnitAnomalies(
        unitId,
        limit: limit,
        offset: offset,
      ),
    );
  }

  // Update anomaly
  Future<bool> updateAnomaly(String id, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _anomalyService.updateAnomaly(id, updates);
      _invalidateAnomalyCache();
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
      _invalidateAnomalyCache();
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
      _invalidateAnomalyCache();
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
      _invalidateAnomalyCache();
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
      _invalidateAnomalyCache();
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
