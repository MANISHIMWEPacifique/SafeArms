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
      _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
      _NavItem(icon: Icons.gavel, label: 'Firearms'),
      _NavItem(icon: Icons.people, label: 'Officers'),
      _NavItem(icon: Icons.sync_alt, label: 'Custody'),
      _NavItem(
        icon: Icons.warning_amber,
        label: 'Anomalies',
        badge: anomaliesCount > 0 ? anomaliesCount.toString() : null,
        badgeColor: const Color(0xFFFFC857),
      ),
      _NavItem(icon: Icons.assessment, label: 'Reports'),
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
      width: 260,
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Color(0xFF78909C).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'v1.0',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
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
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1E88E5).withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(
                          item.icon,
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : const Color(0xFFB0BEC5),
                          size: 22,
                        ),
                        title: Text(
                          item.label,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF1E88E5)
                                : const Color(0xFFB0BEC5),
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: item.badge != null
                            ? Container(
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
                              )
                            : null,
                        onTap: () => setState(() => _selectedIndex = index),
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
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: const Color(0xFFB0BEC5),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: const Color(0xFFB0BEC5),
            onPressed: _loadDashboardData,
          ),
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
              const SizedBox(height: 24),
              _buildRecentActivitiesLog(provider),
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
            Icons.gavel,
            const Color(0xFF1E88E5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Custody',
            inCustody,
            Icons.sync_alt,
            const Color(0xFF3CCB7F),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Officers',
            provider.officersCount.toString(),
            Icons.people,
            const Color(0xFFFFCA28),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Anomalies',
            anomalyCount.toString(),
            Icons.warning_amber,
            const Color(0xFFE85C5C),
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
              Icon(icon, color: color, size: 20),
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
            'Recent Custody Activity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (provider.recentCustodyActivity.isEmpty)
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
              itemCount: provider.recentCustodyActivity.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFF37404F),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final activity = provider.recentCustodyActivity[index];
                return ListTile(
                  leading: Icon(
                    activity['returned_at'] == null
                        ? Icons.arrow_forward
                        : Icons.arrow_back,
                    color: activity['returned_at'] == null
                        ? const Color(0xFFE85C5C)
                        : const Color(0xFF3CCB7F),
                  ),
                  title: Text(
                    '${activity['firearm_type'] ?? ''} - ${activity['serial_number'] ?? 'Unknown'}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${activity['assignment_reason'] ?? activity['purpose'] ?? 'N/A'} - ${activity['officer_name'] ?? 'N/A'}',
                    style: const TextStyle(color: Color(0xFF78909C)),
                  ),
                  trailing: Text(
                    _formatDate(
                        activity['issued_at'] ?? activity['checked_out_at']),
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesLog(DashboardProvider provider) {
    final activities = provider.recentActivities;
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
            'Recent Activities',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recent activities',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFF37404F),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final activity = activities[index];
                final actionType = activity['action_type'] ?? '';
                return ListTile(
                  leading: Icon(
                    _getActivityIcon(actionType),
                    color: _getActivityColor(actionType),
                    size: 22,
                  ),
                  title: Text(
                    _formatActionType(actionType, activity['table_name'] ?? ''),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    'By ${activity['actor_name'] ?? 'System'} ${activity['subject_description'] != null ? '- ${activity['subject_description']}' : ''}',
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                  ),
                  trailing: Text(
                    _formatDate(activity['created_at']),
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String actionType) {
    switch (actionType.toUpperCase()) {
      case 'CREATE':
        return Icons.add_circle_outline;
      case 'UPDATE':
        return Icons.edit_outlined;
      case 'DELETE':
        return Icons.delete_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _getActivityColor(String actionType) {
    switch (actionType.toUpperCase()) {
      case 'CREATE':
        return const Color(0xFF3CCB7F);
      case 'UPDATE':
        return const Color(0xFF1E88E5);
      case 'DELETE':
        return const Color(0xFFE85C5C);
      default:
        return const Color(0xFF78909C);
    }
  }

  String _formatActionType(String actionType, String tableName) {
    final entity = tableName.replaceAll('_', ' ');
    switch (actionType.toUpperCase()) {
      case 'CREATE':
        return 'Created $entity';
      case 'UPDATE':
        return 'Updated $entity';
      case 'DELETE':
        return 'Deleted $entity';
      default:
        return '$actionType $entity';
    }
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
