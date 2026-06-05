// Dashboard Provider
// State management for dashboard statistics

import 'package:flutter/foundation.dart';
import '../services/dashboard_service.dart';
import '../utils/date_formatter.dart';

class DashboardProvider with ChangeNotifier {
  final DashboardService _dashboardService = DashboardService();
  static const Duration _dashboardCacheTtl = Duration(seconds: 15);

  Map<String, dynamic>? _dashboardStats;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastLoadedAt;
  Future<void>? _loadDashboardFuture;

  Map<String, dynamic>? get dashboardStats => _dashboardStats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Convenience getters for common stats
  int get totalUsersCount => _dashboardStats?['total_users'] ?? 0;
  int get activeUnitsCount => _dashboardStats?['active_units'] ?? 0;
  int get activeCustodyCount => _dashboardStats?['active_custody'] ?? 0;
  int get officersCount => _dashboardStats?['officers_count'] ?? 0;
  Map<String, dynamic>? get firearmsStats => _dashboardStats?['firearms'];
  List<dynamic>? get anomaliesStats => _dashboardStats?['anomalies'];
  Map<String, dynamic>? get pendingApprovals =>
      _dashboardStats?['pending_approvals'];
  List<dynamic> get recentCustodyActivity =>
      _dashboardStats?['recent_custody'] ?? [];
  List<dynamic> get recentActivities =>
      _dashboardStats?['recent_activities'] ?? [];
  List<dynamic> get roleActivity => _dashboardStats?['role_activity'] ?? [];

  List<Map<String, dynamic>> getCombinedStationActivity({int limit = 6}) {
    final custodyEvents = recentCustodyActivity;
    final auditActivities = recentActivities;
    final nowWithSkewTolerance = DateTime.now().add(const Duration(minutes: 2));

    final List<Map<String, dynamic>> displayList = [];

    for (var event in custodyEvents) {
      final eventMap = event is Map<String, dynamic>
          ? event
          : Map<String, dynamic>.from(event as Map);
      final timestamp = eventMap['activity_at'] ??
          eventMap['returned_at'] ??
          eventMap['issued_at'] ??
          '';
      final parsedTimestamp = DateFormatter.parseTimestamp(timestamp);

      if (parsedTimestamp != null &&
          parsedTimestamp.isAfter(nowWithSkewTolerance)) {
        continue;
      }

      displayList.add({
        'type': 'custody',
        'data': eventMap,
        'timestamp': timestamp,
        'parsedTimestamp': parsedTimestamp,
      });
    }

    for (var activity in auditActivities) {
      final actMap = activity is Map<String, dynamic>
          ? activity
          : Map<String, dynamic>.from(activity as Map);
      final timestamp = actMap['created_at'] ?? '';
      final parsedTimestamp = DateFormatter.parseTimestamp(timestamp);

      if (parsedTimestamp != null &&
          parsedTimestamp.isAfter(nowWithSkewTolerance)) {
        continue;
      }

      displayList.add({
        'type': 'audit',
        'data': actMap,
        'timestamp': timestamp,
        'parsedTimestamp': parsedTimestamp,
      });
    }

    displayList.sort((a, b) {
      final aTime = a['parsedTimestamp'] as DateTime?;
      final bTime = b['parsedTimestamp'] as DateTime?;

      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;

      return bTime.compareTo(aTime);
    });

    final limitedList = displayList.take(limit).toList();

    if (custodyEvents.isNotEmpty &&
        limitedList.isNotEmpty &&
        limitedList.every((item) => item['type'] != 'custody')) {
      final latestCustody = displayList.firstWhere(
        (item) => item['type'] == 'custody',
        orElse: () => <String, dynamic>{},
      );
      if (latestCustody.isNotEmpty) {
        limitedList[limitedList.length - 1] = latestCustody;
        limitedList.sort((a, b) {
          final aTime = a['parsedTimestamp'] as DateTime?;
          final bTime = b['parsedTimestamp'] as DateTime?;

          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;

          return bTime.compareTo(aTime);
        });
      }
    }

    return limitedList;
  }

  // Load all dashboard statistics with one API call
  Future<void> loadDashboardStats({bool force = false}) async {
    if (_loadDashboardFuture != null) {
      await _loadDashboardFuture;
      if (!force) {
        return;
      }
    }

    if (!force &&
        _dashboardStats != null &&
        _lastLoadedAt != null &&
        DateTime.now().difference(_lastLoadedAt!) < _dashboardCacheTtl) {
      return;
    }

    final loadFuture = _loadDashboardStatsInternal();
    _loadDashboardFuture = loadFuture;

    try {
      await loadFuture;
    } finally {
      if (identical(_loadDashboardFuture, loadFuture)) {
        _loadDashboardFuture = null;
      }
    }
  }

  Future<void> _loadDashboardStatsInternal() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _dashboardStats = await _dashboardService.getDashboardStats();
      _lastLoadedAt = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _dashboardStats = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
