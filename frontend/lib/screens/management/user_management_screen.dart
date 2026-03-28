// User Management Screen
// Admin interface for managing system users
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import '../../widgets/user_avatar.dart';

const double _desktopBreakpoint = 1024;
const double _mobileBreakpoint = 768;
const int _userColumnFlex = 3;
const int _roleColumnFlex = 2;
const int _unitColumnFlex = 2;
const int _statusColumnFlex = 2;
const int _actionsColumnFlex = 2;

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

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
        final width = MediaQuery.of(context).size.width;
        final isDesktop = width >= _desktopBreakpoint;
        final isMobile = width < _mobileBreakpoint;
        final pagePadding = isDesktop ? 32.0 : (isMobile ? 12.0 : 20.0);

        return SingleChildScrollView(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              LayoutBuilder(
                builder: (context, constraints) {
                  final headerIsDesktop =
                      constraints.maxWidth >= _desktopBreakpoint;

                  const titleBlock = Column(
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
                  );

                  final addButton = ElevatedButton.icon(
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
                  );

                  if (headerIsDesktop) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        titleBlock,
                        addButton,
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: addButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Stats Cards
              LayoutBuilder(
                builder: (context, constraints) {
                  final cards = [
                    _buildStatCard(
                      'Total Users',
                      '${stats['total'] ?? provider.users.length}',
                      Icons.people,
                      const Color(0xFF1E88E5),
                    ),
                    _buildStatCard(
                      'Active Users',
                      '${stats['active'] ?? 0}',
                      Icons.check_circle,
                      const Color(0xFF3CCB7F),
                    ),
                    _buildStatCard(
                      'Inactive Users',
                      '${stats['inactive'] ?? 0}',
                      Icons.cancel,
                      const Color(0xFFEF5350),
                    ),
                    _buildStatCard(
                      'Admins',
                      '${stats['admins'] ?? 0}',
                      Icons.admin_panel_settings,
                      const Color(0xFFFFC857),
                    ),
                  ];

                  if (constraints.maxWidth >= _desktopBreakpoint) {
                    return Row(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i < cards.length - 1) const SizedBox(width: 16),
                        ],
                      ],
                    );
                  }

                  final itemWidth = constraints.maxWidth < _mobileBreakpoint
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 16) / 2;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: cards
                        .map((card) => SizedBox(width: itemWidth, child: card))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 32),

              // Filters Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktopFilters =
                      constraints.maxWidth >= _desktopBreakpoint;

                  final searchField = TextField(
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
                        borderSide: const BorderSide(color: Color(0xFF37404F)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF37404F)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF1E88E5)),
                      ),
                    ),
                    onChanged: (value) {
                      provider.setSearchQuery(value);
                    },
                  );

                  final roleFilter = _buildDropdownFilter(
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
                  );

                  final statusFilter = _buildDropdownFilter(
                    'Status',
                    _selectedStatus,
                    ['all', 'active', 'inactive'],
                    (value) {
                      setState(() => _selectedStatus = value!);
                      provider.setStatusFilter(value!);
                    },
                  );

                  if (isDesktopFilters) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(width: 16),
                        Expanded(child: roleFilter),
                        const SizedBox(width: 16),
                        Expanded(child: statusFilter),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: roleFilter),
                          const SizedBox(width: 12),
                          Expanded(child: statusFilter),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Users Table
              LayoutBuilder(
                builder: (context, constraints) {
                  return _buildUsersTable(provider, constraints.maxWidth);
                },
              ),

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

  Widget _buildUsersTable(UserProvider provider, double availableWidth) {
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

    if (availableWidth < _mobileBreakpoint) {
      return Column(
        children: users
            .map((user) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildUserCard(user, provider),
                ))
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: math.max(availableWidth, 980.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: _userColumnFlex,
                      child: Center(
                        child: Text(
                          'User',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: _roleColumnFlex,
                      child: Center(
                        child: Text(
                          'Role',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: _unitColumnFlex,
                      child: Center(
                        child: Text(
                          'Unit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: _statusColumnFlex,
                      child: Center(
                        child: Text(
                          'Status',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: _actionsColumnFlex,
                      child: Center(
                        child: Text(
                          'Actions',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Table Body
              Column(
                children: [
                  for (int index = 0; index < users.length; index++) ...[
                    _buildUserRow(users[index], provider),
                    if (index < users.length - 1)
                      const Divider(
                        color: Color(0xFF37404F),
                        height: 1,
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, UserProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                fullName: user.fullName,
                photoUrl: user.profilePhotoUrl,
                radius: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(
                          color: Color(0xFF78909C), fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildRoleBadge(user.role),
              _buildStatusBadge(user.isActive),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF37404F)),
                ),
                child: Text(
                  user.unitId ?? 'No Unit',
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility,
                    color: Color(0xFF78909C), size: 18),
                onPressed: () => _showUserDetails(user),
                tooltip: 'View',
              ),
              IconButton(
                icon:
                    const Icon(Icons.edit, color: Color(0xFF78909C), size: 18),
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
            flex: _userColumnFlex,
            child: Row(
              children: [
                UserAvatar(
                  fullName: user.fullName,
                  photoUrl: user.profilePhotoUrl,
                  radius: 22,
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
            flex: _roleColumnFlex,
            child: _buildRoleBadge(user.role),
          ),
          Expanded(
            flex: _unitColumnFlex,
            child: Center(
              child: Text(
                user.unitId ?? 'No Unit',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB0BEC5)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: _statusColumnFlex,
            child: _buildStatusBadge(user.isActive),
          ),
          Expanded(
            flex: _actionsColumnFlex,
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
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
      ),
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
                              UserAvatar(
                                fullName: user.fullName,
                                photoUrl: user.profilePhotoUrl,
                                radius: 54,
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
    bool isSubmitting = false;
    Uint8List? selectedProfilePhotoBytes;
    String? selectedProfilePhotoFileName;

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
                            _buildProfilePhotoUploadSection(
                              fullName: fullName,
                              selectedPhotoBytes: selectedProfilePhotoBytes,
                              selectedPhotoFileName:
                                  selectedProfilePhotoFileName,
                              onPickPhoto: isSubmitting
                                  ? null
                                  : () async {
                                      await _pickProfilePhoto(
                                        onSelected: (bytes, fileName) {
                                          setDialogState(() {
                                            selectedProfilePhotoBytes = bytes;
                                            selectedProfilePhotoFileName =
                                                fileName;
                                          });
                                        },
                                      );
                                    },
                            ),
                            const SizedBox(height: 24),

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
                                      if (v == null || v.isEmpty) {
                                        return 'Required';
                                      }
                                      if (v.length < 8) {
                                        return 'Min 8 characters';
                                      }
                                      if (!RegExp(r'[A-Z]').hasMatch(v)) {
                                        return 'Need uppercase letter';
                                      }
                                      if (!RegExp(r'[a-z]').hasMatch(v)) {
                                        return 'Need lowercase letter';
                                      }
                                      if (!RegExp(r'[0-9]').hasMatch(v)) {
                                        return 'Need a number';
                                      }
                                      if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]')
                                          .hasMatch(v)) {
                                        return 'Need special char';
                                      }
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
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final formState = formKey.currentState;
                                        if (formState == null) return;
                                        if (!formState.validate()) return;
                                        formState.save();
                                        setDialogState(
                                            () => isSubmitting = true);
                                        final success =
                                            await provider.createUser(
                                          username: username,
                                          password: password,
                                          fullName: fullName,
                                          email: email,
                                          phoneNumber: phoneNumber,
                                          role: role,
                                          unitId: unitId,
                                          profilePhotoBytes:
                                              selectedProfilePhotoBytes,
                                          profilePhotoFileName:
                                              selectedProfilePhotoFileName,
                                          isActive: isActive,
                                        );
                                        if (!dialogContext.mounted) return;
                                        setDialogState(
                                            () => isSubmitting = false);
                                        final scaffoldMessenger =
                                            ScaffoldMessenger.of(dialogContext);
                                        if (success) {
                                          Navigator.pop(dialogContext);
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'User created successfully'),
                                              backgroundColor:
                                                  Color(0xFF3CCB7F),
                                            ),
                                          );
                                        } else {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  provider.errorMessage ??
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
    bool isSubmitting = false;
    Uint8List? selectedProfilePhotoBytes;
    String? selectedProfilePhotoFileName;
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
                            _buildProfilePhotoUploadSection(
                              fullName: fullName,
                              currentPhotoUrl: user.profilePhotoUrl,
                              selectedPhotoBytes: selectedProfilePhotoBytes,
                              selectedPhotoFileName:
                                  selectedProfilePhotoFileName,
                              onPickPhoto: isSubmitting
                                  ? null
                                  : () async {
                                      await _pickProfilePhoto(
                                        onSelected: (bytes, fileName) {
                                          setDialogState(() {
                                            selectedProfilePhotoBytes = bytes;
                                            selectedProfilePhotoFileName =
                                                fileName;
                                          });
                                        },
                                      );
                                    },
                            ),
                            const SizedBox(height: 24),

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
                                              if (v == null || v.isEmpty) {
                                                return 'Required';
                                              }
                                              if (v.length < 8) {
                                                return 'Min 8 characters';
                                              }
                                              if (!RegExp(r'[A-Z]')
                                                  .hasMatch(v)) {
                                                return 'Need uppercase letter';
                                              }
                                              if (!RegExp(r'[a-z]')
                                                  .hasMatch(v)) {
                                                return 'Need lowercase letter';
                                              }
                                              if (!RegExp(r'[0-9]')
                                                  .hasMatch(v)) {
                                                return 'Need a number';
                                              }
                                              if (!RegExp(
                                                      r'[!@#$%^&*(),.?":{}|<>]')
                                                  .hasMatch(v)) {
                                                return 'Need special char';
                                              }
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
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final formState = formKey.currentState;
                                        if (formState == null) return;
                                        if (!formState.validate()) return;
                                        formState.save();
                                        setDialogState(
                                            () => isSubmitting = true);

                                        // Handle password reset if provided
                                        if (showResetPassword &&
                                            resetPasswordController
                                                .text.isNotEmpty) {
                                          final resetSuccess =
                                              await provider.resetUserPassword(
                                            user.userId,
                                            resetPasswordController.text,
                                          );
                                          if (!dialogContext.mounted) return;
                                          final scaffoldMessenger =
                                              ScaffoldMessenger.of(
                                                  dialogContext);
                                          if (!resetSuccess) {
                                            scaffoldMessenger.showSnackBar(
                                              SnackBar(
                                                content: Text(provider
                                                        .errorMessage ??
                                                    'Failed to reset password'),
                                                backgroundColor:
                                                    const Color(0xFFEF5350),
                                              ),
                                            );
                                            setDialogState(
                                                () => isSubmitting = false);
                                            return;
                                          }
                                        }

                                        final success =
                                            await provider.updateUser(
                                          userId: user.userId,
                                          fullName: fullName,
                                          email: email,
                                          phoneNumber: phoneNumber,
                                          role: role,
                                          unitId: unitId,
                                          profilePhotoBytes:
                                              selectedProfilePhotoBytes,
                                          profilePhotoFileName:
                                              selectedProfilePhotoFileName,
                                          isActive: isActive,
                                        );
                                        if (!dialogContext.mounted) return;
                                        setDialogState(
                                            () => isSubmitting = false);
                                        final scaffoldMessenger =
                                            ScaffoldMessenger.of(dialogContext);
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
                                              content: Text(
                                                  provider.errorMessage ??
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

  Future<void> _pickProfilePhoto({
    required void Function(Uint8List bytes, String fileName) onSelected,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    if (file.bytes == null) {
      return;
    }

    onSelected(file.bytes!, file.name);
  }

  Widget _buildProfilePhotoUploadSection({
    required String fullName,
    required Uint8List? selectedPhotoBytes,
    required String? selectedPhotoFileName,
    required VoidCallback? onPickPhoto,
    String? currentPhotoUrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Photo',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Optional. Used only as visual user indicator in the system.',
          style: TextStyle(
            color: Color(0xFF78909C),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            UserAvatar(
              fullName: fullName,
              photoUrl: currentPhotoUrl,
              memoryBytes: selectedPhotoBytes,
              radius: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: onPickPhoto,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Upload Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selectedPhotoFileName ??
                        (currentPhotoUrl != null
                            ? 'Current photo is set'
                            : 'No image selected'),
                    style: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
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
      try {
        final success = await provider.deleteUser(user.userId);
        if (!mounted) return;
        final scaffoldMessenger = ScaffoldMessenger.of(context);
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
        final scaffoldMessenger = ScaffoldMessenger.of(context);
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
