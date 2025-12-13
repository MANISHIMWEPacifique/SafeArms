// Admin Dashboard
// Dashboard for admin role

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../auth/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final dashboardProvider = Provider.of<DashboardProvider>(
      context,
      listen: false,
    );
    final anomalyProvider = Provider.of<AnomalyProvider>(
      context,
      listen: false,
    );

    // Load all dashboard data
    await Future.wait([
      dashboardProvider.loadDashboardStats(),
      dashboardProvider.loadTotalUsersCount(),
      dashboardProvider.loadActiveUnitsCount(),
      anomalyProvider.loadAnomalies(limit: 10),
    ]);
  }

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard, label: 'Dashboard'),
    _NavItem(icon: Icons.business, label: 'Units'),
    _NavItem(icon: Icons.people, label: 'Users'),
    _NavItem(icon: Icons.settings, label: 'System Settings'),
    _NavItem(icon: Icons.assessment, label: 'Reports'),
    _NavItem(icon: Icons.warning_amber, label: 'Anomaly Summary'),
  ];

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
          // Side Navigation
          _buildSideNavigation(),
          // Main Content
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
                    color: const Color(0xFF78909C).withOpacity(0.2),
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
                  radius: 20,
                  backgroundColor: const Color(0xFF1E88E5),
                  child: Text(
                    (user?['full_name'] ?? 'A')[0].toUpperCase(),
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
                        user?['full_name'] ?? 'Admin User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'System Administrator',
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

          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
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
                            Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFB0BEC5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // System Status
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
                      'System Healthy',
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
          const Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF78909C)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF78909C),
                ),
                onPressed: () {},
              ),
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
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {},
            icon: const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF1E88E5),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
            label: const Row(
              children: [
                SizedBox(width: 8),
                Text(
                  'Admin',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Color(0xFF78909C),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards Row
          _buildStatsCards(),
          const SizedBox(height: 32),

          // Charts Section
          _buildChartsSection(),
          const SizedBox(height: 32),

          // Anomaly Table
          _buildAnomalyTable(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    final totalUsers = dashboardProvider.totalUsersCount ?? 0;
    final activeUnits = dashboardProvider.activeUnitsCount ?? 0;
    final anomaliesData =
        dashboardProvider.dashboardStats?['anomalies'] as List?;

    int totalAnomalies = 0, critical = 0, high = 0;
    if (anomaliesData != null) {
      for (var item in anomaliesData) {
        final count = int.tryParse(item['count']?.toString() ?? '0') ?? 0;
        final severity = item['severity']?.toString().toLowerCase() ?? '';
        totalAnomalies += count;
        if (severity == 'critical')
          critical = count;
        else if (severity == 'high') high = count;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            iconColor: const Color(0xFF42A5F5),
            number: totalUsers.toString(),
            label: 'Total Users',
            trend: '',
            trendColor: const Color(0xFF78909C),
            showUpArrow: false,
            isLoading: dashboardProvider.isLoading,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.business,
            iconColor: const Color(0xFF1E88E5),
            number: activeUnits.toString(),
            label: 'Active Units',
            trend: 'Nationwide',
            trendColor: const Color(0xFF78909C),
            showUpArrow: false,
            isLoading: dashboardProvider.isLoading,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.favorite,
            iconColor: const Color(0xFF3CCB7F),
            number: 'Healthy',
            label: 'System Status',
            trend: '99.8% uptime',
            trendColor: const Color(0xFF78909C),
            showUpArrow: false,
            isLoading: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.warning_amber,
            iconColor: const Color(0xFFFFC857),
            number: totalAnomalies.toString(),
            label: 'Anomalies (30 days)',
            trend: '$critical critical, $high high',
            trendColor: const Color(0xFFE85C5C),
            showUpArrow: false,
            isLoading: dashboardProvider.isLoading,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String number,
    required String label,
    required String trend,
    required Color trendColor,
    required bool showUpArrow,
    bool isLoading = false,
  }) {
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
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 16),
          isLoading
              ? const CircularProgressIndicator()
              : Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (showUpArrow)
                Icon(Icons.arrow_upward, color: trendColor, size: 12),
              if (showUpArrow) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  trend,
                  style: TextStyle(color: trendColor, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Activity Chart (60%)
        Expanded(
          flex: 6,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Activity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Last 7 days',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                ),
                const SizedBox(height: 24),
                // Placeholder for chart
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'Chart Placeholder\n(Use fl_chart package for line chart)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Recent Actions (40%)
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Actions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecentAction(
                  Icons.person_add,
                  const Color(0xFF3CCB7F),
                  'User created',
                  'John Doe created HQ Commander account',
                  '2 mins ago',
                ),
                _buildRecentAction(
                  Icons.edit,
                  const Color(0xFF42A5F5),
                  'Unit updated',
                  'Nyamirambo Station details modified',
                  '15 mins ago',
                ),
                _buildRecentAction(
                  Icons.settings,
                  const Color(0xFF1E88E5),
                  'Settings changed',
                  '2FA settings updated',
                  '1 hour ago',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentAction(
    IconData icon,
    Color iconColor,
    String title,
    String description,
    String time,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 13,
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
          const Text(
            'ML Anomaly Detection Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Top anomalies requiring attention',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(1.5),
              5: FlexColumnWidth(1.5),
              6: FlexColumnWidth(1.5),
            },
            children: [
              // Header Row
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFF252A3A)),
                children: [
                  _buildTableHeader('ANOMALY ID'),
                  _buildTableHeader('TYPE'),
                  _buildTableHeader('SEVERITY'),
                  _buildTableHeader('UNIT'),
                  _buildTableHeader('DETECTED'),
                  _buildTableHeader('STATUS'),
                  _buildTableHeader('ACTION'),
                ],
              ),
              // Sample Data Rows
              _buildAnomalyRow(
                'A2024-1127',
                'Rapid Exchange',
                'CRITICAL',
                const Color(0xFFE85C5C),
                'Nyamirambo Station',
                'Dec 11, 14:23',
                'Under Review',
                const Color(0xFF42A5F5),
              ),
              _buildAnomalyRow(
                'A2024-1126',
                'Night Issue',
                'HIGH',
                const Color(0xFFFFC857),
                'Kigali HQ',
                'Dec 11, 02:15',
                'Detected',
                const Color(0xFFFFC857),
              ),
              _buildAnomalyRow(
                'A2024-1125',
                'Extended Custody',
                'MEDIUM',
                const Color(0xFF42A5F5),
                'Kimironko Station',
                'Dec 10, 18:30',
                'Resolved',
                const Color(0xFF3CCB7F),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB0BEC5),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  TableRow _buildAnomalyRow(
    String id,
    String type,
    String severity,
    Color severityColor,
    String unit,
    String detected,
    String status,
    Color statusColor,
  ) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      children: [
        _buildTableCell(id),
        _buildTableCell(type),
        _buildTableBadge(severity, severityColor),
        _buildTableCell(unit),
        _buildTableCell(detected),
        _buildTableBadge(status, statusColor),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'View Details',
              style: TextStyle(color: Color(0xFF64B5F6), fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }

  Widget _buildTableBadge(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color == const Color(0xFFFFC857)
                ? const Color(0xFF1A1F2E)
                : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  _NavItem({required this.icon, required this.label});
}
