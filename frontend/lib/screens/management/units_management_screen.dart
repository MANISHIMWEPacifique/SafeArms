// Units Management Screen
// Manage police units and stations
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/unit_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/delete_confirmation_dialog.dart';

class UnitsManagementScreen extends StatefulWidget {
  const UnitsManagementScreen({super.key});

  @override
  State<UnitsManagementScreen> createState() => _UnitsManagementScreenState();
}

class _UnitsManagementScreenState extends State<UnitsManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  static const Set<String> _eligibleCommanderRoles = {
    'station_commander',
    'hq_firearm_commander',
  };
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UnitProvider>().loadUnits();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 900;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isNarrow ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Units Management',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Manage police units and stations',
                      style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddUnitDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Unit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Units Management',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage police units and stations across the country',
                          style:
                              TextStyle(color: Color(0xFF78909C), fontSize: 14),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddUnitDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Unit'),
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

          // Filters Row
          isNarrow
              ? Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search units...',
                        hintStyle: const TextStyle(color: Color(0xFF78909C)),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF78909C),
                        ),
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
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3040),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF37404F)),
                      ),
                      child: DropdownButton<String>(
                        value: _typeFilter,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A3040),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(
                              value: 'all', child: Text('All Types')),
                          DropdownMenuItem(
                              value: 'station', child: Text('Police Station')),
                          DropdownMenuItem(
                              value: 'headquarters',
                              child: Text('Headquarters')),
                          DropdownMenuItem(
                              value: 'training_school',
                              child: Text('Training School')),
                          DropdownMenuItem(
                              value: 'special_unit',
                              child: Text('Special Unit')),
                          DropdownMenuItem(
                              value: 'specialized', child: Text('Specialized')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _typeFilter = value ?? 'all';
                          });
                        },
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search units...',
                          hintStyle: const TextStyle(color: Color(0xFF78909C)),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF78909C),
                          ),
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
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Type Filter
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3040),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF37404F)),
                        ),
                        child: DropdownButton<String>(
                          value: _typeFilter,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2A3040),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('All Types')),
                            DropdownMenuItem(
                                value: 'station',
                                child: Text('Police Station')),
                            DropdownMenuItem(
                                value: 'headquarters',
                                child: Text('Headquarters')),
                            DropdownMenuItem(
                                value: 'training_school',
                                child: Text('Training School')),
                            DropdownMenuItem(
                                value: 'special_unit',
                                child: Text('Special Unit')),
                            DropdownMenuItem(
                                value: 'specialized',
                                child: Text('Specialized')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _typeFilter = value ?? 'all';
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 24),

          // Units List
          Consumer<UnitProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Color(0xFFE85C5C),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.error!,
                        style: const TextStyle(color: Color(0xFFE85C5C)),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => provider.loadUnits(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final units = _filterUnits(provider.units);

              if (units.isEmpty) {
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
                        Icon(
                          Icons.business,
                          size: 64,
                          color: Color(0xFF78909C),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No units found',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Add a new unit to get started',
                          style: TextStyle(color: Color(0xFF78909C)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth = isNarrow ? 800.0 : constraints.maxWidth;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Color(0xFF37404F)),
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      'Unit Name',
                                      style: TextStyle(
                                        color: Color(0xFF78909C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Type',
                                      style: TextStyle(
                                        color: Color(0xFF78909C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Location',
                                      style: TextStyle(
                                        color: Color(0xFF78909C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Firearms',
                                      style: TextStyle(
                                        color: Color(0xFF78909C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Officers',
                                      style: TextStyle(
                                        color: Color(0xFF78909C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Color(0xFF78909C),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 80),
                                ],
                              ),
                            ),

                            // Table Body
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: units.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFF37404F),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final unit = units[index];
                                return _buildUnitRow(unit);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  List<dynamic> _filterUnits(List<dynamic> units) {
    return units.where((unit) {
      // Search filter
      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        final name = (unit['unit_name'] ?? '').toString().toLowerCase();
        final location = (unit['location'] ?? '').toString().toLowerCase();
        if (!name.contains(query) && !location.contains(query)) {
          return false;
        }
      }

      // Type filter
      if (_typeFilter != 'all') {
        if (unit['unit_type'] != _typeFilter) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildUnitRow(dynamic unit) {
    // Get stats from unit data (or default to 0)
    final firearmCount = unit['firearm_count'] ?? unit['firearms_count'] ?? 0;
    final officerCount = unit['officer_count'] ?? unit['officers_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1F2E),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getUnitIcon(unit['unit_type']),
                    color: const Color(0xFF1E88E5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _showUnitDetails(unit),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit['unit_name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (unit['commander_name'] != null)
                          Text(
                            'Cmd: ${unit['commander_name']}',
                            style: const TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getTypeColor(unit['unit_type']).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatUnitType(unit['unit_type']),
                style: TextStyle(
                  color: _getTypeColor(unit['unit_type']),
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '${unit['district'] ?? ''}, ${unit['province'] ?? ''}',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Firearms count with icon
          Expanded(
            flex: 1,
            child: Row(
              children: [
                const Icon(Icons.gavel, color: Color(0xFF42A5F5), size: 16),
                const SizedBox(width: 6),
                Text(
                  '$firearmCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Officers count with icon
          Expanded(
            flex: 1,
            child: Row(
              children: [
                const Icon(Icons.badge, color: Color(0xFF3CCB7F), size: 16),
                const SizedBox(width: 6),
                Text(
                  '$officerCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: unit['is_active'] == true
                    ? const Color(0xFF3CCB7F).withValues(alpha: 0.2)
                    : const Color(0xFFE85C5C).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unit['is_active'] == true ? 'Active' : 'Inactive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: unit['is_active'] == true
                      ? const Color(0xFF3CCB7F)
                      : const Color(0xFFE85C5C),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit,
                      color: Color(0xFF78909C), size: 18),
                  onPressed: () => _showEditUnitDialog(unit),
                  tooltip: 'Edit',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFFE85C5C), size: 18),
                  onPressed: () => _confirmDeleteUnit(unit),
                  tooltip: 'Delete',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUnit(dynamic unit) async {
    final confirmed = await DeleteConfirmationDialog.show(
      context,
      title: 'Delete Unit?',
      message: 'You are about to permanently delete',
      itemName: unit['unit_name']?.toString(),
      detail:
          'All officers, firearms, and records associated with this unit will be removed. This cannot be undone.',
      confirmText: 'Delete Unit',
    );

    if (confirmed == true && mounted) {
      final unitProvider = context.read<UnitProvider>();
      final success = await unitProvider.deleteUnit(unit['unit_id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? '${unit['unit_name']} deleted successfully'
                : 'Failed to delete unit'),
            backgroundColor:
                success ? const Color(0xFF3CCB7F) : const Color(0xFFE85C5C),
          ),
        );
      }
    }
  }

  IconData _getUnitIcon(String? type) {
    switch (type) {
      case 'headquarters':
        return Icons.account_balance;
      case 'training_school':
        return Icons.school;
      case 'special_unit':
        return Icons.security;
      case 'specialized':
        return Icons.stars;
      default:
        return Icons.local_police;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'headquarters':
        return const Color(0xFF1E88E5);
      case 'training_school':
        return const Color(0xFFFFC857);
      case 'special_unit':
        return const Color(0xFF9C27B0);
      case 'specialized':
        return const Color(0xFFFF7043);
      default:
        return const Color(0xFF3CCB7F);
    }
  }

  // Valid unit types for dropdowns
  static const List<String> _validUnitTypes = [
    'station',
    'headquarters',
    'training_school',
    'special_unit',
    'specialized',
  ];

  /// Ensure the unit type is a valid dropdown value
  String _sanitizeUnitType(String? type) {
    if (type != null && _validUnitTypes.contains(type)) return type;
    return 'station';
  }

  String _formatUnitType(String? type) {
    switch (type) {
      case 'headquarters':
        return 'Headquarters';
      case 'training_school':
        return 'Training School';
      case 'special_unit':
        return 'Special Unit';
      case 'specialized':
        return 'Specialized';
      case 'station':
        return 'Police Station';
      default:
        return type ?? 'Unknown';
    }
  }

  Future<List<UserModel>> _loadEligibleCommanders() async {
    final users = await _userService.getAllUsers();
    final commanders = users
        .where((user) =>
            user.isActive && _eligibleCommanderRoles.contains(user.role))
        .toList();
    commanders.sort((a, b) => a.fullName.compareTo(b.fullName));
    return commanders;
  }

  String _formatRoleLabel(String role) {
    switch (role) {
      case 'station_commander':
        return 'Station Commander';
      case 'hq_firearm_commander':
        return 'HQ Firearm Commander';
      default:
        return role;
    }
  }

  Future<void> _showAddUnitDialog() async {
    List<UserModel> commanderOptions = [];
    try {
      commanderOptions = await _loadEligibleCommanders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not load commanders. You can still save without one.'),
            backgroundColor: Color(0xFFFFC857),
          ),
        );
      }
    }

    if (!mounted) return;

    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final provinceController = TextEditingController();
    final districtController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String selectedType = 'station';
    String? selectedCommanderUserId;
    bool isActive = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
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
                          child: const Icon(Icons.add_business,
                              color: Color(0xFF3CCB7F), size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add New Unit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Create a new police unit or station',
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
                          // Unit Information Section
                          _buildFormSectionHeader('Unit Information'),
                          const SizedBox(height: 16),
                          _buildDialogTextField(
                              nameController, 'Unit Name', Icons.business),
                          const SizedBox(height: 16),
                          _buildDialogDropdown(
                            value: selectedType,
                            label: 'Unit Type',
                            items: const [
                              DropdownMenuItem(
                                  value: 'station',
                                  child: Text('Police Station')),
                              DropdownMenuItem(
                                  value: 'headquarters',
                                  child: Text('Headquarters')),
                              DropdownMenuItem(
                                  value: 'training_school',
                                  child: Text('Training School')),
                              DropdownMenuItem(
                                  value: 'special_unit',
                                  child: Text('Special Unit')),
                              DropdownMenuItem(
                                  value: 'specialized',
                                  child: Text('Specialized')),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => selectedType = value!),
                          ),
                          const SizedBox(height: 24),

                          // Location Section
                          _buildFormSectionHeader('Location'),
                          const SizedBox(height: 16),
                          _buildDialogTextField(locationController, 'Location',
                              Icons.location_on),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildDialogTextField(
                                      provinceController,
                                      'Province',
                                      Icons.map)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _buildDialogTextField(
                                      districtController,
                                      'District',
                                      Icons.place)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Contact Section
                          _buildFormSectionHeader('Contact Information'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDialogTextField(phoneController,
                                    'Contact Phone', Icons.phone),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDialogTextField(emailController,
                                    'Contact Email', Icons.email),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Commander Assignment Section
                          _buildFormSectionHeader('Commander Assignment'),
                          const SizedBox(height: 16),
                          _buildCommanderDropdown(
                            commanders: commanderOptions,
                            selectedCommanderUserId: selectedCommanderUserId,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedCommanderUserId = value;
                              });
                            },
                          ),
                          const SizedBox(height: 24),

                          // Active Status Toggle
                          _buildStatusToggle(isActive, (value) {
                            setDialogState(() => isActive = value);
                          }),
                          const SizedBox(height: 32),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (nameController.text.isEmpty) {
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text('Unit name is required'),
                                        backgroundColor: Color(0xFFE85C5C)),
                                  );
                                  return;
                                }
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(dialogContext);
                                final unitProvider =
                                    context.read<UnitProvider>();
                                Navigator.pop(dialogContext);
                                final success = await unitProvider.createUnit({
                                  'unit_name': nameController.text,
                                  'unit_type': selectedType,
                                  'location': locationController.text,
                                  'province': provinceController.text,
                                  'district': districtController.text,
                                  'contact_phone': phoneController.text,
                                  'contact_email': emailController.text,
                                  'commander_user_id': selectedCommanderUserId,
                                  'is_active': isActive,
                                });
                                UserModel? selectedCommander;
                                for (final commander in commanderOptions) {
                                  if (commander.userId == selectedCommanderUserId) {
                                    selectedCommander = commander;
                                    break;
                                  }
                                }
                                final stationCommanderBound =
                                    selectedCommander?.role ==
                                        'station_commander';

                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? stationCommanderBound
                                            ? 'Unit created and selected Station Commander was assigned to this unit.'
                                            : 'Unit created successfully'
                                        : 'Failed to create unit'),
                                    backgroundColor: success
                                        ? const Color(0xFF3CCB7F)
                                        : const Color(0xFFE85C5C),
                                  ),
                                );
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
                                'Create Unit',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditUnitDialog(dynamic unit) async {
    List<UserModel> commanderOptions = [];
    try {
      commanderOptions = await _loadEligibleCommanders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not load commanders. You can still keep current assignment.'),
            backgroundColor: Color(0xFFFFC857),
          ),
        );
      }
    }

    if (!mounted) return;

    final nameController = TextEditingController(text: unit['unit_name'] ?? '');
    final locationController =
        TextEditingController(text: unit['location'] ?? '');
    final provinceController =
        TextEditingController(text: unit['province'] ?? '');
    final districtController =
        TextEditingController(text: unit['district'] ?? '');
    final phoneController =
        TextEditingController(text: unit['contact_phone'] ?? '');
    final emailController =
        TextEditingController(text: unit['contact_email'] ?? '');
    String selectedType = _sanitizeUnitType(unit['unit_type']);
    String? selectedCommanderUserId = unit['commander_user_id'] as String?;
    bool isActive = unit['is_active'] ?? true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Center(
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
                                'Edit Unit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                unit['unit_name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                          // Unit Information Section
                          _buildFormSectionHeader('Unit Information'),
                          const SizedBox(height: 16),
                          _buildDialogTextField(
                              nameController, 'Unit Name', Icons.business),
                          const SizedBox(height: 16),
                          _buildDialogDropdown(
                            value: selectedType,
                            label: 'Unit Type',
                            items: const [
                              DropdownMenuItem(
                                  value: 'station',
                                  child: Text('Police Station')),
                              DropdownMenuItem(
                                  value: 'headquarters',
                                  child: Text('Headquarters')),
                              DropdownMenuItem(
                                  value: 'training_school',
                                  child: Text('Training School')),
                              DropdownMenuItem(
                                  value: 'special_unit',
                                  child: Text('Special Unit')),
                              DropdownMenuItem(
                                  value: 'specialized',
                                  child: Text('Specialized')),
                            ],
                            onChanged: (value) =>
                                setDialogState(() => selectedType = value!),
                          ),
                          const SizedBox(height: 24),

                          // Location Section
                          _buildFormSectionHeader('Location'),
                          const SizedBox(height: 16),
                          _buildDialogTextField(locationController, 'Location',
                              Icons.location_on),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildDialogTextField(
                                      provinceController,
                                      'Province',
                                      Icons.map)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _buildDialogTextField(
                                      districtController,
                                      'District',
                                      Icons.place)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Contact Section
                          _buildFormSectionHeader('Contact Information'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDialogTextField(phoneController,
                                    'Contact Phone', Icons.phone),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDialogTextField(emailController,
                                    'Contact Email', Icons.email),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Commander Assignment Section
                          _buildFormSectionHeader('Commander Assignment'),
                          const SizedBox(height: 16),
                          _buildCommanderDropdown(
                            commanders: commanderOptions,
                            selectedCommanderUserId: selectedCommanderUserId,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedCommanderUserId = value;
                              });
                            },
                            legacyCommanderName:
                                unit['commander_name']?.toString(),
                          ),
                          const SizedBox(height: 24),

                          // Active Status Toggle
                          _buildStatusToggle(isActive, (value) {
                            setDialogState(() => isActive = value);
                          }),
                          const SizedBox(height: 32),

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                if (nameController.text.isEmpty) {
                                  ScaffoldMessenger.of(dialogContext)
                                      .showSnackBar(
                                    const SnackBar(
                                        content: Text('Unit name is required'),
                                        backgroundColor: Color(0xFFE85C5C)),
                                  );
                                  return;
                                }
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(dialogContext);
                                final unitProvider =
                                    context.read<UnitProvider>();
                                Navigator.pop(dialogContext);
                                final success = await unitProvider.updateUnit(
                                  unit['unit_id'].toString(),
                                  {
                                    'unit_name': nameController.text,
                                    'unit_type': selectedType,
                                    'location': locationController.text,
                                    'province': provinceController.text,
                                    'district': districtController.text,
                                    'contact_phone': phoneController.text,
                                    'contact_email': emailController.text,
                                    'commander_user_id':
                                        selectedCommanderUserId,
                                    'is_active': isActive,
                                  },
                                );
                                UserModel? selectedCommander;
                                for (final commander in commanderOptions) {
                                  if (commander.userId == selectedCommanderUserId) {
                                    selectedCommander = commander;
                                    break;
                                  }
                                }
                                final stationCommanderBound =
                                    selectedCommander?.role ==
                                        'station_commander';

                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? stationCommanderBound
                                            ? 'Unit updated and selected Station Commander is now assigned to this unit.'
                                            : 'Unit updated successfully'
                                        : 'Failed to update unit'),
                                    backgroundColor: success
                                        ? const Color(0xFF3CCB7F)
                                        : const Color(0xFFE85C5C),
                                  ),
                                );
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStatusToggle(bool isActive, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: isActive
                    ? const Color(0xFF3CCB7F)
                    : const Color(0xFFE85C5C),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'Active Status',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          Switch(
            value: isActive,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF3CCB7F),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogTextField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E88E5))),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE85C5C))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE85C5C))),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String value,
    required String label,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: const Color(0xFF2A3040),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.category, color: Colors.white54, size: 20),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E88E5))),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE85C5C))),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE85C5C))),
      ),
    );
  }

  Widget _buildCommanderDropdown({
    required List<UserModel> commanders,
    required String? selectedCommanderUserId,
    required void Function(String?) onChanged,
    String? legacyCommanderName,
  }) {
    final hasLegacyValue = selectedCommanderUserId == null &&
        legacyCommanderName != null &&
        legacyCommanderName.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: selectedCommanderUserId,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Not assigned'),
            ),
            ...commanders.map((commander) => DropdownMenuItem<String?>(
                  value: commander.userId,
                  child: Text(
                    '${commander.fullName} (${_formatRoleLabel(commander.role)})',
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
          onChanged: onChanged,
          dropdownColor: const Color(0xFF2A3040),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Unit Commander (Optional)',
            labelStyle: const TextStyle(color: Colors.white54),
            prefixIcon:
                const Icon(Icons.person_pin, color: Colors.white54, size: 20),
            filled: true,
            fillColor: const Color(0xFF1A1F2E),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF37404F))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF37404F))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1E88E5))),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Selecting a Station Commander also assigns that user to this unit.',
          style: TextStyle(
            color: Color(0xFF78909C),
            fontSize: 12,
          ),
        ),
        if (hasLegacyValue) ...[
          const SizedBox(height: 8),
          Text(
            'Current legacy commander: $legacyCommanderName',
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  void _showUnitDetails(dynamic unit) {
    final firearmCount = unit['firearm_count'] ?? unit['firearms_count'] ?? 0;
    final officerCount = unit['officer_count'] ?? unit['officers_count'] ?? 0;

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
                        child: Icon(
                          _getUnitIcon(unit['unit_type']),
                          color: const Color(0xFF1E88E5),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'View unit information',
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
                        // Unit Icon & Name
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor:
                                    _getTypeColor(unit['unit_type'])
                                        .withValues(alpha: 0.2),
                                child: Icon(
                                  _getUnitIcon(unit['unit_type']),
                                  color: _getTypeColor(unit['unit_type']),
                                  size: 36,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                unit['unit_name'] ?? 'Unknown',
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
                                  color: unit['is_active'] == true
                                      ? const Color(0xFF3CCB7F)
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFFE85C5C)
                                          .withValues(alpha: 0.15),
                                ),
                                child: Text(
                                  unit['is_active'] == true
                                      ? 'Active'
                                      : 'Inactive',
                                  style: TextStyle(
                                    color: unit['is_active'] == true
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
                        _buildDetailSection('Basic Information', [
                          _buildDetailRow(
                              'Unit Name', unit['unit_name'] ?? 'N/A'),
                          _buildDetailRow(
                              'Type', _formatUnitType(unit['unit_type'])),
                          _buildDetailRow('Commander',
                              unit['commander_name'] ?? 'Not assigned'),
                        ]),
                        const SizedBox(height: 24),
                        _buildDetailSection('Location', [
                          _buildDetailRow('Address', unit['location'] ?? 'N/A'),
                          _buildDetailRow(
                              'Province', unit['province'] ?? 'N/A'),
                          _buildDetailRow(
                              'District', unit['district'] ?? 'N/A'),
                        ]),
                        const SizedBox(height: 24),
                        _buildDetailSection('Contact Information', [
                          _buildDetailRow(
                              'Phone', unit['contact_phone'] ?? 'N/A'),
                          _buildDetailRow(
                              'Email', unit['contact_email'] ?? 'N/A'),
                        ]),
                        const SizedBox(height: 24),
                        _buildDetailSection('Statistics', [
                          _buildDetailRow('Firearms', '$firearmCount'),
                          _buildDetailRow('Officers', '$officerCount'),
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
}
