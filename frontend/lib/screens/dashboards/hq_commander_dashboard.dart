// HQ Commander Dashboard
// Dashboard for HQ firearm commander role

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/firearm_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../../providers/approval_provider.dart';
import '../../providers/settings_provider.dart';
import '../auth/login_screen.dart';
import '../management/units_management_screen.dart';
import '../management/firearms_registry_screen.dart';
import '../workflows/reports_screen.dart';
import '../workflows/hq_reports_screen.dart';
import '../anomaly/anomaly_detection_screen.dart';
import '../../widgets/responsive_dashboard_scaffold.dart';
import '../../widgets/user_avatar.dart';

class HqCommanderDashboard extends StatefulWidget {
  const HqCommanderDashboard({super.key});

  @override
  State<HqCommanderDashboard> createState() => _HqCommanderDashboardState();
}

class _HqCommanderDashboardState extends State<HqCommanderDashboard> {
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
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final firearmsProvider = Provider.of<FirearmProvider>(
      context,
      listen: false,
    );
    final anomalyProvider = Provider.of<AnomalyProvider>(
      context,
      listen: false,
    );
    final approvalProvider = Provider.of<ApprovalProvider>(
      context,
      listen: false,
    );
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    // Load core stats first for faster first paint.
    await dashboardProvider.loadDashboardStats();

    if (!mounted) return;

