// Admin Dashboard
// Dashboard for admin role

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/date_formatter.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/responsive_dashboard_scaffold.dart';
import '../auth/login_screen.dart';
import '../management/user_management_screen.dart';
import '../settings/system_settings_screen.dart';
import '../management/units_management_screen.dart';
import '../workflows/admin_reports_screen.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/charts/role_activity_chart.dart';

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

    // Load core stats first for faster first paint.
    await dashboardProvider.loadDashboardStats();
  }

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.account_balance_outlined, label: 'Units'),
    _NavItem(icon: Icons.group_outlined, label: 'Users'),
    _NavItem(icon: Icons.settings_outlined, label: 'System Settings'),
    _NavItem(icon: Icons.analytics_outlined, label: 'Reports'),
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
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        // Close drawer if open (tablet/compact mode)
                        final scaffoldState = Scaffold.maybeOf(context);
                        if (scaffoldState?.isDrawerOpen ?? false) {
                          Navigator.of(context).pop();
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          Builder(
            builder: (context) {
              final authProvider = Provider.of<AuthProvider>(context);
              final userName = authProvider.userName ?? 'Admin';
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    Text(
                      userName,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
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
        // Dashboard - show the main dashboard content
        return _buildDashboardContent();
      case 1:
        // Units Management
        return const UnitsManagementScreen();
      case 2:
        // Users Management
        return const UserManagementScreen();
      case 3:
        // System Settings
        return const SystemSettingsScreen();
      case 4:
        // System Audit & Compliance Reports
        return const AdminReportsScreen();
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth < 1000;
        final padding = isTablet ? 16.0 : 32.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards Row
              _buildStatsCards(),
              const SizedBox(height: 32),

              // Role Activity Chart
              const RoleActivityChart(),
              const SizedBox(height: 32),

              // Charts Section
              _buildChartsSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCards() {
    return Consumer<DashboardProvider>(
      builder: (context, dashboardProvider, _) {
        final totalUsers = dashboardProvider.totalUsersCount;
        final activeUnits = dashboardProvider.activeUnitsCount;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 800;
            final cards = [
              _buildStatCard(
                icon: Icons.people,
                iconColor: const Color(0xFF1E88E5),
                number: totalUsers.toString(),
                label: 'Total Users',
                trend: '',
                trendColor: const Color(0xFF78909C),
                showUpArrow: false,
                isLoading: dashboardProvider.isLoading,
              ),
              _buildStatCard(
                icon: Icons.business,
                iconColor: const Color(0xFF1E88E5),
                number: activeUnits.toString(),
                label: 'Active Units',
                trend: 'Nationwide',
                trendColor: const Color(0xFF78909C),
                showUpArrow: false,
                isLoading: dashboardProvider.isLoading,
              ),
              _buildStatCard(
                icon: Icons.favorite,
                iconColor: const Color(0xFF1E88E5),
                number: 'Healthy',
                label: 'System Status',
                trend: 'Operational',
                trendColor: const Color(0xFF3CCB7F),
                showUpArrow: false,
                isLoading: false,
              ),
            ];

            if (isNarrow) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 16),
                      Expanded(child: cards[1]),
                    ],
                  ),
                  const SizedBox(height: 16),
                  cards[2],
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 16),
                Expanded(child: cards[1]),
                const SizedBox(width: 16),
                Expanded(child: cards[2]),
              ],
            );
          },
        );
      },
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
    return Consumer<DashboardProvider>(
      builder: (context, dashProvider, _) {
        final recentActivities = dashProvider.recentActivities;

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
                children: [
                  const Icon(Icons.history, color: Color(0xFF1E88E5), size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Recent Actions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${recentActivities.length} entries',
                      style: const TextStyle(
                        color: Color(0xFF1E88E5),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (dashProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
                  ),
                )
              else if (recentActivities.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_outlined,
                            color: Color(0xFF78909C), size: 40),
                        SizedBox(height: 12),
                        Text(
                          'No recent activity',
                          style:
                              TextStyle(color: Color(0xFF78909C), fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...recentActivities.take(6).map((activity) {
                  final actionType = activity['action_type']?.toString() ?? '';
                  final tableName = activity['table_name']?.toString() ?? '';
                  final actorName =
                      activity['actor_name']?.toString() ?? 'System';
                  final createdAt = activity['created_at']?.toString();
                  final timeAgo = _formatTimeAgo(createdAt);
                  final actionInfo = _getActionInfo(actionType, tableName);
                  return _buildRecentAction(
                    actionInfo['icon'] as IconData,
                    actionInfo['color'] as Color,
                    actionInfo['title'] as String,
                    actorName,
                    timeAgo,
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeAgo(String? dateStr) => DateFormatter.timeAgo(dateStr);

  Map<String, dynamic> _getActionInfo(String actionType, String tableName) {
    switch (actionType.toUpperCase()) {
      case 'CREATE':
        return {
          'icon': Icons.add_circle_outline,
          'color': const Color(0xFF3CCB7F),
          'title': 'Created $tableName',
        };
      case 'UPDATE':
        return {
          'icon': Icons.edit_outlined,
          'color': const Color(0xFF42A5F5),
          'title': 'Updated $tableName',
        };
      case 'DELETE':
        return {
          'icon': Icons.delete_outline,
          'color': const Color(0xFFE85C5C),
          'title': 'Deleted $tableName',
        };
      default:
        return {
          'icon': Icons.info_outline,
          'color': const Color(0xFF1E88E5),
          'title': '$actionType on $tableName',
        };
    }
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
              color: iconColor.withValues(alpha: 0.1),
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
}

class _NavItem {
  final IconData icon;
  final String label;

  _NavItem({required this.icon, required this.label});
}
