// Forensic Analyst Dashboard
// Dashboard for forensic analyst role - investigation and analysis center

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../auth/login_screen.dart';
import '../forensic/forensic_search_screen.dart';
import '../management/firearms_registry_screen.dart';
import '../anomaly/anomaly_detection_screen.dart';

class ForensicAnalystDashboard extends StatefulWidget {
  const ForensicAnalystDashboard({super.key});

  @override
  State<ForensicAnalystDashboard> createState() =>
      _ForensicAnalystDashboardState();
}

class _ForensicAnalystDashboardState extends State<ForensicAnalystDashboard> {
  int _selectedIndex = 0;
  String? _selectedFirearm;
  String _dateRange = 'Last 30 Days';

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
    final anomalyProvider = Provider.of<AnomalyProvider>(
      context,
      listen: false,
    );

    // Load forensic-specific dashboard data
    await Future.wait([
      dashboardProvider.loadDashboardStats(),
      anomalyProvider.loadAnomalies(limit: 15),
    ]);
  }

  // Build dynamic nav items based on provider data
  List<_NavItem> _buildNavItems(BuildContext context) {
    final anomalyProvider = Provider.of<AnomalyProvider>(context);
    final anomaliesCount = anomalyProvider.anomalies.length;

    return [
      _NavItem(icon: Icons.dashboard, label: 'Dashboard', badge: null),
      _NavItem(icon: Icons.search, label: 'Forensic Search', badge: null),
      _NavItem(icon: Icons.timeline, label: 'Custody Timeline', badge: null),
      _NavItem(icon: Icons.gps_fixed, label: 'Firearms', badge: null),
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
      floatingActionButton: _buildQuickSearchPanel(),
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
                  'Forensic Analysis',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
              ],
            ),
          ),

          // User Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2A3040),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF1E88E5),
                      radius: 20,
                      child: Text(
                        user?['full_name']
                                ?.toString()
                                .split(' ')
                                .map((e) => e[0])
                                .take(2)
                                .join() ??
                            'FA',
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
                            user?['full_name'] ?? 'Analyst K. Habimana',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Forensic Analyst',
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42A5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Cross-Unit Access',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navigation Menu
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

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
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
                    );
                  },
                );
              },
            ),
          ),

          // Access Indicator Box
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F),
              border: const Border(
                left: BorderSide(color: Color(0xFF42A5F5), width: 4),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.remove_red_eye,
                      color: Color(0xFF42A5F5),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Read-Only Access',
                      style: TextStyle(
                        color: Color(0xFFE3F2FD),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'National database view',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 11),
                ),
              ],
            ),
          ),

          // Bottom Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF37404F), width: 1),
              ),
            ),
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
                      'System Online',
                      style: TextStyle(color: Color(0xFF3CCB7F), fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Logout'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85C5C),
                      side: const BorderSide(color: Color(0xFFE85C5C)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Investigation Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Forensic / Dashboard',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
              ),
            ],
          ),
          const Spacer(),
          // Forensic Search Bar
          Container(
            width: 320,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search ballistic profiles, firearms...',
                hintStyle: const TextStyle(color: Color(0xFF78909C)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF1E88E5),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Stack(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications, color: Color(0xFF78909C)),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE85C5C),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.account_circle, color: Color(0xFF78909C)),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Navigate to different screens based on selected index
    switch (_selectedIndex) {
      case 0:
        // Dashboard - show the main investigation dashboard
        return _buildDashboardOverview();
      case 1:
        // Forensic Search
        return const ForensicSearchScreen();
      case 2:
        // Custody Timeline - embedded in dashboard for now
        return _buildCustodyTimelinePage();
      case 3:
        // Firearms with ballistic profiles
        return const FirearmsRegistryScreen();
      case 4:
        // Anomalies
        return const AnomalyDetectionScreen();
      case 5:
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
            'Forensic Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Generate forensic analysis reports',
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
                    'Forensic Reports Module',
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

  Widget _buildCustodyTimelinePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Custody Timeline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track firearm custody chain of events',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 32),
          _buildCustodyTimeline(),
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
          _buildInvestigationMetrics(),
          const SizedBox(height: 32),
          _buildActivityAndAnomalies(),
          const SizedBox(height: 32),
          _buildCustodyTimeline(),
          const SizedBox(height: 32),
          _buildBallisticMatches(),
        ],
      ),
    );
  }

  Widget _buildInvestigationMetrics() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final anomalyProvider = Provider.of<AnomalyProvider>(context);
    final dashboardStats = dashboardProvider.dashboardStats;

    final totalAnomalies = anomalyProvider.anomalies.length;
    final criticalHigh = anomalyProvider.anomalies
        .where(
          (a) => [
            'critical',
            'high',
          ].contains(a['severity']?.toString().toLowerCase()),
        )
        .length;
    final mediumLow = totalAnomalies - criticalHigh;

    return Row(
      children: [
        Expanded(child: _buildOpenInvestigationsCard()),
        const SizedBox(width: 16),
        Expanded(child: _buildBallisticProfilesCard(dashboardStats)),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFlaggedAnomaliesCard(
            totalAnomalies,
            criticalHigh,
            mediumLow,
            dashboardProvider.isLoading,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _buildCustodyTracesCard(dashboardStats)),
      ],
    );
  }

  Widget _buildOpenInvestigationsCard() {
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
          const Icon(Icons.folder_open, color: Color(0xFF1E88E5), size: 36),
          const SizedBox(height: 16),
          const Text(
            '7',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Active Investigations',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF3CCB7F),
                size: 14,
              ),
              const SizedBox(width: 4),
              const Text(
                '3 Ballistic matches',
                style: TextStyle(color: Color(0xFF3CCB7F), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.search, color: Color(0xFFFFC857), size: 14),
              const SizedBox(width: 4),
              const Text(
                '4 Pending review',
                style: TextStyle(color: Color(0xFFFFC857), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBallisticProfilesCard(Map<String, dynamic>? dashboardStats) {
    final ballisticCount =
        dashboardStats?['ballistic_profiles_count']?.toString() ?? '0';

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
          const Icon(Icons.fingerprint, color: Color(0xFF42A5F5), size: 36),
          const SizedBox(height: 16),
          Text(
            ballisticCount,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ballistic Profiles',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            'National database',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
          const Text(
            'Cross-unit searchable',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedAnomaliesCard(
    int total,
    int criticalHigh,
    int mediumLow,
    bool isLoading,
  ) {
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
          const Icon(Icons.shield, color: Color(0xFFE85C5C), size: 36),
          const SizedBox(height: 16),
          isLoading
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
            'Anomalies for Review',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE85C5C),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$criticalHigh Critical/High',
                style: const TextStyle(color: Color(0xFFE85C5C), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF42A5F5),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$mediumLow Medium/Low',
                style: const TextStyle(color: Color(0xFF42A5F5), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustodyTracesCard(Map<String, dynamic>? dashboardStats) {
    final totalCustody = dashboardStats?['total_custody_traces'] ??
        dashboardStats?['active_custody'] ??
        0;

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
          const Icon(Icons.timeline, color: Color(0xFF3CCB7F), size: 36),
          const SizedBox(height: 16),
          Text(
            totalCustody.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Custody Records Traced',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 12),
          const Text(
            'Last 30 days',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityAndAnomalies() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 60, child: _buildRecentInvestigations()),
        const SizedBox(width: 16),
        Expanded(flex: 40, child: _buildAnomalyQueue()),
      ],
    );
  }

  Widget _buildRecentInvestigations() {
    // Sample investigation data - in production, this would come from an investigations provider
    final investigations = [
      {
        'id': '#INV-2025-0089',
        'status': 'In Progress',
        'type': 'Ballistic Match Analysis',
        'firearm': 'Glock 17 - GLK-2024-0445',
        'unit': 'Nyamirambo Station',
        'analyst': 'K. Habimana',
        'priority': 'High',
        'updated': '2h ago',
        'progress': 0.65,
      },
      {
        'id': '#INV-2025-0088',
        'status': 'Completed',
        'type': 'Custody Pattern Investigation',
        'firearm': 'AK-47 - AK-2021-0892',
        'unit': 'Remera Station',
        'analyst': 'K. Habimana',
        'priority': 'Medium',
        'updated': '5h ago',
        'progress': 1.0,
      },
      {
        'id': '#INV-2025-0087',
        'status': 'Pending',
        'type': 'Cross-Unit Transfer Review',
        'firearm': 'M4 - M4-2022-0156',
        'unit': 'Training Academy',
        'analyst': 'K. Habimana',
        'priority': 'Low',
        'updated': '1d ago',
        'progress': 0.0,
      },
    ];

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Recent Investigation Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Last 7 days',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFF64B5F6), fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...investigations.map((inv) => _buildInvestigationItem(inv)),
        ],
      ),
    );
  }

  Widget _buildInvestigationItem(Map<String, dynamic> investigation) {
    final status = investigation['status'] as String;
    final Color statusColor = status == 'Completed'
        ? const Color(0xFF3CCB7F)
        : status == 'In Progress'
            ? const Color(0xFF42A5F5)
            : const Color(0xFFFFC857);

    final Color priorityColor = investigation['priority'] == 'High'
        ? const Color(0xFFFFC857)
        : investigation['priority'] == 'Medium'
            ? const Color(0xFF42A5F5)
            : const Color(0xFF78909C);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                investigation['id'] as String,
                style: const TextStyle(
                  color: Color(0xFF64B5F6),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Updated ${investigation['updated']}',
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            investigation['type'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Firearm: ${investigation['firearm']}',
                      style: const TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Analyst: ${investigation['analyst']}',
                      style: const TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unit: ${investigation['unit']}',
                      style: const TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 13,
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Priority: ',
                          style: TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            investigation['priority'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'In Progress') ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: investigation['progress'] as double,
                backgroundColor: const Color(0xFF37404F),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF1E88E5),
                ),
                minHeight: 4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'Completed'
                    ? const Color(0xFF3CCB7F)
                    : const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: Text(
                status == 'Completed' ? 'View Report' : 'Continue',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomalyQueue() {
    final anomalyProvider = Provider.of<AnomalyProvider>(context);
    final anomalies = anomalyProvider.anomalies;
    final highPriorityAnomalies = anomalies
        .where(
          (a) => [
            'critical',
            'high',
          ].contains(a['severity']?.toString().toLowerCase()),
        )
        .take(4)
        .toList();

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
                'Anomaly Investigation Queue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE85C5C),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${anomalies.length} Flagged',
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
          anomalyProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : highPriorityAnomalies.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No high-priority anomalies',
                          style: TextStyle(color: Color(0xFF78909C)),
                        ),
                      ),
                    )
                  : Column(
                      children: highPriorityAnomalies
                          .map((anomaly) => _buildAnomalyQueueItem(anomaly))
                          .toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildAnomalyQueueItem(Map<String, dynamic> anomaly) {
    final severity = anomaly['severity']?.toString().toUpperCase() ?? 'MEDIUM';
    final severityColor = _getSeverityColor(severity);
    final score =
        double.tryParse(anomaly['anomaly_score']?.toString() ?? '0.0') ?? 0.0;
    final timeAgo = _formatTimeAgo(anomaly['detected_at']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border(left: BorderSide(color: severityColor, width: 4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${anomaly['anomaly_id'] ?? 'N/A'}',
                style: const TextStyle(
                  color: Color(0xFF64B5F6),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      severity,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            anomaly['anomaly_type']?.toString() ?? 'Anomaly Detected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            anomaly['unit_name']?.toString() ?? 'N/A',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
          ),
          const SizedBox(height: 8),
          // Anomaly Score Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Anomaly Score',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 11),
                  ),
                  Text(
                    score.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF37404F),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  widthFactor: score,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFFFC857), severityColor],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E88E5),
                side: const BorderSide(color: Color(0xFF1E88E5)),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              child: const Text('Investigate', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
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

  String _formatTimeAgo(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildCustodyTimeline() {
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
                'Cross-Unit Custody Timeline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A3A),
                      border: Border.all(color: const Color(0xFF37404F)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedFirearm,
                      hint: const Text(
                        'Select Firearm',
                        style: TextStyle(color: Color(0xFFB0BEC5)),
                      ),
                      dropdownColor: const Color(0xFF252A3A),
                      underline: Container(),
                      style: const TextStyle(color: Colors.white),
                      items: const [],
                      onChanged: (value) {
                        setState(() {
                          _selectedFirearm = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A3A),
                      border: Border.all(color: const Color(0xFF37404F)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: DropdownButton<String>(
                      value: _dateRange,
                      dropdownColor: const Color(0xFF252A3A),
                      underline: Container(),
                      style: const TextStyle(color: Colors.white),
                      items: ['Last 7 Days', 'Last 30 Days', 'Last 90 Days']
                          .map(
                            (range) => DropdownMenuItem(
                              value: range,
                              child: Text(range),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _dateRange = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Empty state
          Center(
            child: Column(
              children: const [
                Icon(Icons.search, color: Color(0xFF78909C), size: 64),
                SizedBox(height: 16),
                Text(
                  'Select a firearm to view custody timeline',
                  style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Track firearm movement across units',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildBallisticMatches() {
    // Sample ballistic match data
    final matches = List.generate(6, (index) {
      final score = 94 - (index * 5);
      return {
        'id': '#BP-2024-04${45 + index}',
        'firearm': 'Glock 17 - GLK-2024-04${45 + index}',
        'pattern': 'Right twist, 1:10 ratio, 6 lands...',
        'score': score,
        'incidents': 3 - (index ~/ 2),
        'updated': '2025-12-${12 - (index % 5)}',
      };
    });

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
                'Recent Ballistic Matches',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All Profiles',
                  style: TextStyle(color: Color(0xFF64B5F6), fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(
                const Color(0xFF252A3A),
              ),
              dataRowColor: MaterialStateProperty.all(const Color(0xFF2A3040)),
              headingRowHeight: 48,
              dataRowHeight: 60,
              columnSpacing: 24,
              horizontalMargin: 0,
              columns: const [
                DataColumn(
                  label: Text(
                    'PROFILE ID',
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
                    'RIFLING PATTERN',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'MATCH SCORE',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'RELATED INCIDENTS',
                    style: TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'LAST UPDATED',
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
              rows: matches.map((match) {
                final score = match['score'] as int;
                final Color scoreColor = score > 80
                    ? const Color(0xFF3CCB7F)
                    : score > 60
                        ? const Color(0xFFFFC857)
                        : const Color(0xFFE85C5C);

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        match['id'] as String,
                        style: const TextStyle(
                          color: Color(0xFF64B5F6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          const Icon(
                            Icons.gps_fixed,
                            color: Color(0xFF78909C),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            match['firearm'] as String,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Text(
                            match['pattern'] as String,
                            style: const TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF78909C),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF37404F),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              widthFactor: score / 100,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scoreColor,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$score%',
                            style: TextStyle(
                              color: scoreColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          match['incidents'].toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Color(0xFF78909C),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            match['updated'] as String,
                            style: const TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E88E5),
                              side: const BorderSide(color: Color(0xFF1E88E5)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              minimumSize: Size.zero,
                            ),
                            child: const Text(
                              'View Profile',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.compare_arrows,
                              color: Color(0xFF78909C),
                              size: 20,
                            ),
                            tooltip: 'Compare',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearchPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Search',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 280,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Search Ballistic Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E88E5),
                side: const BorderSide(color: Color(0xFF1E88E5)),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.timeline, size: 18),
              label: const Text('Trace Custody History'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E88E5),
                side: const BorderSide(color: Color(0xFF1E88E5)),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.gps_fixed, size: 18),
              label: const Text('Find Firearm'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1E88E5),
                side: const BorderSide(color: Color(0xFF1E88E5)),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.centerLeft,
              ),
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

  _NavItem({
    required this.icon,
    required this.label,
    this.badge,
    this.badgeColor,
  });
}
