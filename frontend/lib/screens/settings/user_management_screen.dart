// User Management Screen
// SafeArms Frontend - Admin only screen for managing user accounts

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/create_user_modal.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showCreateModal = false;
  bool _showDeleteModal = false;
  UserModel? _userToDelete;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUsers();
      context.read<UserProvider>().loadStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Row(
        children: [
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopNavBar(context, userProvider),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterBar(userProvider),
                          const SizedBox(height: 24),
                          _buildStatsBar(userProvider),
                          const SizedBox(height: 24),
                          _buildUsersTable(userProvider),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Modals
      floatingActionButton: _buildModals(context, userProvider),
    );
  }

  Widget _buildTopNavBar(BuildContext context, UserProvider userProvider) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // Title and breadcrumb
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Home / Users',
                style: TextStyle(
                  color: const Color(0xFF78909C),
                  fontSize: 14,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Search bar
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                userProvider.setSearchQuery(value);
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search users by name, username, role...',
                hintStyle:
                    const TextStyle(color: Color(0xFF78909C), fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF78909C), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Create User button
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showCreateModal = true;
              });
            },
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Create User',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(UserProvider userProvider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Role filter
          Expanded(
            child: _buildFilterDropdown(
              label: 'Filter by Role',
              value: userProvider.roleFilter,
              items: const [
                {'value': 'all', 'label': 'All Roles'},
                {'value': 'admin', 'label': 'Admin'},
                {
                  'value': 'hq_firearm_commander',
                  'label': 'HQ Firearm Commander'
                },
                {'value': 'station_commander', 'label': 'Station Commander'},
                {'value': 'investigator', 'label': 'Investigator'},
              ],
              onChanged: (value) => userProvider.setRoleFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),

          // Status filter
          Expanded(
            child: _buildFilterDropdown(
              label: 'Status',
              value: userProvider.statusFilter,
              items: const [
                {'value': 'all', 'label': 'All'},
                {'value': 'active', 'label': 'Active'},
                {'value': 'inactive', 'label': 'Inactive'},
              ],
              onChanged: (value) =>
                  userProvider.setStatusFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),

          // Unit filter (placeholder - would load actual units)
          Expanded(
            child: _buildFilterDropdown(
              label: 'Unit',
              value: userProvider.unitFilter,
              items: const [
                {'value': 'all', 'label': 'All Units'},
              ],
              onChanged: (value) => userProvider.setUnitFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),

          // Clear button
          TextButton.icon(
            onPressed: () => userProvider.clearFilters(),
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Clear Filters'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64B5F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            border: Border.all(color: const Color(0xFF37404F)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFF78909C)),
              dropdownColor: const Color(0xFF2A3040),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['value'],
                  child: Text(item['label']!),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(UserProvider userProvider) {
    final stats = userProvider.stats;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.people,
            iconColor: const Color(0xFF1E88E5),
            number: '${userProvider.users.length}',
            label: 'Total Users',
          ),
          _buildDivider(),
          _buildStatCard(
            icon: Icons.check_circle,
            iconColor: const Color(0xFF3CCB7F),
            number:
                '${stats['active'] ?? stats['active_count'] ?? userProvider.users.where((u) => u.isActive).length}',
            label: 'Active',
          ),
          _buildDivider(),
          _buildRoleBreakdown(stats),
          _buildDivider(),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String number,
    required String label,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 60,
      color: const Color(0xFF37404F),
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildRoleBreakdown(Map<String, dynamic> stats) {
    // Backend returns: admins, hqCommanders, stationCommanders, investigators
    // or byRole.admin, byRole.hq_firearm_commander, etc.
    final byRole = stats['byRole'] as Map<String, dynamic>? ?? {};
    final admins =
        stats['admins'] ?? byRole['admin'] ?? stats['admin_count'] ?? 0;
    final hqCmds = stats['hqCommanders'] ??
        byRole['hq_firearm_commander'] ??
        stats['hq_count'] ??
        0;
    final stationCmds = stats['stationCommanders'] ??
        byRole['station_commander'] ??
        stats['station_count'] ??
        0;
    final investigators = stats['investigators'] ??
        byRole['investigator'] ??
        stats['investigator_count'] ??
        0;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'By Role',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '$admins Admins',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
          ),
          Text(
            '$hqCmds HQ Commanders',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
          ),
          Text(
            '$stationCmds Station Commanders',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
          ),
          Text(
            '$investigators Investigators',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Expanded(
      child: Row(
        children: [
          const Icon(Icons.access_time, color: Color(0xFF42A5F5), size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Last user created',
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
              ),
              SizedBox(height: 4),
              Text(
                '2 hours ago',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTable(UserProvider userProvider) {
    if (userProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
      );
    }

    final users = userProvider.paginatedUsers;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF252A3A),
              border: Border(
                bottom: BorderSide(color: Color(0xFF37404F), width: 2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: const [
                Expanded(flex: 3, child: _TableHeader('USER')),
                Expanded(flex: 2, child: _TableHeader('USERNAME')),
                Expanded(flex: 2, child: _TableHeader('ROLE')),
                Expanded(flex: 2, child: _TableHeader('UNIT')),
                Expanded(flex: 2, child: _TableHeader('LAST LOGIN')),
                Expanded(flex: 1, child: _TableHeader('STATUS')),
                SizedBox(width: 100, child: _TableHeader('ACTIONS')),
              ],
            ),
          ),

          // Table rows
          ...users.map((user) => _buildUserRow(user, userProvider)).toList(),

          // Pagination
          _buildPagination(userProvider),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserModel user, UserProvider userProvider) {
    return InkWell(
      onTap: () => userProvider.selectUser(user),
      hoverColor: const Color(0xFF252A3A),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF37404F), width: 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // User column with avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getAvatarColor(user.fullName),
                    child: Text(
                      _getInitials(user.fullName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
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
                          user.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Username
            Expanded(
              flex: 2,
              child: Text(
                user.username,
                style: TextStyle(
                  color: const Color(0xFFB0BEC5),
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Role
            Expanded(
              flex: 2,
              child: _buildRoleBadge(user.role),
            ),

            // Unit
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  if (user.unitId != null) ...[
                    const Icon(Icons.business,
                        color: Color(0xFF78909C), size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        user.unitId ?? '—',
                        style: const TextStyle(
                            color: Color(0xFFB0BEC5), fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Text('—',
                        style:
                            TextStyle(color: Color(0xFF78909C), fontSize: 14)),
                ],
              ),
            ),

            // Last login
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      color: Color(0xFF78909C), size: 16),
                  const SizedBox(width: 4),
                  Text(
                    user.lastLogin != null
                        ? _getRelativeTime(user.lastLogin!)
                        : 'Never',
                    style: TextStyle(
                      color: const Color(0xFF78909C),
                      fontSize: 14,
                      fontStyle: user.lastLogin == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),

            // Status
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: user.isActive
                          ? const Color(0xFF3CCB7F)
                          : const Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    user.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: user.isActive
                          ? const Color(0xFF3CCB7F)
                          : const Color(0xFF78909C),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            SizedBox(
              width: 100,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    color: const Color(0xFF1E88E5),
                    onPressed: () {
                      userProvider.selectUser(user);
                      setState(() {
                        _showCreateModal = true;
                      });
                    },
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    color: const Color(0xFFE85C5C),
                    onPressed: () {
                      setState(() {
                        _userToDelete = user;
                        _showDeleteModal = true;
                      });
                    },
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color backgroundColor;
    String displayText;

    switch (role) {
      case 'admin':
        backgroundColor = const Color(0xFFE85C5C);
        displayText = 'ADMIN';
        break;
      case 'hq_firearm_commander':
        backgroundColor = const Color(0xFF1E88E5);
        displayText = 'HQ COMMANDER';
        break;
      case 'station_commander':
        backgroundColor = const Color(0xFF3CCB7F);
        displayText = 'STATION COMMANDER';
        break;
      case 'investigator':
        backgroundColor = const Color(0xFF42A5F5);
        displayText = 'INVESTIGATOR';
        break;
      default:
        backgroundColor = const Color(0xFF78909C);
        displayText = role.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPagination(UserProvider userProvider) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(
          top: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(userProvider.currentPage - 1) * userProvider.itemsPerPage + 1}-'
            '${(userProvider.currentPage * userProvider.itemsPerPage).clamp(0, userProvider.totalItems)} '
            'of ${userProvider.totalItems} users',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: userProvider.currentPage > 1
                    ? const Color(0xFFB0BEC5)
                    : const Color(0xFF37404F),
                onPressed: userProvider.currentPage > 1
                    ? () => userProvider.previousPage()
                    : null,
              ),
              ...List.generate(
                userProvider.totalPages.clamp(0, 5),
                (index) {
                  final page = index + 1;
                  final isActive = page == userProvider.currentPage;
                  return InkWell(
                    onTap: () => userProvider.setPage(page),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF1E88E5)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$page',
                        style: TextStyle(
                          color:
                              isActive ? Colors.white : const Color(0xFFB0BEC5),
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                color: userProvider.currentPage < userProvider.totalPages
                    ? const Color(0xFFB0BEC5)
                    : const Color(0xFF37404F),
                onPressed: userProvider.currentPage < userProvider.totalPages
                    ? () => userProvider.nextPage()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModals(BuildContext context, UserProvider userProvider) {
    if (_showCreateModal) {
      return CreateUserModal(
        user: userProvider.selectedUser,
        onClose: () {
          setState(() {
            _showCreateModal = false;
          });
          userProvider.clearSelectedUser();
        },
        onSuccess: () {
          setState(() {
            _showCreateModal = false;
          });
          userProvider.clearSelectedUser();
          userProvider.loadUsers();
        },
      );
    }

    if (_showDeleteModal && _userToDelete != null) {
      return _DeleteConfirmationModal(
        user: _userToDelete!,
        onClose: () {
          setState(() {
            _showDeleteModal = false;
            _userToDelete = null;
          });
        },
        onConfirm: () async {
          final success = await userProvider.deleteUser(_userToDelete!.userId);
          if (!mounted) return;
          setState(() {
            _showDeleteModal = false;
            _userToDelete = null;
          });
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User deleted successfully'),
                backgroundColor: Color(0xFF3CCB7F),
              ),
            );
          }
        },
      );
    }

    return const SizedBox.shrink();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF1E88E5),
      const Color(0xFF3CCB7F),
      const Color(0xFFE85C5C),
      const Color(0xFF42A5F5),
      const Color(0xFFFFC857),
    ];
    return colors[name.length % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

class _TableHeader extends StatelessWidget {
  final String text;

  const _TableHeader(this.text, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFB0BEC5),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }
}

// Delete Confirmation Modal (will be in separate file - placeholder for now)
class _DeleteConfirmationModal extends StatelessWidget {
  final UserModel user;
  final VoidCallback onClose;
  final VoidCallback onConfirm;

  const _DeleteConfirmationModal({
    Key? key,
    required this.user,
    required this.onClose,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // This will be implemented in next iteration
    return Container();
  }
}
