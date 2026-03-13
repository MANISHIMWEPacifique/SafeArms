// User Management Screen
// Admin interface for managing system users
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/delete_confirmation_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedRole = 'all';
  String _selectedStatus = 'all';

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
    return Consumer<UserProvider>(
      builder: (context, provider, child) {
        final stats = provider.stats;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage system users and roles',
                        style:
                            TextStyle(color: Color(0xFF78909C), fontSize: 14),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddUserDialog(context, provider),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Users',
                      '${stats['total'] ?? provider.users.length}',
                      Icons.people,
                      const Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Active Users',
                      '${stats['active'] ?? 0}',
                      Icons.check_circle,
                      const Color(0xFF3CCB7F),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Inactive Users',
                      '${stats['inactive'] ?? 0}',
                      Icons.cancel,
                      const Color(0xFFEF5350),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Admins',
                      '${stats['admins'] ?? 0}',
                      Icons.admin_panel_settings,
                      const Color(0xFFFFC857),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Filters Row
              Row(
                children: [
                  // Search
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, or username...',
                        hintStyle: const TextStyle(color: Color(0xFF78909C)),
                        prefixIcon:
                            const Icon(Icons.search, color: Color(0xFF78909C)),
                        filled: true,
                        fillColor: const Color(0xFF2A3040),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF37404F)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF37404F)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF1E88E5)),
                        ),
                      ),
                      onChanged: (value) {
                        provider.setSearchQuery(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Role Filter
                  Expanded(
                    child: _buildDropdownFilter(
                      'Role',
                      _selectedRole,
                      [
                        'all',
                        'admin',
                        'hq_firearm_commander',
                        'station_commander',
                        'investigator'
                      ],
                      (value) {
                        setState(() => _selectedRole = value!);
                        provider.setRoleFilter(value!);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Status Filter
                  Expanded(
                    child: _buildDropdownFilter(
                      'Status',
                      _selectedStatus,
                      ['all', 'active', 'inactive'],
                      (value) {
                        setState(() => _selectedStatus = value!);
                        provider.setStatusFilter(value!);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Users Table
              _buildUsersTable(provider),

              // Pagination
              if (provider.totalPages > 1) ...[
                const SizedBox(height: 16),
                _buildPagination(provider),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF2A3040),
          style: const TextStyle(color: Colors.white),
          icon: const Icon(Icons.expand_more, color: Color(0xFF78909C)),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(_formatFilterLabel(item)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _formatFilterLabel(String value) {
    if (value == 'all') return 'All';
    return value.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  Widget _buildUsersTable(UserProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
      );
    }

    if (provider.errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3040),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF37404F)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Color(0xFFEF5350)),
              const SizedBox(height: 16),
              Text(
                provider.errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => provider.loadUsers(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final users = provider.paginatedUsers;

    if (users.isEmpty) {
      return Container(
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
              Icon(Icons.people_outline, size: 64, color: Color(0xFF78909C)),
              SizedBox(height: 16),
              Text(
                'No users found',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Try adjusting your filters or add a new user',
                style: TextStyle(color: Color(0xFF78909C)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'User',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Role',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Unit',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Status',
                    style: TextStyle(
                      color: Color(0xFF78909C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 120, child: Text('')),
              ],
            ),
          ),

          // Table Body
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(
              color: Color(0xFF37404F),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserRow(user, provider);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(UserModel user, UserProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF1E88E5),
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : '?',
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
                        user.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        user.email,
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
          ),
          Expanded(
            child: _buildRoleBadge(user.role),
          ),
          Expanded(
            child: Text(
              user.unitId ?? 'No Unit',
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
          ),
          Expanded(
            child: _buildStatusBadge(user.isActive),
          ),
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility,
                      color: Color(0xFF78909C), size: 18),
                  onPressed: () => _showUserDetails(user),
                  tooltip: 'View',
                ),
                IconButton(
                  icon: const Icon(Icons.edit,
                      color: Color(0xFF78909C), size: 18),
                  onPressed: () => _showEditUserDialog(user, provider),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFEF5350),
                    size: 18,
                  ),
                  onPressed: () => _deleteUser(user, provider),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    switch (role) {
      case 'admin':
        badgeColor = const Color(0xFFFFC857);
        break;
      case 'hq_firearm_commander':
        badgeColor = const Color(0xFF1E88E5);
        break;
      case 'station_commander':
        badgeColor = const Color(0xFF3CCB7F);
        break;
      case 'investigator':
        badgeColor = const Color(0xFF9C27B0);
        break;
      default:
        badgeColor = const Color(0xFF78909C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatFilterLabel(role),
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF3CCB7F).withValues(alpha: 0.2)
            : const Color(0xFFEF5350).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isActive ? const Color(0xFF3CCB7F) : const Color(0xFFEF5350),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPagination(UserProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF78909C)),
          onPressed: provider.currentPage > 1
              ? () => provider.setPage(provider.currentPage - 1)
              : null,
        ),
        ...List.generate(provider.totalPages, (index) {
          final page = index + 1;
          final isCurrentPage = page == provider.currentPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => provider.setPage(page),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCurrentPage
                      ? const Color(0xFF1E88E5)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrentPage
                        ? const Color(0xFF1E88E5)
                        : const Color(0xFF37404F),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$page',
                    style: TextStyle(
                      color: isCurrentPage
                          ? Colors.white
                          : const Color(0xFF78909C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
        IconButton(
          icon: const Icon(Icons.chevron_right, color: Color(0xFF78909C)),
          onPressed: provider.currentPage < provider.totalPages
              ? () => provider.setPage(provider.currentPage + 1)
              : null,
        ),
      ],
    );
  }

  void _showUserDetails(UserModel user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 500,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF252A3A),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1F2E),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.person,
                            color: Color(0xFF1E88E5), size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'User Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'View user information',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, color: Colors.white54),
                        hoverColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ],
                  ),
                ),
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Avatar & Name
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.2),
                                child: Text(
                                  user.fullName.isNotEmpty
                                      ? user.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Color(0xFF1E88E5),
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.isActive
                                      ? const Color(0xFF3CCB7F)
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFFE85C5C)
                                          .withValues(alpha: 0.15),
                                ),
                                child: Text(
                                  user.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color: user.isActive
                                        ? const Color(0xFF3CCB7F)
                                        : const Color(0xFFE85C5C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDetailSection('Account Information', [
                          _buildDetailRow('Username', user.username),
                          _buildDetailRow(
                              'Role', _formatFilterLabel(user.role)),
                          _buildDetailRow(
                              'Unit', user.unitId ?? 'Not assigned'),
                        ]),
                        const SizedBox(height: 24),
                        _buildDetailSection('Contact Information', [
                          _buildDetailRow('Email', user.email),
                          _buildDetailRow(
                              'Phone', user.phoneNumber ?? 'Not provided'),
                        ]),
                        const SizedBox(height: 24),
                        _buildDetailSection('Security & Status', [
                          _buildDetailRow(
                              'Unit Confirmed',
                              user.role == 'station_commander'
                                  ? (user.unitConfirmed ? 'Yes' : 'Pending')
                                  : 'N/A'),
                          _buildDetailRow('Must Change Password',
                              user.mustChangePassword ? 'Yes' : 'No'),
                          _buildDetailRow('Last Login',
                              user.lastLogin?.toString() ?? 'Never'),
                          _buildDetailRow('Created',
                              user.createdAt?.toString() ?? 'Unknown'),
                        ]),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1F2E),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF37404F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, UserProvider provider) {
    final formKey = GlobalKey<FormState>();
    String username = '';
    String password = '';
    String fullName = '';
    String email = '';
    String phoneNumber = '';
    String role = 'station_commander';
    String? unitId;
    bool isActive = true;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 600,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF252A3A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1F2E),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF3CCB7F).withValues(alpha: 0.2),
                          ),
                          child: const Icon(Icons.person_add,
                              color: Color(0xFF3CCB7F), size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create New User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Add a new user to the SafeArms platform',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white54),
                          hoverColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Account Credentials Section
                            const Text(
                              'Account Credentials',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                      'Username', (v) => username = v,
                                      required: true),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: const TextStyle(
                                          color: Colors.white54),
                                      prefixIcon: const Icon(Icons.lock,
                                          color: Colors.white54, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: Colors.white54,
                                          size: 20,
                                        ),
                                        onPressed: () => setDialogState(() =>
                                            obscurePassword = !obscurePassword),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF1A1F2E),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF37404F)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF37404F)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF1E88E5)),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE85C5C)),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                            color: Color(0xFFE85C5C)),
                                      ),
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    obscureText: obscurePassword,
                                    validator: (v) {
                                      if (v == null || v.isEmpty)
                                        return 'Required';
                                      if (v.length < 8)
                                        return 'Min 8 characters';
                                      if (!RegExp(r'[A-Z]').hasMatch(v))
                                        return 'Need uppercase letter';
                                      if (!RegExp(r'[a-z]').hasMatch(v))
                                        return 'Need lowercase letter';
                                      if (!RegExp(r'[0-9]').hasMatch(v))
                                        return 'Need a number';
                                      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]')
                                          .hasMatch(v))
                                        return 'Need special char';
                                      return null;
                                    },
                                    onSaved: (v) => password = v!,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Color(0xFF42A5F5), size: 14),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Password: min 8 chars, uppercase, lowercase, number & special character',
                                      style: TextStyle(
                                          color: Color(0xFF90CAF9),
                                          fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Personal Information Section
                            const Text(
                              'Personal Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField('Full Name', (v) => fullName = v,
                                required: true),
                            const SizedBox(height: 24),

                            // Contact Information Section
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                      'Email', (v) => email = v,
                                      required: true,
                                      type: TextInputType.emailAddress),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                      'Phone Number', (v) => phoneNumber = v,
                                      required: true,
                                      type: TextInputType.phone),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Role & Assignment Section
                            const Text(
                              'Role & Assignment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildRoleDropdown(role, (v) {
                              setDialogState(() => role = v!);
                            }),
                            const SizedBox(height: 16),

                            // Unit assignment info for station commanders
                            if (role == 'station_commander') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF1E88E5)
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Color(0xFF1E88E5), size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Station Commander will need to confirm their unit assignment on first login.',
                                        style: TextStyle(
                                            color: Color(0xFFB0BEC5),
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Active Status Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFF37404F)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isActive
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: isActive
                                            ? const Color(0xFF3CCB7F)
                                            : const Color(0xFFE85C5C),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Active Status',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: isActive,
                                    onChanged: (v) =>
                                        setDialogState(() => isActive = v),
                                    activeThumbColor: const Color(0xFF3CCB7F),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final formState = formKey.currentState;
                                  if (formState == null) return;
                                  if (!formState.validate()) return;
                                  formState.save();
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(dialogContext);
                                  final success = await provider.createUser(
                                    username: username,
                                    password: password,
                                    fullName: fullName,
                                    email: email,
                                    phoneNumber: phoneNumber,
                                    role: role,
                                    unitId: unitId,
                                    isActive: isActive,
                                  );
                                  if (success) {
                                    Navigator.pop(dialogContext);
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('User created successfully'),
                                        backgroundColor: Color(0xFF3CCB7F),
                                      ),
                                    );
                                  } else {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(provider.errorMessage ??
                                            'Failed to create user'),
                                        backgroundColor:
                                            const Color(0xFFEF5350),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                child: const Text(
                                  'Create User',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    Function(String) onSaved, {
    bool required = false,
    bool obscure = false,
    TextInputType type = TextInputType.text,
    String? initialValue,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF37404F)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF37404F)),
        ),
      ),
      style: const TextStyle(color: Colors.white),
      obscureText: obscure,
      keyboardType: type,
      validator:
          required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      onSaved: (v) => onSaved(v ?? ''),
    );
  }

  Widget _buildRoleDropdown(String value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: 'Role',
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF37404F)),
        ),
      ),
      dropdownColor: const Color(0xFF2A3040),
      style: const TextStyle(color: Colors.white),
      items: [
        'admin',
        'hq_firearm_commander',
        'station_commander',
        'investigator',
      ].map((role) {
        return DropdownMenuItem(
            value: role, child: Text(_formatFilterLabel(role)));
      }).toList(),
      onChanged: onChanged,
    );
  }

  void _showEditUserDialog(UserModel user, UserProvider provider) {
    final formKey = GlobalKey<FormState>();
    String fullName = user.fullName;
    String email = user.email;
    String phoneNumber = user.phoneNumber ?? '';
    String role = user.role;
    String? unitId = user.unitId;
    bool isActive = user.isActive;
    bool showResetPassword = false;
    bool obscureNewPassword = true;
    final resetPasswordController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 600,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogContext).size.height * 0.9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF252A3A),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1F2E),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFFC857).withValues(alpha: 0.2),
                          ),
                          child: const Icon(Icons.edit,
                              color: Color(0xFFFFC857), size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Edit User',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                user.username,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white54),
                          hoverColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                  ),
                  // Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Account Information Section
                            const Text(
                              'Account Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Username (readonly)
                            TextFormField(
                              initialValue: user.username,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: 'Username (cannot be changed)',
                                labelStyle:
                                    const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.account_circle,
                                    color: Colors.white54, size: 20),
                                filled: true,
                                fillColor: const Color(0xFF1A1F2E)
                                    .withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF37404F)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF37404F)),
                                ),
                                disabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF37404F)),
                                ),
                              ),
                              style: const TextStyle(color: Color(0xFF78909C)),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                      'Full Name', (v) => fullName = v,
                                      required: true, initialValue: fullName),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildRoleDropdown(role, (v) {
                                    setDialogState(() => role = v!);
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Contact Information Section
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                      'Email', (v) => email = v,
                                      required: true,
                                      type: TextInputType.emailAddress,
                                      initialValue: email),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextField(
                                      'Phone Number', (v) => phoneNumber = v,
                                      required: true,
                                      type: TextInputType.phone,
                                      initialValue: phoneNumber),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Unit assignment info for station commanders
                            if (role == 'station_commander') ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF1E88E5)
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: Color(0xFF1E88E5), size: 16),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Station Commander requires unit assignment. User will need to confirm unit on first login.',
                                        style: TextStyle(
                                            color: Color(0xFFB0BEC5),
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Active Status Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1F2E),
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFF37404F)),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isActive
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: isActive
                                            ? const Color(0xFF3CCB7F)
                                            : const Color(0xFFE85C5C),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Active Status',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: isActive,
                                    onChanged: (v) =>
                                        setDialogState(() => isActive = v),
                                    activeThumbColor: const Color(0xFF3CCB7F),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Reset Password Section
                            InkWell(
                              onTap: () => setDialogState(
                                  () => showResetPassword = !showResetPassword),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1F2E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: showResetPassword
                                        ? const Color(0xFFFF9800)
                                            .withValues(alpha: 0.5)
                                        : const Color(0xFF37404F),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.lock_reset,
                                          color: showResetPassword
                                              ? const Color(0xFFFF9800)
                                              : const Color(0xFF78909C),
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Reset Password',
                                          style: TextStyle(
                                            color: showResetPassword
                                                ? const Color(0xFFFF9800)
                                                : Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      showResetPassword
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: const Color(0xFF78909C),
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (showResetPassword) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1F2E),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFFF9800)
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9800)
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning_amber,
                                              color: Color(0xFFFFB74D),
                                              size: 14),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'User will be required to change this password on next login.',
                                              style: TextStyle(
                                                  color: Color(0xFFFFE0B2),
                                                  fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: resetPasswordController,
                                      decoration: InputDecoration(
                                        labelText: 'New Password',
                                        labelStyle: const TextStyle(
                                            color: Colors.white54),
                                        prefixIcon: const Icon(Icons.lock,
                                            color: Colors.white54, size: 20),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            obscureNewPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.white54,
                                            size: 20,
                                          ),
                                          onPressed: () => setDialogState(() =>
                                              obscureNewPassword =
                                                  !obscureNewPassword),
                                        ),
                                        filled: true,
                                        fillColor: const Color(0xFF252A3A),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF37404F)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF37404F)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFFF9800)),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE85C5C)),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          borderSide: const BorderSide(
                                              color: Color(0xFFE85C5C)),
                                        ),
                                      ),
                                      style:
                                          const TextStyle(color: Colors.white),
                                      obscureText: obscureNewPassword,
                                      validator: showResetPassword &&
                                              resetPasswordController
                                                  .text.isNotEmpty
                                          ? (v) {
                                              if (v == null || v.isEmpty)
                                                return 'Required';
                                              if (v.length < 8)
                                                return 'Min 8 characters';
                                              if (!RegExp(r'[A-Z]').hasMatch(v))
                                                return 'Need uppercase letter';
                                              if (!RegExp(r'[a-z]').hasMatch(v))
                                                return 'Need lowercase letter';
                                              if (!RegExp(r'[0-9]').hasMatch(v))
                                                return 'Need a number';
                                              if (!RegExp(
                                                      r'[!@#$%^&*(),.?":{}|<>]')
                                                  .hasMatch(v))
                                                return 'Need special char';
                                              return null;
                                            }
                                          : null,
                                      onSaved: (v) => resetPasswordController
                                          .text = v ?? '',
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Min 8 chars, uppercase, lowercase, number & special character',
                                      style: TextStyle(
                                          color: Color(0xFF78909C),
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  final formState = formKey.currentState;
                                  if (formState == null) return;
                                  if (!formState.validate()) return;
                                  formState.save();
                                  final scaffoldMessenger =
                                      ScaffoldMessenger.of(dialogContext);

                                  // Handle password reset if provided
                                  if (showResetPassword &&
                                      resetPasswordController.text.isNotEmpty) {
                                    final resetSuccess =
                                        await provider.resetUserPassword(
                                      user.userId,
                                      resetPasswordController.text,
                                    );
                                    if (!resetSuccess) {
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(provider.errorMessage ??
                                              'Failed to reset password'),
                                          backgroundColor:
                                              const Color(0xFFEF5350),
                                        ),
                                      );
                                      return;
                                    }
                                  }

                                  final success = await provider.updateUser(
                                    userId: user.userId,
                                    fullName: fullName,
                                    email: email,
                                    phoneNumber: phoneNumber,
                                    role: role,
                                    unitId: unitId,
                                    isActive: isActive,
                                  );
                                  if (success) {
                                    Navigator.pop(dialogContext);
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(showResetPassword &&
                                                resetPasswordController
                                                    .text.isNotEmpty
                                            ? 'User updated & password reset successfully'
                                            : 'User updated successfully'),
                                        backgroundColor:
                                            const Color(0xFF3CCB7F),
                                      ),
                                    );
                                  } else {
                                    scaffoldMessenger.showSnackBar(
                                      SnackBar(
                                        content: Text(provider.errorMessage ??
                                            'Failed to update user'),
                                        backgroundColor:
                                            const Color(0xFFEF5350),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                child: const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteUser(UserModel user, UserProvider provider) async {
    final confirm = await DeleteConfirmationDialog.show(
      context,
      title: 'Delete User?',
      message: 'You are about to permanently delete',
      itemName: user.fullName,
      detail:
          'All user data and access will be permanently removed. This cannot be undone.',
      confirmText: 'Delete User',
    );

    if (confirm == true) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        final success = await provider.deleteUser(user.userId);
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'User deleted successfully'
                  : (provider.errorMessage ?? 'Failed to delete user'),
            ),
            backgroundColor:
                success ? const Color(0xFF3CCB7F) : const Color(0xFFE85C5C),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting user: $e'),
            backgroundColor: const Color(0xFFE85C5C),
          ),
        );
      }
    }
  }
}
