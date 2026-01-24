// HQ Commander Dashboard
// Dashboard for HQ firearm commander role

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/firearm_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../../providers/approval_provider.dart';
import '../auth/login_screen.dart';
import '../management/units_management_screen.dart';
import '../management/firearms_registry_screen.dart';
import '../management/ballistic_profiles_screen.dart';
import '../workflows/approvals_portal_screen.dart';
import '../anomaly/anomaly_detection_screen.dart';

class HqCommanderDashboard extends StatefulWidget {
  const HqCommanderDashboard({super.key});

  @override
  State<HqCommanderDashboard> createState() => _HqCommanderDashboardState();
}

class _HqCommanderDashboardState extends State<HqCommanderDashboard> {
  int _selectedIndex = 0;
  int _currentPage = 1;

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

    // Load all dashboard data - single API call for main stats
    await Future.wait([
      dashboardProvider.loadDashboardStats(),
      firearmsProvider.loadStats(),
      anomalyProvider.loadAnomalies(limit: 10),
      approvalProvider.loadPendingApprovals(),
    ]);
  }

  // Build dynamic nav items based on provider data
  List<_NavItem> _buildNavItems(BuildContext context) {
    final approvalProvider = Provider.of<ApprovalProvider>(context);
    final anomalyProvider = Provider.of<AnomalyProvider>(context);

    // Calculate pending approvals total
    final pendingApprovals = approvalProvider.pendingApprovals;
    final lossReports =
        int.tryParse(pendingApprovals?['loss_reports']?.toString() ?? '0') ?? 0;
    final destruction = int.tryParse(
            pendingApprovals?['destruction_requests']?.toString() ?? '0') ??
        0;
    final procurement = int.tryParse(
            pendingApprovals?['procurement_requests']?.toString() ?? '0') ??
        0;
    final totalPendingApprovals = lossReports + destruction + procurement;

    // Get anomalies count
    final anomaliesCount = anomalyProvider.anomalies.length;

    return [
      _NavItem(icon: Icons.dashboard, label: 'Dashboard', badge: null),
      _NavItem(icon: Icons.business, label: 'Units', badge: null),
      _NavItem(icon: Icons.gps_fixed, label: 'Firearms', badge: null),
      _NavItem(
          icon: Icons.track_changes, label: 'Ballistic Profiles', badge: null),
      _NavItem(
        icon: Icons.check_circle_outline,
        label: 'Approvals',
        badge:
            totalPendingApprovals > 0 ? totalPendingApprovals.toString() : null,
        badgeColor: const Color(0xFFE85C5C),
      ),
      _NavItem(
        icon: Icons.warning_amber,
        label: 'Anomalies',
        badge: anomaliesCount > 0 ? anomaliesCount.toString() : null,
        badgeColor: const Color(0xFFFFC857),
      ),
      _NavItem(icon: Icons.assessment, label: 'Reports', badge: null),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'SafeArms',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'HQ Command',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
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
                  radius: 20,
                  backgroundColor: const Color(0xFF1E88E5),
                  child: Text(
                    (user?['full_name'] ?? 'C')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
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
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF78909C),
                                  size: 20,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Home / Dashboard',
                style: TextStyle(color: const Color(0xFF78909C), fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF78909C)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (context) {
              final anomalyProvider = Provider.of<AnomalyProvider>(context);
              final notificationCount = anomalyProvider.anomalies.length;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFF78909C),
                    ),
                    onPressed: () {
                      // Navigate to anomalies
                      setState(() {
                        _selectedIndex = 5;
                      });
                    },
                  ),
                  if (notificationCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE85C5C),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          notificationCount > 9 ? '9+' : '$notificationCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          Builder(
            builder: (context) {
              final authProvider = Provider.of<AuthProvider>(context);
              final userName = authProvider.userName ?? 'Commander';
              return TextButton.icon(
                onPressed: () {},
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
        // Ballistic Profiles
        return const BallisticProfilesScreen();
      case 4:
        // Approvals Portal
        return const ApprovalsPortalScreen();
      case 5:
        // Anomalies Detection
        return const AnomalyDetectionScreen();
      case 6:
        // Reports
        return _buildReportsPlaceholder();
      default:
        return _buildDashboardOverview();
    }
  }

  Widget _buildReportsPlaceholder() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate and view system reports',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assessment, size: 64, color: Color(0xFF78909C)),
                  SizedBox(height: 16),
                  Text(
                    'Reports Module',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Coming soon...',
                    style: TextStyle(color: Color(0xFF78909C)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 32),
          _buildChartsSection(),
          const SizedBox(height: 32),
          _buildAnomalyTable(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildTotalFirearmsCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildPendingApprovalsCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildActiveUnitsCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildAnomaliesCard()),
        ],
      ),
    );
  }

  Widget _buildTotalFirearmsCard() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final dashboardStats = dashboardProvider.dashboardStats;
    final firearmsData = dashboardStats?['firearms'];
    final total = firearmsData?['total']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.gps_fixed, color: Color(0xFF1E88E5), size: 36),
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
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
    final lossReports =
        int.tryParse(pendingApprovals?['loss_reports']?.toString() ?? '0') ?? 0;
    final destruction = int.tryParse(
          pendingApprovals?['destruction_requests']?.toString() ?? '0',
        ) ??
        0;
    final procurement = int.tryParse(
          pendingApprovals?['procurement_requests']?.toString() ?? '0',
        ) ??
        0;
    final total = lossReports + destruction + procurement;

    return Container(
      padding: const EdgeInsets.all(24),
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
              const Icon(Icons.schedule, color: Color(0xFFFFC857), size: 36),
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.business, color: Color(0xFF42A5F5), size: 36),
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          const Text(
            '2 Special Units',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
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
        if (severity == 'critical')
          critical = count;
        else if (severity == 'high')
          high = count;
        else if (severity == 'medium' || severity == 'low') medium += count;
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFFE85C5C), size: 36),
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 65, child: _buildDistributionChart()),
        const SizedBox(width: 16),
        Expanded(flex: 35, child: _buildApprovalQueue()),
      ],
    );
  }

  Widget _buildDistributionChart() {
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
            'Firearm Distribution by Unit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Top 10 Units',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                'Horizontal Bar Chart Placeholder\n(Use fl_chart package)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalQueue() {
    final approvalProvider = Provider.of<ApprovalProvider>(context);
    final pendingApprovals = approvalProvider.pendingApprovals;
    final lossReports =
        int.tryParse(pendingApprovals?['loss_reports']?.toString() ?? '0') ?? 0;
    final destruction = int.tryParse(
            pendingApprovals?['destruction_requests']?.toString() ?? '0') ??
        0;
    final procurement = int.tryParse(
            pendingApprovals?['procurement_requests']?.toString() ?? '0') ??
        0;
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
          _buildApprovalItem(
            Icons.close,
            const Color(0xFFE85C5C),
            'Loss Report',
            'Nyamirambo Station',
            'Glock 17 - GLK-2024-0445',
            '2 hours ago',
            true,
          ),
          _buildApprovalItem(
            Icons.delete_outline,
            const Color(0xFFFFC857),
            'Destruction Request',
            'Remera Station',
            'AK-47 - AK-2019-0234',
            '5 hours ago',
            false,
          ),
          _buildApprovalItem(
            Icons.add_circle_outline,
            const Color(0xFF3CCB7F),
            'Procurement Request',
            'Training Academy',
            '10 x Glock 17',
            '1 day ago',
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalItem(
    IconData icon,
    Color color,
    String type,
    String unit,
    String firearm,
    String time,
    bool isUrgent,
  ) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 13,
                  ),
                ),
                Text(
                  firearm,
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Review',
                      style: TextStyle(color: Colors.white, fontSize: 13),
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

  Widget _buildAnomalyTable() {
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
                'ML Anomaly Alerts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A3A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF37404F)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Last 7 Days',
                          style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Color(0xFF78909C),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'View All',
                      style: TextStyle(color: Color(0xFF64B5F6), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFF252A3A),
              ),
              dataRowColor: WidgetStateProperty.all(const Color(0xFF2A3040)),
              headingRowHeight: 48,
              dataRowMinHeight: 60,
              dataRowMaxHeight: 60,
              columnSpacing: 24,
              horizontalMargin: 16,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              columns: const [
                DataColumn(
                  label: Text(
                    'ANOMALY ID',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'TYPE',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'SEVERITY',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'UNIT',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'OFFICER',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'FIREARM',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'DETECTED',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'STATUS',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACTION',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              rows: _buildAnomalyRows(),
            ),
          ),
          const SizedBox(height: 16),
          _buildPagination(),
        ],
      ),
    );
  }

  List<DataRow> _buildAnomalyRows() {
    final anomalyProvider = Provider.of<AnomalyProvider>(context);
    final anomalies = anomalyProvider.anomalies;

    if (anomalyProvider.isLoading) {
      return [
        const DataRow(
          cells: [
            DataCell(CircularProgressIndicator()),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
          ],
        ),
      ];
    }

    if (anomalies.isEmpty) {
      return [
        const DataRow(
          cells: [
            DataCell(
              Text(
                'No anomalies found',
                style: TextStyle(color: Color(0xFFB0BEC5)),
              ),
            ),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
            DataCell(Text('')),
          ],
        ),
      ];
    }

    return anomalies.map((anomaly) {
      final severityColor = _getSeverityColor(
        anomaly['severity']?.toString() ?? '',
      );
      final statusColor = _getStatusColor(anomaly['status']?.toString() ?? '');

      return _buildAnomalyRow(
        '#${anomaly['anomaly_id']?.toString() ?? 'N/A'}',
        anomaly['anomaly_type']?.toString() ?? 'Unknown',
        anomaly['severity']?.toString().toUpperCase() ?? 'N/A',
        severityColor,
        anomaly['unit_name']?.toString() ?? 'N/A',
        anomaly['officer_name']?.toString() ?? 'N/A',
        anomaly['firearm_serial']?.toString() ?? 'N/A',
        _formatDateTime(anomaly['detected_at']?.toString()),
        anomaly['status']?.toString() ?? 'N/A',
        statusColor,
      );
    }).toList();
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFE85C5C);
      case 'high':
        return const Color(0xFFFFC857);
      case 'medium':
      case 'low':
      default:
        return const Color(0xFF42A5F5);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'detected':
        return const Color(0xFFFFC857);
      case 'under review':
      case 'under_review':
        return const Color(0xFF42A5F5);
      case 'resolved':
        return const Color(0xFF3CCB7F);
      default:
        return const Color(0xFF78909C);
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (e) {
      return dateTime;
    }
  }

  DataRow _buildAnomalyRow(
    String id,
    String type,
    String severity,
    Color severityColor,
    String unit,
    String officer,
    String firearm,
    String detected,
    String status,
    Color statusColor,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            id,
            style: const TextStyle(color: Color(0xFF64B5F6), fontSize: 14),
          ),
        ),
        DataCell(
          Text(type, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: severityColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              severity,
              style: TextStyle(
                color: severityColor == const Color(0xFFFFC857)
                    ? const Color(0xFF1A1F2E)
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            unit,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
        ),
        DataCell(
          Text(
            officer,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        DataCell(
          Text(
            firearm,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ),
        DataCell(
          Text(
            detected,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor == const Color(0xFFFFC857)
                    ? const Color(0xFF1A1F2E)
                    : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        DataCell(
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1E88E5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: const Text(
              'Investigate',
              style: TextStyle(color: Color(0xFF1E88E5), fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF78909C)),
          onPressed:
              _currentPage > 1 ? () => setState(() => _currentPage--) : null,
        ),
        for (int i = 1; i <= 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => setState(() => _currentPage = i),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _currentPage == i
                      ? const Color(0xFF1E88E5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$i',
                  style: TextStyle(
                    color: _currentPage == i
                        ? Colors.white
                        : const Color(0xFFB0BEC5),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Color(0xFF78909C)),
          onPressed:
              _currentPage < 3 ? () => setState(() => _currentPage++) : null,
        ),
      ],
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
