// Station Commander Dashboard
// Dashboard for station commander role - unit-level control center

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/custody_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../auth/login_screen.dart';

class StationCommanderDashboard extends StatefulWidget {
  const StationCommanderDashboard({super.key});

  @override
  State<StationCommanderDashboard> createState() =>
      _StationCommanderDashboardState();
}

class _StationCommanderDashboardState extends State<StationCommanderDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dashboardProvider =
        Provider.of<DashboardProvider>(context, listen: false);
    final custodyProvider =
        Provider.of<CustodyProvider>(context, listen: false);
    final anomalyProvider =
        Provider.of<AnomalyProvider>(context, listen: false);

    final unitId = authProvider.currentUser?['unit_id']?.toString();

    // Load all dashboard data
    await Future.wait([
      dashboardProvider.loadDashboardStats(),
      dashboardProvider.loadRecentCustodyActivity(),
      dashboardProvider.loadOfficersCount(),
      if (unitId != null) anomalyProvider.loadUnitAnomalies(unitId, limit: 10),
    ]);
  }