    // Fetch secondary panels in background.
    unawaited(firearmsProvider.loadStats());
    unawaited(
      anomalyProvider.loadAnomalies(
        limit: settingsProvider.itemsPerPage > 0
            ? settingsProvider.itemsPerPage
            : 10,
      ),
    );
    unawaited(approvalProvider.loadPendingApprovals());
  }

  // Build dynamic nav items based on provider data
  List<_NavItem> _buildNavItems(BuildContext context) {
    final approvalProvider = Provider.of<ApprovalProvider>(context);
    final anomalyProvider = Provider.of<AnomalyProvider>(context);

    // Calculate pending approvals total
    final pendingApprovals = approvalProvider.pendingApprovals;
    final lossReports = (pendingApprovals?['loss_reports'] is List)
        ? (pendingApprovals!['loss_reports'] as List).length
        : (int.tryParse(pendingApprovals?['loss_reports']?.toString() ?? '0') ??
            0);
    final destruction = (pendingApprovals?['destruction_requests'] is List)
        ? (pendingApprovals!['destruction_requests'] as List).length
        : (int.tryParse(
                pendingApprovals?['destruction_requests']?.toString() ?? '0') ??
            0);
    final procurement = (pendingApprovals?['procurement_requests'] is List)
        ? (pendingApprovals!['procurement_requests'] as List).length
        : (int.tryParse(
                pendingApprovals?['procurement_requests']?.toString() ?? '0') ??
            0);
    final totalPendingApprovals = lossReports + destruction + procurement;

    // Get anomalies count
    final anomaliesCount = anomalyProvider.anomalies.length;

    return [
      _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', badge: null),
      _NavItem(
          icon: Icons.account_balance_outlined, label: 'Units', badge: null),
      _NavItem(icon: Icons.security_outlined, label: 'Firearms', badge: null),
      _NavItem(
        icon: Icons.task_alt,
        label: 'Approvals',
        badge:
            totalPendingApprovals > 0 ? totalPendingApprovals.toString() : null,
        badgeColor: const Color(0xFFE85C5C),
      ),
      _NavItem(
        icon: Icons.report_problem_outlined,
        label: 'Anomalies',
        badge: anomaliesCount > 0 ? anomaliesCount.toString() : null,
        badgeColor: const Color(0xFFFFC857),
      ),
      _NavItem(icon: Icons.analytics_outlined, label: 'Reports', badge: null),
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
            child: const Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 28,
                ),
                SizedBox(width: 12),
                Text(
                  'SafeArms',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
                        user?['full_name'] ?? 'Cdr. Jean Nkusi',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'HQ Firearm Commander',
                        style: TextStyle(
                          color: Color(0xFFB0BEC5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Navigation Items - Dynamic based on provider data
          Expanded(
            child: Builder(
              builder: (context) {
                final navItems = _buildNavItems(context);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: navItems.length,
                  itemBuilder: (context, index) {
                    final item = navItems[index];
                    final isSelected = _selectedIndex == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
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
                              _loadDashboardData();
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
                                    ),
                                  ),
                                ),
                                if (item.badge != null &&
                                    item.badge!.isNotEmpty &&
                                    item.badge != '0')
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: item.badgeColor ??
                                          const Color(0xFFFFC857),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      item.badge!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
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

          // Bottom Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3CCB7F),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Operational',
                      style: TextStyle(color: Color(0xFF3CCB7F), fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(
                      Icons.logout,
                      color: Color(0xFFE85C5C),
                      size: 16,
                    ),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: Color(0xFFE85C5C), fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF37404F)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Home / Dashboard',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          Builder(
            builder: (context) {
              final authProvider = Provider.of<AuthProvider>(context);
              final userName = authProvider.userName ?? 'Commander';
              return TextButton.icon(
                onPressed: () {
                  showMenu(
                    context: context,
                    position: const RelativeRect.fromLTRB(1000, 64, 0, 0),
                    color: const Color(0xFF2A3040),
                    items: <PopupMenuEntry<dynamic>>[
                      PopupMenuItem(
                        enabled: false,
                        child: Text(userName,
                            style: const TextStyle(
                                color: Color(0xFF78909C), fontSize: 13)),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        onTap: () {
                          authProvider.logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        },
                        child: const Row(
                          children: [
                            Icon(Icons.logout,
                                color: Color(0xFFE85C5C), size: 18),
                            SizedBox(width: 8),
                            Text('Logout',
                                style: TextStyle(color: Color(0xFFE85C5C))),
                          ],
                        ),
                      ),
                    ],
                  );
                },
                icon: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF1E88E5),
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                label: Row(
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      userName,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF78909C),
                      size: 20,
                    ),
                  ],
                ),
              );
            },
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
        // Units Management
        return const UnitsManagementScreen();
      case 2:
        // Firearms Registry
        return const FirearmsRegistryScreen();
      case 3:
        // Approvals - using ReportsScreen with HQ role for approve/reject
        return const ReportsScreen(roleType: 'hq');
      case 4:
        // Anomalies Detection
        return const AnomalyDetectionScreen();
      case 5:
        // National Reports
        return const HqReportsScreen();
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildDashboardOverview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth < 900;
        final padding = isTablet ? 16.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCards(),
              const SizedBox(height: 32),
              _buildChartsSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final cards = [
          _buildTotalFirearmsCard(),
          _buildPendingApprovalsCard(),
          _buildActiveUnitsCard(),
          _buildAnomaliesCard(),
        ];
        if (isNarrow) {
          return Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[3]),
                  ],
                ),
              ),
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
              const SizedBox(width: 16),
              Expanded(child: cards[3]),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalFirearmsCard() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final dashboardStats = dashboardProvider.dashboardStats;
    final firearmsData = dashboardStats?['firearms'];
    final total = firearmsData?['total']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gps_fixed, color: Color(0xFF1E88E5), size: 36),
          const SizedBox(height: 8),
          dashboardProvider.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  total,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),
          const Text(
            'Total Firearms Registered',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${firearmsData?['available'] ?? 0} Available',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          Text(
            '${firearmsData?['in_custody'] ?? 0} In Custody',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsCard() {
    final approvalProvider = Provider.of<ApprovalProvider>(context);
    final pendingApprovals = approvalProvider.pendingApprovals;
    final lossReports = (pendingApprovals?['loss_reports'] is List)
        ? (pendingApprovals!['loss_reports'] as List).length
        : (int.tryParse(pendingApprovals?['loss_reports']?.toString() ?? '0') ??
            0);
    final destruction = (pendingApprovals?['destruction_requests'] is List)
        ? (pendingApprovals!['destruction_requests'] as List).length
        : (int.tryParse(
                pendingApprovals?['destruction_requests']?.toString() ?? '0') ??
            0);
    final procurement = (pendingApprovals?['procurement_requests'] is List)
        ? (pendingApprovals!['procurement_requests'] as List).length
        : (int.tryParse(
                pendingApprovals?['procurement_requests']?.toString() ?? '0') ??
            0);
    final total = lossReports + destruction + procurement;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.schedule, color: Color(0xFF1E88E5), size: 36),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE85C5C),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$total Pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          approvalProvider.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  total.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),
          const Text(
            'Pending Approvals',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '$lossReports Loss Reports',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          Text(
            '$destruction Destruction',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          Text(
            '$procurement Procurement',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUnitsCard() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final activeUnits = dashboardProvider.activeUnitsCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business, color: Color(0xFF1E88E5), size: 36),
          const SizedBox(height: 8),
          dashboardProvider.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  activeUnits.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),
          const Text(
            'Police Units Nationwide',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesCard() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final anomaliesData =
        dashboardProvider.dashboardStats?['anomalies'] as List?;

    int critical = 0, high = 0, medium = 0;
    int total = 0;

    if (anomaliesData != null) {
      for (var item in anomaliesData) {
        final count = int.tryParse(item['count']?.toString() ?? '0') ?? 0;
        final severity = item['severity']?.toString().toLowerCase() ?? '';

        total += count;
        if (severity == 'critical') {
          critical = count;
        } else if (severity == 'high') {
          high = count;
        } else if (severity == 'medium' || severity == 'low') {
          medium += count;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF1E88E5), size: 36),
          const SizedBox(height: 8),
          dashboardProvider.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  total.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),
          const Text(
            'Anomalies (30 Days)',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildAnomalyIndicator('$critical Critical', const Color(0xFFE85C5C)),
          _buildAnomalyIndicator('$high High', const Color(0xFFFFC857)),
          _buildAnomalyIndicator('$medium Medium/Low', const Color(0xFF42A5F5)),
        ],
      ),
    );
  }

  Widget _buildAnomalyIndicator(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      children: [
        const _UserActivitiesBarChart(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  const _FirearmDistributionPieChart(),
                  const SizedBox(height: 16),
                  _buildApprovalQueue(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  flex: 65,
                  child: _FirearmDistributionPieChart(),
                ),
                const SizedBox(width: 16),
                Expanded(flex: 35, child: _buildApprovalQueue()),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildApprovalQueue() {
    final approvalProvider = Provider.of<ApprovalProvider>(context);
    final pendingApprovals = approvalProvider.pendingApprovals;
    final lossReports = (pendingApprovals?['loss_reports'] is List)
        ? (pendingApprovals!['loss_reports'] as List).length
        : (int.tryParse(pendingApprovals?['loss_reports']?.toString() ?? '0') ??
            0);
    final destruction = (pendingApprovals?['destruction_requests'] is List)
        ? (pendingApprovals!['destruction_requests'] as List).length
        : (int.tryParse(
                pendingApprovals?['destruction_requests']?.toString() ?? '0') ??
            0);
    final procurement = (pendingApprovals?['procurement_requests'] is List)
        ? (pendingApprovals!['procurement_requests'] as List).length
        : (int.tryParse(
                pendingApprovals?['procurement_requests']?.toString() ?? '0') ??
            0);
    final total = lossReports + destruction + procurement;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Approval Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC857),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$total Pending',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No pending approvals',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else ...[
            if (lossReports > 0)
              _buildApprovalSummaryCard(
                Icons.report_problem_outlined,
                const Color(0xFFE85C5C),
                'Loss Reports',
                '$lossReports pending review',
                lossReports > 1,
              ),
            if (destruction > 0)
              _buildApprovalSummaryCard(
                Icons.delete_outline,
                const Color(0xFFFFC857),
                'Destruction Requests',
                '$destruction pending review',
                false,
              ),
            if (procurement > 0)
              _buildApprovalSummaryCard(
                Icons.add_circle_outline,
                const Color(0xFF3CCB7F),
                'Procurement Requests',
                '$procurement pending review',
                false,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovalSummaryCard(
    IconData icon,
    Color color,
    String type,
    String description,
    bool isUrgent,
  ) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE85C5C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              setState(() => _selectedIndex = 3); // Go to Approvals tab
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E88E5),
              side: const BorderSide(color: Color(0xFF1E88E5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Review',
              style: TextStyle(color: Color(0xFF1E88E5), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? badgeColor;

  _NavItem(
      {required this.icon, required this.label, this.badge, this.badgeColor});
}

class _FirearmDistributionPieChart extends StatefulWidget {
  const _FirearmDistributionPieChart();

  @override
  State<_FirearmDistributionPieChart> createState() =>
      _FirearmDistributionPieChartState();
}

class _FirearmDistributionPieChartState
    extends State<_FirearmDistributionPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);
    final firearms = dashProvider.firearmsStats;

    final available =
        double.tryParse(firearms?['available']?.toString() ?? '0') ?? 0;
    final inCustody =
        double.tryParse(firearms?['in_custody']?.toString() ?? '0') ?? 0;
    final maintenance =
        double.tryParse(firearms?['maintenance']?.toString() ?? '0') ?? 0;

    final total = available + inCustody + maintenance;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Firearms Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Current distribution overview',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: total == 0
                ? const Center(
                    child: Text(
                      'No data available',
                      style: TextStyle(color: Color(0xFF78909C)),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedIndex = -1;
                              return;
                            }
                            _touchedIndex = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        _buildPieSection(0, available, const Color(0xFF3CCB7F)),
                        _buildPieSection(1, inCustody, const Color(0xFF42A5F5)),
                        _buildPieSection(
                            2, maintenance, const Color(0xFFFFB74D)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          _buildPieLegend(),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(int index, double value, Color color) {
    final isTouched = index == _touchedIndex;
    final fontSize = isTouched ? 16.0 : 12.0;
    final radius = isTouched ? 75.0 : 65.0;

    return PieChartSectionData(
      color: color,
      value: value,
      title: '${value.toInt()}',
      radius: radius,
      titleStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPieLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem(const Color(0xFF3CCB7F), 'Available'),
        const SizedBox(width: 16),
        _buildLegendItem(const Color(0xFF42A5F5), 'In Custody'),
        const SizedBox(width: 16),
        _buildLegendItem(const Color(0xFFFFB74D), 'Maintenance'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
      ],
    );
  }
}

class _UserActivitiesBarChart extends StatefulWidget {
  const _UserActivitiesBarChart();

  @override
  State<_UserActivitiesBarChart> createState() =>
      _UserActivitiesBarChartState();
}

class _UserActivitiesBarChartState extends State<_UserActivitiesBarChart> {
  String _selectedPeriod = 'Weekly';

  final Map<String, Color> _roleColors = {
    'admin': const Color(0xFFFFA726), // Orange
    'hq_firearm_commander': const Color(0xFF1E88E5), // Blue
    'station_commander': const Color(0xFFFFCA28), // Yellow
    'investigator': const Color(0xFFFFFFFF), // White
  };

  final Map<String, String> _roleNames = {
    'admin': 'System Admin',
    'hq_firearm_commander': 'HQ Cmdr',
    'station_commander': 'Station Cmdr',
    'investigator': 'Investigator',
  };

  String _formatDateKey(DateTime date) {
    if (_selectedPeriod == 'Daily') {
      return DateFormat('MMM d').format(date);
    } else if (_selectedPeriod == 'Weekly') {
      int week = ((date.day - date.weekday + 10) / 7).floor();
      return 'Wk $week, ${DateFormat('MMM').format(date)}';
    } else {
      return DateFormat('MMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashProvider, _) {
        final activityData = dashProvider.roleActivity;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'User Activities',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildPeriodSelector(),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 250,
                child: dashProvider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                        color: Color(0xFF1E88E5),
                      ))
                    : activityData.isEmpty
                        ? const Center(
                            child: Text(
                              'No activity recorded.',
                              style: TextStyle(color: Color(0xFF78909C)),
                            ),
                          )
                        : _buildGroupedBarChart(activityData),
              ),
              const SizedBox(height: 24),
              _buildLegend(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Daily', 'Weekly', 'Monthly'].map((period) {
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                period,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFB0BEC5),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroupedBarChart(List<dynamic> rawData) {
    final now = DateTime.now();
    final parsedMap = <String, Map<String, double>>{};
    final sortedLabels = <String>[];

    for (int i = 3; i >= 0; i--) {
      if (_selectedPeriod == 'Daily') {
        sortedLabels.add(_formatDateKey(now.subtract(Duration(days: i))));
      } else if (_selectedPeriod == 'Weekly') {
        sortedLabels.add(_formatDateKey(now.subtract(Duration(days: i * 7))));
      } else {
        sortedLabels
            .add(_formatDateKey(DateTime(now.year, now.month - i, now.day)));
      }
    }

    for (var r in _roleColors.keys) {
      parsedMap[r] = {};
      for (var label in sortedLabels) {
        parsedMap[r]![label] = 0;
      }
    }

    for (var item in rawData) {
      if (item['activity_date'] == null || item['actor_role'] == null) continue;

      final date = DateTime.tryParse(item['activity_date'].toString());
      if (date == null) continue;

      final role = item['actor_role'].toString();
      if (!_roleColors.containsKey(role)) continue;

      final val = double.tryParse(item['actions_count'].toString()) ?? 0;
      final timeKey = _formatDateKey(date);

      if (sortedLabels.contains(timeKey)) {
        parsedMap[role]![timeKey] = (parsedMap[role]![timeKey] ?? 0) + val;
      }
    }

    double maxY = 10;
    final barGroups = <BarChartGroupData>[];

    for (int i = 0; i < sortedLabels.length; i++) {
      final label = sortedLabels[i];
      final adminVal = parsedMap['admin']![label] ?? 0;
      final hqVal = parsedMap['hq_firearm_commander']![label] ?? 0;
      final stationVal = parsedMap['station_commander']![label] ?? 0;
      final investVal = parsedMap['investigator']![label] ?? 0;

      final maxInGroup = [adminVal, hqVal, stationVal, investVal]
          .fold(0.0, (a, b) => a > b ? a : b);
      if (maxInGroup > maxY) maxY = maxInGroup;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
                toY: adminVal,
                color: _roleColors['admin'],
                width: 16,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2))),
            BarChartRodData(
                toY: hqVal,
                color: _roleColors['hq_firearm_commander'],
                width: 16,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2))),
            BarChartRodData(
                toY: stationVal,
                color: _roleColors['station_commander'],
                width: 16,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2))),
            BarChartRodData(
                toY: investVal,
                color: _roleColors['investigator'],
                width: 16,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(2))),
          ],
          barsSpace: 6,
        ),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2 + 1,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String roleName = '';
              if (rodIndex == 0) {
                roleName = 'Admin';
              } else if (rodIndex == 1) {
                roleName = 'HQ Cmdr';
              } else if (rodIndex == 2) {
                roleName = 'Stn Cmdr';
              } else if (rodIndex == 3) {
                roleName = 'Investigator';
              }

              return BarTooltipItem(
                '$roleName\n${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < sortedLabels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      sortedLabels[idx],
                      style: const TextStyle(
                          color: Color(0xFF78909C), fontSize: 10),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 10),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 5).ceil().toDouble() > 0
              ? (maxY / 5).ceil().toDouble()
              : 1.0,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: Color(0xFF37404F), strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _roleColors.keys.map((role) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _roleColors[role],
              ),
            ),
            const SizedBox(width: 4),
            Text(
              _roleNames[role]!,
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11),
            ),
          ],
        );
      }).toList(),
    );
  }
}
