// User Management Screen
// Admin interface for managing system users
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';

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
                  icon: const Icon(Icons.visibility, color: Color(0xFF78909C)),
                  onPressed: () => _showUserDetails(user),
                  tooltip: 'View',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF78909C)),
                  onPressed: () => _showEditUserDialog(user, provider),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: Icon(
                    user.isActive ? Icons.block : Icons.check_circle_outline,
                    color: user.isActive
                        ? const Color(0xFFEF5350)
                        : const Color(0xFF3CCB7F),
                  ),
                  onPressed: () => _toggleUserStatus(user, provider),
                  tooltip: user.isActive ? 'Deactivate' : 'Activate',
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1E88E5),
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.fullName,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Username', user.username),
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided'),
              _buildDetailRow('Role', _formatFilterLabel(user.role)),
              _buildDetailRow('Unit', user.unitId ?? 'Not assigned'),
              _buildDetailRow('Status', user.isActive ? 'Active' : 'Inactive'),
              _buildDetailRow(
                  'Unit Confirmed',
                  user.role == 'station_commander'
                      ? (user.unitConfirmed ? 'Yes' : 'Pending')
                      : 'N/A'),
              _buildDetailRow('Must Change Password',
                  user.mustChangePassword ? 'Yes' : 'No'),
              _buildDetailRow(
                  'Last Login', user.lastLogin?.toString() ?? 'Never'),
              _buildDetailRow(
                  'Created', user.createdAt?.toString() ?? 'Unknown'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
              '$label:',
              style: const TextStyle(color: Color(0xFF78909C)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title:
            const Text('Add New User', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField('Username', (v) => username = v,
                      required: true),
                  const SizedBox(height: 12),
                  _buildTextField('Password', (v) => password = v,
                      required: true, obscure: true),
                  const SizedBox(height: 12),
                  _buildTextField('Full Name', (v) => fullName = v,
                      required: true),
                  const SizedBox(height: 12),
                  _buildTextField('Email', (v) => email = v,
                      required: true, type: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _buildTextField('Phone Number', (v) => phoneNumber = v,
                      required: true, type: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildRoleDropdown(role, (v) => role = v!),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                final success = await provider.createUser(
                  username: username,
                  password: password,
                  fullName: fullName,
                  email: email,
                  phoneNumber: phoneNumber,
                  role: role,
                  unitId: unitId,
                );
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User created successfully'),
                      backgroundColor: Color(0xFF3CCB7F),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          provider.errorMessage ?? 'Failed to create user'),
                      backgroundColor: const Color(0xFFEF5350),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5)),
            child: const Text('Create User'),
          ),
        ],
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
      validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
      onSaved: (v) => onSaved(v!),
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A3040),
          title: const Text('Edit User', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Username (readonly)
                    TextFormField(
                      initialValue: user.username,
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Username (cannot be changed)',
                        labelStyle: const TextStyle(color: Color(0xFF78909C)),
                        filled: true,
                        fillColor: const Color(0xFF1A1F2E).withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(color: Color(0xFF78909C)),
                    ),
                    const SizedBox(height: 12),
                    _buildTextField('Full Name', (v) => fullName = v,
                        required: true, initialValue: fullName),
                    const SizedBox(height: 12),
                    _buildTextField('Email', (v) => email = v,
                        required: true,
                        type: TextInputType.emailAddress,
                        initialValue: email),
                    const SizedBox(height: 12),
                    _buildTextField('Phone Number', (v) => phoneNumber = v,
                        required: true,
                        type: TextInputType.phone,
                        initialValue: phoneNumber),
                    const SizedBox(height: 12),
                    _buildRoleDropdown(role, (v) {
                      setDialogState(() => role = v!);
                    }),
                    const SizedBox(height: 12),
                    // Unit selection for station commanders
                    if (role == 'station_commander') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFF1E88E5).withValues(alpha: 0.3)),
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
                                    color: Color(0xFFB0BEC5), fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Active status toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1F2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF37404F)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Active Status',
                              style: TextStyle(color: Color(0xFF78909C))),
                          Switch(
                            value: isActive,
                            onChanged: (v) =>
                                setDialogState(() => isActive = v),
                            activeThumbColor: const Color(0xFF3CCB7F),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User updated successfully'),
                        backgroundColor: Color(0xFF3CCB7F),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            provider.errorMessage ?? 'Failed to update user'),
                        backgroundColor: const Color(0xFFEF5350),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5)),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleUserStatus(UserModel user, UserProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: Text(
          user.isActive ? 'Deactivate User?' : 'Activate User?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          user.isActive
              ? 'Are you sure you want to deactivate ${user.fullName}?'
              : 'Are you sure you want to activate ${user.fullName}?',
          style: const TextStyle(color: Color(0xFFB0BEC5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: user.isActive
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF3CCB7F),
            ),
            child: Text(user.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success =
          await provider.toggleUserStatus(user.userId, !user.isActive);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'User ${user.isActive ? 'deactivated' : 'activated'} successfully'
                : 'Failed to update user status',
          ),
          backgroundColor:
              success ? const Color(0xFF3CCB7F) : const Color(0xFFEF5350),
        ),
      );
    }
  }
}
