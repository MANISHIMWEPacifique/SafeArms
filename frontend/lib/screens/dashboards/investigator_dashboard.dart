// Investigator Dashboard
// Dashboard for investigator role - investigation and analysis center
// All data is fetched from backend APIs - no hardcoded/dummy data

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../../services/firearm_service.dart';
import '../../services/forensic_traceability_service.dart';
import '../../models/firearm_model.dart';
import '../../widgets/custody_timeline_widget.dart';
import '../auth/login_screen.dart';
import '../forensic/forensic_search_screen.dart';
import '../management/firearms_registry_screen.dart';
import '../workflows/reports_screen.dart';
import '../anomaly/anomaly_detection_screen.dart';

class InvestigatorDashboard extends StatefulWidget {
  const InvestigatorDashboard({super.key});

  @override
  State<InvestigatorDashboard> createState() => _InvestigatorDashboardState();
}

class _InvestigatorDashboardState extends State<InvestigatorDashboard> {
  int _selectedIndex = 0;

  // Custody Timeline search state
  final TextEditingController _firearmSearchController =
      TextEditingController();
  final FirearmService _firearmService = FirearmService();
  final ForensicTraceabilityService _traceabilityService =
      ForensicTraceabilityService();
  List<FirearmModel> _firearmSearchResults = [];
  bool _isSearchingFirearms = false;
  FirearmModel? _selectedFirearmForTimeline;
  bool _isLoadingTimeline = false;
  List<Map<String, dynamic>> _custodyTimelineData = [];
  Map<String, dynamic>? _custodyTimelineSummary;
  String? _timelineError;

  @override
  void initState() {
    super.initState();
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

    await Future.wait([
      dashboardProvider.loadDashboardStats(),
      anomalyProvider.loadAnomalies(limit: 15),
    ]);
  }

  @override
  void dispose() {
    _firearmSearchController.dispose();
    super.dispose();
  }

