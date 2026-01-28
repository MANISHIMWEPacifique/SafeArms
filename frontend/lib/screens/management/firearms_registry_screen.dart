import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firearm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/firearm_model.dart';
import '../../widgets/register_firearm_modal.dart';
import '../../widgets/firearm_detail_modal.dart';

class FirearmsRegistryScreen extends StatefulWidget {
  const FirearmsRegistryScreen({Key? key}) : super(key: key);

  @override
  State<FirearmsRegistryScreen> createState() => _FirearmsRegistryScreenState();
}

class _FirearmsRegistryScreenState extends State<FirearmsRegistryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showRegisterModal = false;
  FirearmModel? _selectedFirearmForDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final role = authProvider.currentUser?['role'] as String?;
      String? unitId;
      if (role == 'station_commander') {
        unitId = authProvider.currentUser?['unit_id'] as String?;
      }

      context.read<FirearmProvider>().loadFirearms(unitId: unitId);
      context.read<FirearmProvider>().loadStats(unitId: unitId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firearmProvider = context.watch<FirearmProvider>();
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.currentUser?['role'] as String?;
    final isHQCommander = userRole == 'hq_firearm_commander';
    final isForensicAnalyst = userRole == 'forensic_analyst';
    final isAdmin = userRole == 'admin';
    // HQ Commander, Forensic Analyst, and Admin see national registry
    final hasNationalAccess = isHQCommander || isForensicAnalyst || isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildTopNavBar(context, firearmProvider, isHQCommander,
                        hasNationalAccess, isForensicAnalyst),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFilterBar(
                                  firearmProvider, hasNationalAccess),
                              const SizedBox(height: 24),
                              _buildStatsBar(firearmProvider),
                              const SizedBox(height: 24),
                              firearmProvider.isGridView
                                  ? _buildGridView(firearmProvider)
                                  : _buildListView(firearmProvider),
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

          // Modal Overlays
          if (_showRegisterModal)
            RegisterFirearmModal(
              onClose: () => setState(() => _showRegisterModal = false),
              onSuccess: () {
                setState(() => _showRegisterModal = false);
                firearmProvider.loadFirearms();
                firearmProvider.loadStats();
              },
            ),

          if (_selectedFirearmForDetail != null)
            FirearmDetailModal(
              firearm: _selectedFirearmForDetail!,
              onClose: () => setState(() => _selectedFirearmForDetail = null),
              onEdit: () {
                setState(() {
                  _selectedFirearmForDetail = null;
                  _showRegisterModal = true;
                });
                firearmProvider.selectFirearm(_selectedFirearmForDetail!);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context, FirearmProvider provider,
      bool isHQCommander, bool hasNationalAccess, bool isForensicAnalyst) {
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
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasNationalAccess
                    ? 'National Firearms Registry'
                    : 'Unit Firearms Inventory',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    hasNationalAccess ? 'Home / Firearms' : 'Unit / Firearms',
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 14),
                  ),
                  if (isForensicAnalyst) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF42A5F5).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Read-Only',
                        style: TextStyle(
                            color: Color(0xFF42A5F5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 320,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => provider.setSearchQuery(value),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search by serial number, model, unit...',
                hintStyle: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: Color(0xFF78909C), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (isHQCommander)
            ElevatedButton.icon(
              onPressed: () => setState(() => _showRegisterModal = true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Register Firearm',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(FirearmProvider provider, bool hasNationalAccess) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              label: 'Status',
              value: provider.statusFilter,
              items: const [
                {'value': 'all', 'label': 'All Status'},
                {'value': 'available', 'label': 'Available'},
                {'value': 'in_custody', 'label': 'In Custody'},
                {'value': 'maintenance', 'label': 'Maintenance'},
                {'value': 'lost', 'label': 'Lost'},
                {'value': 'stolen', 'label': 'Stolen'},
                {'value': 'destroyed', 'label': 'Destroyed'},
                {'value': 'unassigned', 'label': 'Unassigned'},
              ],
              onChanged: (value) => provider.setStatusFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Firearm Type',
              value: provider.typeFilter,
              items: const [
                {'value': 'all', 'label': 'All Types'},
                {'value': 'pistol', 'label': 'Pistol'},
                {'value': 'rifle', 'label': 'Rifle'},
                {'value': 'shotgun', 'label': 'Shotgun'},
                {'value': 'submachine_gun', 'label': 'Submachine Gun'},
                {'value': 'other', 'label': 'Other'},
              ],
              onChanged: (value) => provider.setTypeFilter(value ?? 'all'),
            ),
          ),
          if (hasNationalAccess) ...[
            const SizedBox(width: 16),
            Expanded(
              child: _buildFilterDropdown(
                label: 'Assigned Unit',
                value: provider.unitFilter,
                items: const [
                  {'value': 'all', 'label': 'All Units'},
                  // Would load from units API
                ],
                onChanged: (value) => provider.setUnitFilter(value ?? 'all'),
              ),
            ),
          ],
          const SizedBox(width: 16),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Manufacturer',
              value: provider.manufacturerFilter,
              items: const [
                {'value': 'all', 'label': 'All'},
                {'value': 'Glock', 'label': 'Glock'},
                {'value': 'Beretta', 'label': 'Beretta'},
                {'value': 'H&K', 'label': 'H&K'},
                {'value': 'SIG Sauer', 'label': 'SIG Sauer'},
              ],
              onChanged: (value) =>
                  provider.setManufacturerFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      provider.isGridView ? Icons.grid_view : Icons.view_list,
                      color: const Color(0xFF1E88E5),
                    ),
                    onPressed: () => provider.toggleViewMode(),
                    tooltip: provider.isGridView
                        ? 'Switch to List View'
                        : 'Switch to Grid View',
                  ),
                  TextButton.icon(
                    onPressed: () => provider.clearFilters(),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64B5F6)),
                  ),
                ],
              ),
            ],
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
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
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
              items: items
                  .map((item) => DropdownMenuItem<String>(
                        value: item['value'],
                        child: Text(item['label']!),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(FirearmProvider provider) {
    final stats = provider.stats;

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
            icon: Icons.inventory_2,
            iconColor: const Color(0xFF1E88E5),
            number: '${stats['total'] ?? provider.firearms.length}',
            label: 'Total Registered',
            percentage: null,
          ),
          _buildDivider(),
          _buildStatCard(
            icon: Icons.check_circle,
            iconColor: const Color(0xFF3CCB7F),
            number: '${stats['available'] ?? 0}',
            label: 'Available',
            percentage: '${stats['available_percentage'] ?? 0}%',
            percentageColor: const Color(0xFF3CCB7F),
          ),
          _buildDivider(),
          _buildStatCard(
            icon: Icons.badge,
            iconColor: const Color(0xFF42A5F5),
            number: '${stats['in_custody'] ?? 0}',
            label: 'In Custody',
            percentage: '${stats['custody_percentage'] ?? 0}%',
            percentageColor: const Color(0xFF42A5F5),
          ),
          _buildDivider(),
          _buildStatCard(
            icon: Icons.build,
            iconColor: const Color(0xFFFFC857),
            number: '${stats['maintenance'] ?? 0}',
            label: 'Maintenance',
            percentage: null,
          ),
          _buildDivider(),
          _buildStatCard(
            icon: Icons.warning,
            iconColor: const Color(0xFFE85C5C),
            number: '${stats['lost_stolen'] ?? 0}',
            label: 'Lost/Stolen',
            percentage: null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String number,
    required String label,
    String? percentage,
    Color? percentageColor,
  }) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFFB0BEC5), fontSize: 13)),
                if (percentage != null)
                  Text(
                    percentage,
                    style: TextStyle(
                        color: percentageColor ?? const Color(0xFF78909C),
                        fontSize: 12),
                  ),
              ],
            ),
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

  Widget _buildGridView(FirearmProvider provider) {
    if (provider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    final firearms = provider.paginatedFirearms;

    if (firearms.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.58,
          ),
          itemCount: firearms.length,
          itemBuilder: (context, index) => _buildFirearmCard(firearms[index]),
        ),
        const SizedBox(height: 24),
        _buildPagination(provider),
      ],
    );
  }

  Widget _buildFirearmCard(FirearmModel firearm) {
    return InkWell(
      onTap: () {
        setState(() => _selectedFirearmForDetail = firearm);
      },
      hoverColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2A3040),
          border: Border.all(color: const Color(0xFF37404F)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header with status badges
            Row(
              children: [
                _buildStatusBadge(firearm.currentStatus),
                const Spacer(),
                _buildRegistrationLevelBadge(firearm.registrationLevel),
              ],
            ),
            const SizedBox(height: 16),

            // Firearm icon
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xFF252A3A),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getFirearmIcon(firearm.firearmType),
                  color: const Color(0xFF42A5F5),
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Firearm details
            Text(
              '${firearm.manufacturer} ${firearm.model}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    firearm.serialNumber,
                    style: const TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 14,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy,
                      size: 16, color: Color(0xFF78909C)),
                  onPressed: () {
                    // Copy serial number
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF37404F), height: 32),

            // Specifications
            _buildSpecRow('Type', _formatFirearmType(firearm.firearmType)),
            _buildSpecRow('Caliber', firearm.caliber ?? 'N/A'),
            _buildSpecRow('Year', firearm.manufactureYear?.toString() ?? 'N/A'),
            _buildSpecRow('Acquired', _formatDate(firearm.acquisitionDate)),

            const SizedBox(height: 16),

            // Assignment section
            if (firearm.assignedUnitId != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A3A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business,
                        color: Color(0xFF42A5F5), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assigned Unit',
                            style: TextStyle(
                                color: Color(0xFF78909C), fontSize: 11),
                          ),
                          Text(
                            firearm.assignedUnitId!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // View details
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      side: const BorderSide(color: Color(0xFF1E88E5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('View Details',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.edit,
                      size: 18, color: Color(0xFF78909C)),
                  onPressed: () {
                    // Edit firearm
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Color(0xFF78909C)),
                  onPressed: () {
                    // More actions
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12)),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    String displayText;

    switch (status) {
      case 'available':
        backgroundColor = const Color(0xFF3CCB7F);
        displayText = 'AVAILABLE';
        break;
      case 'in_custody':
        backgroundColor = const Color(0xFF42A5F5);
        displayText = 'IN CUSTODY';
        break;
      case 'maintenance':
        backgroundColor = const Color(0xFFFFC857);
        displayText = 'MAINTENANCE';
        break;
      case 'lost':
      case 'stolen':
        backgroundColor = const Color(0xFFE85C5C);
        displayText = status.toUpperCase();
        break;
      case 'unassigned':
        backgroundColor = const Color(0xFF78909C);
        displayText = 'UNASSIGNED';
        break;
      default:
        backgroundColor = const Color(0xFF78909C);
        displayText = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRegistrationLevelBadge(String level) {
    final isHQ = level == 'hq';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
            color: isHQ ? const Color(0xFF1E88E5) : const Color(0xFF3CCB7F)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHQ ? Icons.domain : Icons.business,
            size: 12,
            color: isHQ ? const Color(0xFF1E88E5) : const Color(0xFF3CCB7F),
          ),
          const SizedBox(width: 4),
          Text(
            isHQ ? 'HQ' : 'UNIT',
            style: TextStyle(
              color: isHQ ? const Color(0xFF1E88E5) : const Color(0xFF3CCB7F),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(FirearmProvider provider) {
    // Placeholder - would implement similar to User Management table
    return const Center(
      child: Text(
        'List view implementation',
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64, color: const Color(0xFF78909C)),
          const SizedBox(height: 16),
          const Text(
            'No firearms found',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or register a new firearm',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(FirearmProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(provider.currentPage - 1) * provider.itemsPerPage + 1}-'
            '${(provider.currentPage * provider.itemsPerPage).clamp(0, provider.totalItems)} '
            'of ${provider.totalItems} firearms',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                color: provider.currentPage > 1
                    ? const Color(0xFFB0BEC5)
                    : const Color(0xFF37404F),
                onPressed: provider.currentPage > 1
                    ? () => provider.previousPage()
                    : null,
              ),
              ...List.generate(
                provider.totalPages.clamp(0, 5),
                (index) {
                  final page = index + 1;
                  final isActive = page == provider.currentPage;
                  return InkWell(
                    onTap: () => provider.setPage(page),
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
                color: provider.currentPage < provider.totalPages
                    ? const Color(0xFFB0BEC5)
                    : const Color(0xFF37404F),
                onPressed: provider.currentPage < provider.totalPages
                    ? () => provider.nextPage()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFirearmIcon(String type) {
    switch (type) {
      case 'pistol':
        return Icons.sports_martial_arts;
      case 'rifle':
        return Icons.yard;
      case 'shotgun':
        return Icons.wifi_protected_setup;
      default:
        return Icons.hardware;
    }
  }

  String _formatFirearmType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
