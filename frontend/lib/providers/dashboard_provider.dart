// Dashboard Provider
// State management for dashboard statistics

import 'package:flutter/foundation.dart';
import '../services/dashboard_service.dart';

class DashboardProvider with ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();

  Map<String, dynamic>? _dashboardStats;
  List<Map<String, dynamic>> _recentCustodyActivity = [];
  int? _activeUnitsCount;
  int? _totalUsersCount;
  int? _officersCount;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  List<Map<String, dynamic>> get recentCustodyActivity =>
      _recentCustodyActivity;
  int? get activeUnitsCount => _activeUnitsCount;
  int? get totalUsersCount => _totalUsersCount;
  int? get officersCount => _officersCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load dashboard statistics
  Future<void> loadDashboardStats() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboardStats = await _dashboardService.getDashboardStats();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _dashboardStats = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load recent custody activity (for station commanders)
  Future<void> loadRecentCustodyActivity() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recentCustodyActivity = await _dashboardService
          .getRecentCustodyActivity();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _recentCustodyActivity = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load active units count
  Future<void> loadActiveUnitsCount() async {
    try {
      _activeUnitsCount = await _dashboardService.getActiveUnitsCount();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Load total users count (admin only)
  Future<void> loadTotalUsersCount() async {
    try {
      _totalUsersCount = await _dashboardService.getTotalUsersCount();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // Load officers count
  Future<void> loadOfficersCount() async {
    try {
      _officersCount = await _dashboardService.getOfficersCount();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