  Future<void> _searchFirearmsForTimeline(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _firearmSearchResults = [];
      });
      return;
    }

    setState(() => _isSearchingFirearms = true);

    try {
      final results = await _firearmService.searchFirearms(query.trim());
      if (mounted) {
        setState(() {
          _firearmSearchResults = results;
          _isSearchingFirearms = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _firearmSearchResults = [];
          _isSearchingFirearms = false;
        });
      }
    }
  }

  Future<void> _loadCustodyTimelineForFirearm(FirearmModel firearm) async {
    setState(() {
      _selectedFirearmForTimeline = firearm;
      _isLoadingTimeline = true;
      _timelineError = null;
      _firearmSearchResults = [];
    });

    try {
      final response =
          await _traceabilityService.getCustodyTimeline(firearm.firearmId);
      final timelineData = response['timeline'];
      if (mounted) {
        setState(() {
          _custodyTimelineData = timelineData is List
              ? List<Map<String, dynamic>>.from(timelineData)
              : [];
          _custodyTimelineSummary =
              response['summary'] as Map<String, dynamic>?;
          _isLoadingTimeline = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _timelineError = 'Unable to load custody timeline';
          _isLoadingTimeline = false;
        });
      }
    }
  }

  List<_NavItem> _buildNavItems(BuildContext context) {
    final anomalyProvider = Provider.of<AnomalyProvider>(context);
    final anomaliesCount = anomalyProvider.anomalies.length;

    return [
      _NavItem(icon: Icons.dashboard, label: 'Dashboard', badge: null),
      _NavItem(icon: Icons.search, label: 'Investigation Search', badge: null),
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
    );
  }

  // =====================================
  // SIDE NAVIGATION
  // =====================================

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
                Text(
                  user?['full_name'] ?? 'Investigator',
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                            'IN',
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
                            user?['full_name'] ?? 'Investigator',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Investigator',
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

  // =====================================
  // TOP NAV BAR
  // =====================================

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

  // =====================================
  // MAIN CONTENT ROUTING
  // =====================================

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardOverview();
      case 1:
        return const ForensicSearchScreen();
      case 2:
        return _buildCustodyTimelinePage();
      case 3:
        return const FirearmsRegistryScreen();
      case 4:
        return const AnomalyDetectionScreen();
      case 5:
        return const ReportsScreen(roleType: 'investigator');
      default:
        return _buildDashboardOverview();
    }
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
            'Track firearm custody chain of events across all units',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 32),
          _buildCustodyTimeline(),
        ],
      ),
    );
  }

  // =====================================
  // DASHBOARD OVERVIEW (Tab 0) - ALL REAL DATA
  // =====================================

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
          _buildRecentCustodyEvents(),
          const SizedBox(height: 32),
          _buildBallisticProfilesTable(),
        ],
      ),
    );
  }

  // =====================================
  // METRIC CARDS - ALL FROM BACKEND
  // =====================================

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
        Expanded(
          child: _buildActiveCasesCard(
            dashboardStats,
            dashboardProvider.isLoading,
          ),
        ),
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

  /// Card 1: Active Cases - loss reports pending + anomalies needing review
  Widget _buildActiveCasesCard(
    Map<String, dynamic>? dashboardStats,
    bool isLoading,
  ) {
    final lossReports = dashboardStats?['loss_reports_summary'];
    final pendingAnomalies = dashboardStats?['pending_anomalies_summary'];

    final pendingLoss =
        int.tryParse(lossReports?['pending']?.toString() ?? '0') ?? 0;
    final openAnomalies = int.tryParse(
          pendingAnomalies?['total']?.toString() ?? '0',
        ) ??
        0;
    final mandatoryPending = int.tryParse(
          pendingAnomalies?['mandatory_pending']?.toString() ?? '0',
        ) ??
        0;
    final totalActive = pendingLoss + openAnomalies;

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
          isLoading
              ? const SizedBox(
                  height: 36,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Text(
                  totalActive.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          const SizedBox(height: 4),
          const Text(
            'Items Requiring Review',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.report_problem,
                color: Color(0xFFFFC857),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '$pendingLoss Loss reports pending',
                style: const TextStyle(color: Color(0xFFFFC857), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.policy, color: Color(0xFFE85C5C), size: 14),
              const SizedBox(width: 4),
              Text(
                '$mandatoryPending Mandatory reviews',
                style: const TextStyle(color: Color(0xFFE85C5C), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card 2: Ballistic Profiles - real count from backend
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

  /// Card 3: Flagged Anomalies - real from anomaly provider
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
              ? const SizedBox(
                  height: 36,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
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

  /// Card 4: Custody Records Traced - real count from backend
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
            'All units nationwide',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // =====================================
  // RECENT ACTIVITY + ANOMALY QUEUE
  // =====================================

  Widget _buildActivityAndAnomalies() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 60, child: _buildRecentActivitySection()),
        const SizedBox(width: 16),
        Expanded(flex: 40, child: _buildAnomalyQueue()),
      ],
    );
  }

  /// Recent Activity - uses real audit logs from backend
  Widget _buildRecentActivitySection() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final dashboardStats = dashboardProvider.dashboardStats;
    final recentActivities =
        (dashboardStats?['recent_activities'] as List<dynamic>?) ?? [];

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
                    'Recent System Activity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Audit trail across all units',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadDashboardData,
                icon: const Icon(Icons.refresh, color: Color(0xFF78909C)),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dashboardProvider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (recentActivities.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No recent activity recorded',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else
            ...recentActivities
                .take(6)
                .map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(dynamic activity) {
    final actionType = activity['action_type']?.toString() ?? 'UNKNOWN';
    final tableName = activity['table_name']?.toString() ?? '';
    final actorName = activity['actor_name']?.toString() ?? 'System';
    final createdAt = activity['created_at']?.toString();
    final subjectDesc = activity['subject_description']?.toString() ?? '';
    final timeAgo = _formatTimeAgo(createdAt);

    // Determine icon and color by action type
    IconData actIcon;
    Color actColor;
    String actLabel;

    switch (actionType.toUpperCase()) {
      case 'CUSTODY_ASSIGN':
      case 'CUSTODY_RETURN':
        actIcon = Icons.swap_horiz;
        actColor = const Color(0xFF42A5F5);
        actLabel = actionType == 'CUSTODY_ASSIGN'
            ? 'Custody Assigned'
            : 'Custody Returned';
        break;
      case 'BALLISTIC_ACCESS':
        actIcon = Icons.fingerprint;
        actColor = const Color(0xFFFFC857);
        actLabel = 'Ballistic Access';
        break;
      case 'CREATE':
        actIcon = Icons.add_circle_outline;
        actColor = const Color(0xFF3CCB7F);
        actLabel = 'Record Created';
        break;
      case 'UPDATE':
        actIcon = Icons.edit;
        actColor = const Color(0xFF42A5F5);
        actLabel = 'Record Updated';
        break;
      case 'LOGIN':
        actIcon = Icons.login;
        actColor = const Color(0xFF78909C);
        actLabel = 'User Login';
        break;
      case 'SEARCH':
        actIcon = Icons.search;
        actColor = const Color(0xFF42A5F5);
        actLabel = 'Search Performed';
        break;
      default:
        actIcon = Icons.info_outline;
        actColor = const Color(0xFF78909C);
        actLabel = actionType.replaceAll('_', ' ');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border(left: BorderSide(color: actColor, width: 4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: actColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(actIcon, color: actColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tableName.isNotEmpty ? '[$tableName] ' : ''}$subjectDesc',
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'By $actorName',
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeAgo,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// Anomaly Investigation Queue - real data from anomaly provider
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
          if (anomalies.length > 4) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 4; // Navigate to anomalies tab
                  });
                },
                child: Text(
                  'View all ${anomalies.length} anomalies',
                  style: const TextStyle(
                    color: Color(0xFF64B5F6),
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
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
            '${anomaly['serial_number'] ?? ''} - ${anomaly['unit_name'] ?? 'N/A'}',
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
                  widthFactor: score.clamp(0.0, 1.0),
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
              onPressed: () {
                setState(() {
                  _selectedIndex = 4; // Go to anomalies tab
                });
              },
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

  // =====================================
  // RECENT CUSTODY EVENTS - REAL DATA
  // =====================================

  Widget _buildRecentCustodyEvents() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final dashboardStats = dashboardProvider.dashboardStats;
    final custodyEvents =
        (dashboardStats?['recent_custody_events'] as List<dynamic>?) ?? [];

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
                'Recent Custody Events',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 2; // Custody Timeline tab
                  });
                },
                child: const Text(
                  'View Full Timeline',
                  style: TextStyle(color: Color(0xFF64B5F6), fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dashboardProvider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (custodyEvents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No recent custody events',
                  style: TextStyle(color: Color(0xFF78909C)),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF252A3A),
                ),
                dataRowColor: WidgetStateProperty.all(const Color(0xFF2A3040)),
                headingRowHeight: 48,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 56,
                columnSpacing: 20,
                columns: const [
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
                      'ISSUED',
                      style: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: custodyEvents.take(8).map<DataRow>((event) {
                  final custodyStatus =
                      event['custody_status']?.toString() ?? 'active';
                  final isActive = custodyStatus == 'active';
                  final statusColor = isActive
                      ? const Color(0xFF3CCB7F)
                      : const Color(0xFF78909C);

                  return DataRow(
                    cells: [
                      DataCell(
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
                            isActive ? 'Active' : 'Returned',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.gps_fixed,
                              color: Color(0xFF78909C),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${event['manufacturer'] ?? ''} ${event['model'] ?? ''}\n${event['serial_number'] ?? ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          event['officer_name']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          event['unit_name']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF37404F),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (event['custody_type']?.toString() ?? '')
                                .replaceAll('_', ' '),
                            style: const TextStyle(
                              color: Color(0xFFB0BEC5),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatTimeAgo(event['issued_at']?.toString()),
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 13,
                          ),
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

  // =====================================
  // BALLISTIC PROFILES TABLE - REAL DATA
  // Shows the 5 ballistic profile characteristics:
  // 1. Firing Pin Shape and Pattern
  // 2. Caliber and Chambering Specification
  // 3. Barrel Rifling Specifications
  // 4. Chamber and Feed System Description
  // 5. Breech Face Impression Pattern (ejector + extractor marks)
  // =====================================

  Widget _buildBallisticProfilesTable() {
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final dashboardStats = dashboardProvider.dashboardStats;
    final profiles =
        (dashboardStats?['recent_ballistic_profiles'] as List<dynamic>?) ?? [];

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
                    'Ballistic Profiles Database',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Registered firearm ballistic characteristics for investigative traceability',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 13),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 1; // Investigation Search
                  });
                },
                icon: const Icon(Icons.search, size: 16),
                label: const Text(
                  'Search Profiles',
                  style: TextStyle(color: Color(0xFF64B5F6), fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Legend for the 5 ballistic characteristics
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildCharacteristicLegend(
                Icons.radio_button_checked,
                'Firing Pin',
                const Color(0xFFFFC857),
              ),
              _buildCharacteristicLegend(
                Icons.straighten,
                'Caliber',
                const Color(0xFF42A5F5),
              ),
              _buildCharacteristicLegend(
                Icons.rotate_right,
                'Rifling',
                const Color(0xFF3CCB7F),
              ),
              _buildCharacteristicLegend(
                Icons.settings,
                'Chamber/Feed',
                const Color(0xFFCE93D8),
              ),
              _buildCharacteristicLegend(
                Icons.blur_circular,
                'Breech Face',
                const Color(0xFFE85C5C),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dashboardProvider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (profiles.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.fingerprint, color: Color(0xFF78909C), size: 48),
                    SizedBox(height: 12),
                    Text(
                      'No ballistic profiles registered',
                      style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF252A3A),
                ),
                dataRowColor: WidgetStateProperty.all(const Color(0xFF2A3040)),
                headingRowHeight: 48,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 64,
                columnSpacing: 20,
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
                      'CALIBER',
                      style: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'FIRING PIN',
                      style: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'RIFLING',
                      style: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'CHAMBER/FEED',
                      style: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'BREECH FACE',
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
                      'INTEGRITY',
                      style: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                rows: profiles.map<DataRow>((profile) {
                  final isLocked = profile['is_locked'] == true;
                  final hasHash = profile['registration_hash'] != null &&
                      profile['registration_hash'].toString().isNotEmpty;

                  return DataRow(
                    cells: [
                      // Profile ID
                      DataCell(
                        Text(
                          profile['ballistic_id']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            color: Color(0xFF64B5F6),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Firearm info
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.gps_fixed,
                                  color: Color(0xFF78909C),
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${profile['manufacturer'] ?? ''} ${profile['model'] ?? ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              profile['serial_number']?.toString() ?? '',
                              style: const TextStyle(
                                color: Color(0xFF78909C),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Caliber & Chambering (characteristic #2)
                      DataCell(
                        Text(
                          profile['caliber']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Firing Pin Impression (characteristic #1)
                      DataCell(
                        _buildCharacteristicCell(
                          profile['firing_pin_impression']?.toString(),
                          const Color(0xFFFFC857),
                        ),
                      ),
                      // Rifling Characteristics (characteristic #3)
                      DataCell(
                        _buildCharacteristicCell(
                          profile['rifling_characteristics']?.toString(),
                          const Color(0xFF3CCB7F),
                        ),
                      ),
                      // Chamber Marks / Feed System (characteristic #4)
                      DataCell(
                        _buildCharacteristicCell(
                          profile['chamber_marks']?.toString(),
                          const Color(0xFFCE93D8),
                        ),
                      ),
                      // Breech Face / Ejector+Extractor Marks (characteristic #5)
                      DataCell(
                        _buildCharacteristicCell(
                          _combineBreechFaceData(
                            profile['ejector_marks']?.toString(),
                            profile['extractor_marks']?.toString(),
                          ),
                          const Color(0xFFE85C5C),
                        ),
                      ),
                      // Assigned Unit
                      DataCell(
                        Text(
                          profile['assigned_unit_name']?.toString() ?? 'N/A',
                          style: const TextStyle(
                            color: Color(0xFFB0BEC5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Integrity status
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLocked && hasHash
                                  ? Icons.verified
                                  : Icons.warning_amber,
                              color: isLocked && hasHash
                                  ? const Color(0xFF3CCB7F)
                                  : const Color(0xFFFFC857),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isLocked && hasHash ? 'Verified' : 'Unverified',
                              style: TextStyle(
                                color: isLocked && hasHash
                                    ? const Color(0xFF3CCB7F)
                                    : const Color(0xFFFFC857),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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

  Widget _buildCharacteristicLegend(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCharacteristicCell(String? value, Color color) {
    if (value == null || value.isEmpty || value == 'null') {
      return const Text(
        'Not recorded',
        style: TextStyle(
          color: Color(0xFF546E7A),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Truncate long values for table display
    final display = value.length > 30 ? '${value.substring(0, 30)}...' : value;

    return Tooltip(
      message: value,
      child: Text(
        display,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String? _combineBreechFaceData(
    String? ejectorMarks,
    String? extractorMarks,
  ) {
    final parts = <String>[];
    if (ejectorMarks != null &&
        ejectorMarks.isNotEmpty &&
        ejectorMarks != 'null') {
      parts.add(ejectorMarks);
    }
    if (extractorMarks != null &&
        extractorMarks.isNotEmpty &&
        extractorMarks != 'null') {
      parts.add(extractorMarks);
    }
    return parts.isNotEmpty ? parts.join(' / ') : null;
  }

  // =====================================
  // CUSTODY TIMELINE - SEARCHABLE FIREARM FINDER
  // =====================================

  Widget _buildCustodyTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cross-Unit Custody Timeline',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Search for any firearm nationwide by serial number, manufacturer, model, or caliber',
                style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _firearmSearchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      decoration: InputDecoration(
                        hintText:
                            'Type serial number, manufacturer, model, or caliber to search...',
                        hintStyle: const TextStyle(
                            color: Color(0xFF546E7A), fontSize: 14),
                        prefixIcon: const Icon(Icons.search,
                            color: Color(0xFF64B5F6), size: 22),
                        suffixIcon: _firearmSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Color(0xFF78909C), size: 20),
                                onPressed: () {
                                  _firearmSearchController.clear();
                                  setState(() {
                                    _firearmSearchResults = [];
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF1A1F2E),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF37404F)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF37404F)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E88E5), width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        _searchFirearmsForTimeline(value);
                      },
                      onSubmitted: (value) {
                        _searchFirearmsForTimeline(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSearchingFirearms
                          ? null
                          : () => _searchFirearmsForTimeline(
                              _firearmSearchController.text),
                      icon: _isSearchingFirearms
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search, size: 20),
                      label: const Text('Search',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

              // Selected firearm chip
              if (_selectedFirearmForTimeline != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed,
                          color: Color(0xFF64B5F6), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_selectedFirearmForTimeline!.serialNumber} — ${_selectedFirearmForTimeline!.manufacturer} ${_selectedFirearmForTimeline!.model} (${_selectedFirearmForTimeline!.caliber ?? "N/A"})',
                          style: const TextStyle(
                              color: Color(0xFF64B5F6),
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedFirearmForTimeline!.unitDisplayName,
                        style: const TextStyle(
                            color: Color(0xFF90A4AE), fontSize: 13),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedFirearmForTimeline = null;
                            _custodyTimelineData = [];
                            _custodyTimelineSummary = null;
                            _timelineError = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Icon(Icons.close,
                            color: Color(0xFF78909C), size: 18),
                      ),
                    ],
                  ),
                ),
              ],

              // Search results list
              if (_firearmSearchResults.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF37404F)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _firearmSearchResults.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFF2E3546)),
                    itemBuilder: (context, index) {
                      final firearm = _firearmSearchResults[index];
                      return InkWell(
                        onTap: () {
                          _firearmSearchController.text = firearm.serialNumber;
                          _loadCustodyTimelineForFirearm(firearm);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.gps_fixed,
                                    color: Color(0xFF64B5F6), size: 18),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${firearm.manufacturer} ${firearm.model}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'SN: ${firearm.serialNumber}  •  ${firearm.caliber ?? "N/A"}  •  ${firearm.firearmType}',
                                      style: const TextStyle(
                                          color: Color(0xFF90A4AE),
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    firearm.unitDisplayName,
                                    style: const TextStyle(
                                        color: Color(0xFF78909C), fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getFirearmStatusColor(
                                              firearm.currentStatus)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      firearm.currentStatus
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: _getFirearmStatusColor(
                                            firearm.currentStatus),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.arrow_forward_ios,
                                  color: Color(0xFF546E7A), size: 14),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Searching indicator
              if (_isSearchingFirearms && _firearmSearchResults.isEmpty) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF64B5F6)),
                      ),
                      SizedBox(width: 12),
                      Text('Searching firearms...',
                          style: TextStyle(
                              color: Color(0xFF90A4AE), fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Timeline content
        if (_selectedFirearmForTimeline != null)
          _buildTimelineResultPanel()
        else if (_firearmSearchResults.isEmpty &&
            _firearmSearchController.text.isEmpty)
          // Empty state
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timeline,
                      size: 56,
                      color: const Color(0xFF546E7A).withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'Search for a firearm to view its custody timeline',
                    style: TextStyle(color: Color(0xFF90A4AE), fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track firearm movement and custody chain across all units nationwide',
                    style: TextStyle(color: Color(0xFF546E7A), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTimelineResultPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2E3546))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timeline,
                      color: Color(0xFF64B5F6), size: 20),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Custody Chain of Evidence',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                if (_custodyTimelineSummary != null) ...[
                  _buildTimelineSummaryChip(
                      'Transfers',
                      _custodyTimelineSummary!['total_transfers']?.toString() ??
                          '0'),
                  const SizedBox(width: 8),
                  _buildTimelineSummaryChip(
                      'Current',
                      _custodyTimelineSummary!['current_holder']?.toString() ??
                          'Unknown'),
                ],
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: _buildTimelineContentBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF2E3546)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTimelineContentBody() {
    if (_isLoadingTimeline) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Color(0xFF1E88E5))),
              SizedBox(height: 14),
              Text('Loading custody chain...',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_timelineError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFE57373), size: 28),
              const SizedBox(height: 10),
              Text(_timelineError!,
                  style:
                      const TextStyle(color: Color(0xFFE57373), fontSize: 14)),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => _loadCustodyTimelineForFirearm(
                    _selectedFirearmForTimeline!),
                child: const Text('Retry', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ),
      );
    }

    if (_custodyTimelineData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.timeline, color: Color(0xFF546E7A), size: 36),
              SizedBox(height: 14),
              Text('No custody records found for this firearm',
                  style: TextStyle(color: Color(0xFF90A4AE), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return CustodyTimelineWidget(
      timeline: _custodyTimelineData,
      summary: _custodyTimelineSummary,
    );
  }

  Color _getFirearmStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'available':
        return const Color(0xFF4CAF50);
      case 'assigned':
        return const Color(0xFF42A5F5);
      case 'in_maintenance':
        return const Color(0xFFFFA726);
      case 'decommissioned':
        return const Color(0xFFE57373);
      default:
        return const Color(0xFF78909C);
    }
  }

  // =====================================
  // UTILITY METHODS
  // =====================================

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
