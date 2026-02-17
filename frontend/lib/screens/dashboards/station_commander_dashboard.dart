// Station Commander Dashboard
// Dashboard for station commander role - unit-level control center

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../auth/login_screen.dart';
import '../management/station_firearms_screen.dart';
import '../management/station_officers_screen.dart';
import '../workflows/station_custody_management_screen.dart';
import '../workflows/reports_screen.dart';
import '../anomaly/anomaly_detection_screen.dart';

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
    // Use addPostFrameCallback to avoid calling notifyListeners during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dashboardProvider =
        Provider.of<DashboardProvider>(context, listen: false);
    final anomalyProvider =
        Provider.of<AnomalyProvider>(context, listen: false);

    final unitId = authProvider.currentUser?['unit_id']?.toString();

    // Load all dashboard data - single API call gets all stats
    await Future.wait([
      dashboardProvider.loadDashboardStats(),
      if (unitId != null) anomalyProvider.loadUnitAnomalies(unitId, limit: 10),
    ]);
  }

  // Build dynamic nav items based on provider data
  List<_NavItem> _buildNavItems(BuildContext context) {
    final anomalyProvider = Provider.of<AnomalyProvider>(context);
    final anomaliesCount = anomalyProvider.anomalies.length;

    return [
      _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
      _NavItem(icon: Icons.security_outlined, label: 'Firearms'),
      _NavItem(icon: Icons.badge_outlined, label: 'Officers'),
      _NavItem(icon: Icons.swap_horiz_rounded, label: 'Custody'),
      _NavItem(
        icon: Icons.report_problem_outlined,
        label: 'Anomalies',
        badge: anomaliesCount > 0 ? anomaliesCount.toString() : null,
        badgeColor: const Color(0xFFFFC857),
      ),
      _NavItem(icon: Icons.analytics_outlined, label: 'Reports'),
    ];
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Row(
        children: [
          _buildSideNavigation(),
          Expanded(
            child: Column(
              children: [
                _buildTopNavBar(),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNavigation() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(right: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF37404F), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'SafeArms',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // User Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2A3040),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E88E5),
                  child: Text(
                    user?['full_name']?.toString().substring(0, 1) ?? 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?['full_name'] ?? 'Station Commander',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Station Commander',
                        style: TextStyle(
                          color: const Color(0xFF78909C),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: Builder(
              builder: (context) {
                final navItems = _buildNavItems(context);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: navItems.length,
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = _selectedIndex == index;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _selectedIndex = index),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1E88E5)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFFB0BEC5),
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (item.badge != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.badgeColor ??
                                          const Color(0xFFE85C5C),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item.badge!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF37404F), width: 1),
              ),
            ),
            child: ListTile(
              leading:
                  const Icon(Icons.logout, color: Color(0xFFE85C5C), size: 22),
              title: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFE85C5C), fontSize: 14),
              ),
              onTap: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            _buildNavItems(context)[_selectedIndex].label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Navigate to different screens based on selected index
    switch (_selectedIndex) {
      case 0:
        // Dashboard - show the main dashboard overview
        return _buildDashboardOverview();
      case 1:
        // Firearms - view unit's assigned firearms (Station-specific)
        return const StationFirearmsScreen();
      case 2:
        // Officers - unit-specific officers registry (Station-specific)
        return const StationOfficersScreen();
      case 3:
        // Custody Management (Station-specific)
        return const StationCustodyManagementScreen();
      case 4:
        // Anomalies
        return const AnomalyDetectionScreen();
      case 5:
        // Reports
        return const ReportsScreen(roleType: 'station');
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCards(provider),
              const SizedBox(height: 24),
              _buildRecentActivity(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCards(DashboardProvider provider) {
    final stats = provider.dashboardStats;
    final firearms = stats?['firearms'];
    final totalFirearms = firearms?['total']?.toString() ?? '0';
    final inCustody = stats?['active_custody']?.toString() ?? '0';

    // Count anomalies
    int anomalyCount = 0;
    final anomalies = stats?['anomalies'] as List?;
    if (anomalies != null) {
      for (var a in anomalies) {
        anomalyCount += int.tryParse(a['count']?.toString() ?? '0') ?? 0;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Firearms',
            totalFirearms,
            Icons.security_outlined,
            const Color(0xFF1E88E5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Custody',
            inCustody,
            Icons.swap_horiz_rounded,
            const Color(0xFF1E88E5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Officers',
            provider.officersCount.toString(),
            Icons.badge_outlined,
            const Color(0xFF1E88E5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Anomalies',
            anomalyCount.toString(),
            Icons.report_problem_outlined,
            const Color(0xFF1E88E5),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(DashboardProvider provider) {
    // Station commander sees only custody events from their unit
    final custodyEvents = provider.recentCustodyActivity;

    // Build display list from custody events only
    final List<Map<String, dynamic>> displayList = custodyEvents
        .take(8)
        .map<Map<String, dynamic>>((event) => {
              'type': 'custody',
              'data': event,
            })
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Station Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Custody events in your unit',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          const SizedBox(height: 16),
          if (displayList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayList.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFF37404F),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = displayList[index];
                return _buildCustodyItem(item['data']);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCustodyItem(Map<String, dynamic> activity) {
    final isAssigned = activity['returned_at'] == null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color:
              (isAssigned ? const Color(0xFFE85C5C) : const Color(0xFF3CCB7F))
                  .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isAssigned ? Icons.arrow_forward : Icons.arrow_back,
          color: isAssigned ? const Color(0xFFE85C5C) : const Color(0xFF3CCB7F),
          size: 20,
        ),
      ),
      title: Text(
        '${activity['firearm_type'] ?? ''} - ${activity['serial_number'] ?? 'Unknown'}',
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        '${isAssigned ? 'Assigned to' : 'Returned by'} ${activity['officer_name'] ?? 'N/A'}',
        style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
      ),
      trailing: Text(
        _formatDate(activity['issued_at'] ?? activity['checked_out_at']),
        style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? badgeColor;

  _NavItem({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeColor,
  });
}
