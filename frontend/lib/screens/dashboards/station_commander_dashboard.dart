// Station Commander Dashboard
// Dashboard for station commander role - unit-level control center

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../auth/login_screen.dart';
import '../management/station_firearms_screen.dart';
import '../management/station_officers_screen.dart';
import '../workflows/station_custody_management_screen.dart';
import '../workflows/reports_screen.dart';
import '../anomaly/anomaly_detection_screen.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/responsive_dashboard_scaffold.dart';
import '../../widgets/user_avatar.dart';

class StationCommanderDashboard extends StatefulWidget {
  final bool autoLoad;

  const StationCommanderDashboard({
    super.key,
    this.autoLoad = true,
  });

  @override
  State<StationCommanderDashboard> createState() =>
      _StationCommanderDashboardState();
}

class _StationCommanderDashboardState extends State<StationCommanderDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      // Use addPostFrameCallback to avoid calling notifyListeners during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDashboardData(force: true);
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDashboardData({
    bool force = false,
    bool includeAnomalies = true,
  }) async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final dashboardProvider =
        Provider.of<DashboardProvider>(context, listen: false);

    final unitId = authProvider.currentUser?['unit_id']?.toString();

    // Load core stats first for faster first paint, then hydrate activity.
    await dashboardProvider.loadDashboardStats(
      force: force,
      includeRecent: false,
    );

    if (!mounted) return;

    unawaited(dashboardProvider.loadDashboardStats(
      force: true,
      includeRecent: true,
      showLoading: false,
    ));

    if (!mounted || unitId == null || !includeAnomalies) return;

    final anomalyProvider =
        Provider.of<AnomalyProvider>(context, listen: false);

    // Fetch anomalies in background.
    unawaited(anomalyProvider.loadUnitAnomalies(unitId));
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
    return ResponsiveDashboardScaffold(
      sideNavigation: _buildSideNavigation(),
      topNavigation: _buildTopNavBar(),
      mainContent: _buildMainContent(),
    );
  }

  Widget _buildSideNavigation() {
    final authProvider = Provider.of<AuthProvider?>(context);
    final user = authProvider?.currentUser;

    return Material(
      color: const Color(0xFF252A3A),
      child: Container(
        width: 220,
        decoration: const BoxDecoration(
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
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
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
                UserAvatar(
                  fullName: user?['full_name']?.toString(),
                  photoUrl: user?['profile_photo_url']?.toString(),
                  radius: 24,
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
                      const Text(
                        'Station Commander',
                        style: TextStyle(
                          color: Color(0xFF78909C),
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
                          onTap: () {
                            setState(() => _selectedIndex = index);
                            // Close drawer if open (tablet/compact mode)
                            final scaffoldState = Scaffold.maybeOf(context);
                            if (scaffoldState?.isDrawerOpen ?? false) {
                              Navigator.of(context).pop();
                            }
                            // Reload dashboard data when switching back to Dashboard tab
                            if (index == 0) {
                              _loadDashboardData(force: true);
                            }
                          },
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
    ));
  }

  Widget _buildTopNavBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;

        return Container(
          height: isPhone ? 56 : 64,
          padding: EdgeInsets.symmetric(horizontal: isPhone ? 16 : 24),
          decoration: const BoxDecoration(
            color: Color(0xFF252A3A),
            border: Border(
              bottom: BorderSide(color: Color(0xFF37404F), width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _buildNavItems(context)[_selectedIndex].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isPhone ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
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

        return LayoutBuilder(
          builder: (context, outerConstraints) {
            final pad = outerConstraints.maxWidth < 480 ? 12.0 : 24.0;
            return SingleChildScrollView(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsCards(provider),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        return Column(
                          children: [
                            _buildFirearmStatusChart(provider),
                            const SizedBox(height: 16),
                            _buildRecentActivity(provider),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildFirearmStatusChart(provider,
                                isExpanded: true),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child:
                                _buildRecentActivity(provider, isExpanded: true),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatsCards(DashboardProvider provider) {
    final stats = provider.dashboardStats;
    final firearms = stats?['firearms'];
    final totalFirearms = firearms?['total']?.toString() ?? '0';
    final inCustody = stats?['active_custody']?.toString() ?? '0';
    final anomalyCount = context.watch<AnomalyProvider>().anomalies.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPhone = constraints.maxWidth < 600;
        final useSingleColumn = constraints.maxWidth < 390;
        final gap = isPhone ? 10.0 : 16.0;
        final cards = [
          _buildStatCard('Total Firearms', totalFirearms,
              Icons.security_outlined, const Color(0xFF1E88E5),
              compact: isPhone),
          _buildStatCard('Active Custody', inCustody, Icons.swap_horiz_rounded,
              const Color(0xFF1E88E5),
              compact: isPhone),
          _buildStatCard('Officers', provider.officersCount.toString(),
              Icons.badge_outlined, const Color(0xFF1E88E5),
              compact: isPhone),
          _buildStatCard('Anomalies', anomalyCount.toString(),
              Icons.report_problem_outlined, const Color(0xFF1E88E5),
              compact: isPhone),
        ];

        if (useSingleColumn) {
          return Column(
            children: cards
                .asMap()
                .entries
                .map((entry) => Padding(
                      padding: EdgeInsets.only(top: entry.key == 0 ? 0 : gap),
                      child: entry.value,
                    ))
                .toList(),
          );
        }

        if (constraints.maxWidth < 600) {
          final cardWidth = (constraints.maxWidth - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            SizedBox(width: gap),
            Expanded(child: cards[1]),
            SizedBox(width: gap),
            Expanded(child: cards[2]),
            SizedBox(width: gap),
            Expanded(child: cards[3]),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 20),
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
              Icon(icon, color: color, size: compact ? 22 : 28),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 22 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFFB0BEC5),
              fontSize: compact ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirearmStatusChart(DashboardProvider provider,
      {bool isExpanded = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stats = provider.dashboardStats;
        final firearms = stats?['firearms'];
        final isPhone = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth < 600;

        final available =
            double.tryParse(firearms?['available']?.toString() ?? '0') ?? 0;
        final inCustody =
            double.tryParse(firearms?['in_custody']?.toString() ?? '0') ?? 0;
        final maintenance =
            double.tryParse(firearms?['maintenance']?.toString() ?? '0') ?? 0;
        final total = available + inCustody + maintenance;

        final centerRadius = isPhone ? 34.0 : (isExpanded ? 56.0 : 40.0);
        final sectionRadius = isPhone ? 46.0 : (isExpanded ? 66.0 : 50.0);
        final contentHeight = isPhone ? 270.0 : (isTablet ? 220.0 : 200.0);
        final expandedHeight = isTablet ? 420.0 : 500.0;

        Widget pieChart() {
          if (total == 0) {
            return const Center(
              child: Text(
                'No firearm data available',
                style: TextStyle(color: Color(0xFF78909C)),
              ),
            );
          }

          return PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: centerRadius,
              sections: [
                if (available > 0)
                  PieChartSectionData(
                    value: available,
                    title: '${(available / total * 100).toStringAsFixed(0)}%',
                    color: const Color(0xFF3CCB7F),
                    radius: sectionRadius,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (inCustody > 0)
                  PieChartSectionData(
                    value: inCustody,
                    title: '${(inCustody / total * 100).toStringAsFixed(0)}%',
                    color: const Color(0xFF42A5F5),
                    radius: sectionRadius,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (maintenance > 0)
                  PieChartSectionData(
                    value: maintenance,
                    title: '${(maintenance / total * 100).toStringAsFixed(0)}%',
                    color: const Color(0xFFFFB74D),
                    radius: sectionRadius,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          );
        }

        final legend = Wrap(
          spacing: isPhone ? 14 : 0,
          runSpacing: 10,
          direction: isPhone ? Axis.horizontal : Axis.vertical,
          children: [
            _buildLegendItem(
                const Color(0xFF3CCB7F), 'Available', available.toInt()),
            _buildLegendItem(
                const Color(0xFF42A5F5), 'In Custody', inCustody.toInt()),
            _buildLegendItem(
                const Color(0xFFFFB74D), 'Maintenance', maintenance.toInt()),
          ],
        );

        final chartContent = total == 0
            ? pieChart()
            : isPhone
                ? Column(
                    children: [
                      Expanded(child: pieChart()),
                      const SizedBox(height: 16),
                      legend,
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: pieChart()),
                      const SizedBox(width: 24),
                      legend,
                    ],
                  );

        return Container(
          height: isExpanded ? expandedHeight : null,
          padding: EdgeInsets.all(isPhone ? 16 : 24),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF37404F), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit Firearm Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isPhone ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: ${total.toInt()} firearms in your unit',
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
              ),
              SizedBox(height: isPhone ? 16 : 24),
              if (isExpanded)
                Expanded(child: chartContent)
              else
                SizedBox(
                  height: contentHeight,
                  child: chartContent,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label ($count)',
          style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(DashboardProvider provider,
      {bool isExpanded = false}) {
    const int maxDisplayItems = 6;
    final width = MediaQuery.of(context).size.width;
    final isPhone = width < 480;
    final isTablet = width < 600;
    final limitedList = provider.getCombinedStationActivity(
      limit: maxDisplayItems,
    );

    return Container(
      height: isExpanded ? (isTablet ? 420 : 500) : null,
      padding: EdgeInsets.all(isPhone ? 16 : 20),
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
              Expanded(
                child: Text(
                  'Recent Station Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isPhone ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _loadDashboardData(force: true),
                icon: const Icon(
                  Icons.refresh,
                  color: Color(0xFF1E88E5),
                  size: 20,
                ),
                tooltip: 'Refresh activity',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Custody events in your unit',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          SizedBox(height: isPhone ? 12 : 16),
          if (limitedList.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else if (isExpanded)
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: limitedList.length,
                separatorBuilder: (context, index) => const Divider(
                  color: Color(0xFF37404F),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final item = limitedList[index];
                  if (item['type'] == 'audit') {
                    return _buildAuditItem(item['data']);
                  }
                  return _buildCustodyItem(item['data']);
                },
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: limitedList.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color(0xFF37404F),
                height: 1,
              ),
              itemBuilder: (context, index) {
                final item = limitedList[index];
                if (item['type'] == 'audit') {
                  return _buildAuditItem(item['data']);
                }
                return _buildCustodyItem(item['data']);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAuditItem(Map<String, dynamic> activity) {
    final actionType = activity['action_type']?.toString() ?? 'action';
    final tableName = activity['table_name']?.toString() ?? '';
    final actorName = activity['actor_name']?.toString() ?? 'System';
    final subject = activity['subject_description']?.toString() ?? tableName;

    // Map action types to icons and colors
    IconData icon;
    Color color;
    String actionLabel;
    switch (actionType.toLowerCase()) {
      case 'create':
      case 'insert':
        icon = Icons.add_circle_outline;
        color = const Color(0xFF3CCB7F);
        actionLabel = 'Created';
        break;
      case 'update':
        icon = Icons.edit_outlined;
        color = const Color(0xFFFFC857);
        actionLabel = 'Updated';
        break;
      case 'delete':
        icon = Icons.delete_outline;
        color = const Color(0xFFE85C5C);
        actionLabel = 'Deleted';
        break;
      case 'login':
        icon = Icons.login;
        color = const Color(0xFF5B8DEF);
        actionLabel = 'Logged in';
        break;
      case 'checkout':
      case 'checkin':
        icon = Icons.swap_horiz;
        color = const Color(0xFF5B8DEF);
        actionLabel = actionType == 'checkout' ? 'Checked out' : 'Checked in';
        break;
      default:
        icon = Icons.info_outline;
        color = const Color(0xFF78909C);
        actionLabel = actionType;
    }

    // Format the table name for display
    final displayTable = tableName.replaceAll('_', ' ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final timeAgo = _formatTimeAgo(activity['created_at']);
        final subtitle =
            'by $actorName${subject.isNotEmpty && subject != tableName ? ' - $subject' : ''}';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: isNarrow ? 32 : 36,
            height: isNarrow ? 32 : 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isNarrow ? 18 : 20),
          ),
          title: Text(
            '$actionLabel $displayTable',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isNarrow ? '$subtitle • $timeAgo' : subtitle,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
            maxLines: isNarrow ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isNarrow
              ? null
              : Text(
                  timeAgo,
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                ),
        );
      },
    );
  }

  Widget _buildCustodyItem(Map<String, dynamic> activity) {
    final isAssigned = activity['returned_at'] == null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final timeAgo = _formatTimeAgo(isAssigned
            ? activity['issued_at']
            : (activity['returned_at'] ?? activity['issued_at']));
        final subtitle =
            '${isAssigned ? 'Assigned to' : 'Returned by'} ${activity['officer_name'] ?? 'N/A'}';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: isNarrow ? 32 : 36,
            height: isNarrow ? 32 : 36,
            decoration: BoxDecoration(
              color: (isAssigned
                      ? const Color(0xFFE85C5C)
                      : const Color(0xFF3CCB7F))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAssigned ? Icons.arrow_forward : Icons.arrow_back,
              color: isAssigned
                  ? const Color(0xFFE85C5C)
                  : const Color(0xFF3CCB7F),
              size: isNarrow ? 18 : 20,
            ),
          ),
          title: Text(
            '${activity['firearm_type'] ?? ''} - ${activity['serial_number'] ?? 'Unknown'}',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isNarrow ? '$subtitle • $timeAgo' : subtitle,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
            maxLines: isNarrow ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isNarrow
              ? null
              : Text(
                  timeAgo,
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 11),
                ),
        );
      },
    );
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    final dateStr = timestamp.toString().trim();
    if (dateStr.isEmpty) return 'N/A';
    return DateFormatter.timeAgo(dateStr);
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
