import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../providers/firearm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/firearm_model.dart';
import '../../widgets/register_firearm_modal.dart';
import '../../widgets/firearm_detail_modal.dart';
import '../../widgets/filter_dropdown_widget.dart';
import '../../widgets/empty_state_widget.dart';

class FirearmsRegistryScreen extends StatefulWidget {
  const FirearmsRegistryScreen({super.key});

  @override
  State<FirearmsRegistryScreen> createState() => _FirearmsRegistryScreenState();
}

class _FirearmsRegistryScreenState extends State<FirearmsRegistryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showRegisterModal = false;
  FirearmModel? _selectedFirearmForDetail;
  FirearmModel? _firearmToEdit;

  static const double _desktopLayoutBreakpoint = 1024;

  bool get _isInvestigator {
    final authProvider = context.read<AuthProvider>();
    return authProvider.currentUser?['role'] == 'investigator';
  }

  bool get _canDeleteFirearm {
    final authProvider = context.read<AuthProvider>();
    return authProvider.currentUser?['role'] == 'hq_firearm_commander';
  }

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
    final isInvestigator = userRole == 'investigator';
    final isAdmin = userRole == 'admin';
    // HQ Commander, Investigator, and Admin see national registry
    final hasNationalAccess = isHQCommander || isInvestigator || isAdmin;

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
                        hasNationalAccess, isInvestigator),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFilterBar(
                                  firearmProvider, hasNationalAccess),
                              const SizedBox(height: 24),
                              _buildStatsBar(firearmProvider),
                              const SizedBox(height: 24),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 240),
                                transitionBuilder: (child, animation) {
                                  final scale = Tween<double>(
                                          begin: 0.97, end: 1.0)
                                      .animate(CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOut));
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                        scale: scale, child: child),
                                  );
                                },
                                child: firearmProvider.isGridView
                                    ? KeyedSubtree(
                                        key: const ValueKey('grid'),
                                        child:
                                            _buildGridView(firearmProvider))
                                    : KeyedSubtree(
                                        key: const ValueKey('list'),
                                        child:
                                            _buildListView(firearmProvider)),
                              ),
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
              firearm: _firearmToEdit,
              onClose: () => setState(() {
                _showRegisterModal = false;
                _firearmToEdit = null;
              }),
              onSuccess: () {
                setState(() {
                  _showRegisterModal = false;
                  _firearmToEdit = null;
                });
                firearmProvider.loadFirearms();
                firearmProvider.loadStats();
              },
            ),

          if (_selectedFirearmForDetail != null)
            FirearmDetailModal(
              firearm: _selectedFirearmForDetail!,
              onClose: () => setState(() => _selectedFirearmForDetail = null),
              onEdit: isInvestigator
                  ? null
                  : () {
                      final firearmToEdit = _selectedFirearmForDetail;
                      setState(() {
                        _selectedFirearmForDetail = null;
                        _firearmToEdit = firearmToEdit;
                        _showRegisterModal = true;
                      });
                    },
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context, FirearmProvider provider,
      bool isHQCommander, bool hasNationalAccess, bool isInvestigator) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF252A3A),
            border: Border(
              bottom: BorderSide(color: Color(0xFF37404F), width: 1),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isNarrow ? 16 : 32,
            vertical: 8,
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hasNationalAccess
                                ? 'National Firearms Registry'
                                : 'Unit Firearms Inventory',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isHQCommander)
                          ElevatedButton.icon(
                            onPressed: () => setState(() {
                              _firearmToEdit = null;
                              _showRegisterModal = true;
                            }),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Register',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E88E5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3040),
                        border: Border.all(color: const Color(0xFF37404F)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => provider.setSearchQuery(value),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search...',
                          hintStyle:
                              TextStyle(color: Color(0xFF78909C), fontSize: 14),
                          prefixIcon: Icon(Icons.search,
                              color: Color(0xFF78909C), size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
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
                              hasNationalAccess
                                  ? 'Home / Firearms'
                                  : 'Unit / Firearms',
                              style: const TextStyle(
                                  color: Color(0xFF78909C), fontSize: 14),
                            ),
                            if (isInvestigator) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF42A5F5)
                                      .withValues(alpha: 0.2),
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
                      width: 300,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3040),
                        border: Border.all(color: const Color(0xFF37404F)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => provider.setSearchQuery(value),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search by serial number, model, unit...',
                          hintStyle:
                              TextStyle(color: Color(0xFF78909C), fontSize: 14),
                          prefixIcon: Icon(Icons.search,
                              color: Color(0xFF78909C), size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (isHQCommander)
                      ElevatedButton.icon(
                        onPressed: () => setState(() {
                          _firearmToEdit = null;
                          _showRegisterModal = true;
                        }),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Register Firearm',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                  ],
                ),
        );
      },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth < _desktopLayoutBreakpoint;
          final dropdowns = [
            _buildFilterDropdown(
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
            _buildFilterDropdown(
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
            if (hasNationalAccess)
              _buildFilterDropdown(
                label: 'Assigned Unit',
                value: provider.unitFilter,
                items: const [
                  {'value': 'all', 'label': 'All Units'},
                ],
                onChanged: (value) => provider.setUnitFilter(value ?? 'all'),
              ),
            _buildFilterDropdown(
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
          ];

          final actionButtons = Row(
            mainAxisSize: MainAxisSize.min,
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
          );

          if (isTablet) {
            final itemWidth = constraints.maxWidth < 700
                ? constraints.maxWidth
                : constraints.maxWidth < 1000
                    ? (constraints.maxWidth - 12) / 2
                    : (constraints.maxWidth - 24) / 3;

            return Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: dropdowns.whereType<Widget>().map((d) {
                    return SizedBox(
                      width: itemWidth,
                      child: d,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: actionButtons),
              ],
            );
          }

          return Row(
            children: [
              for (int i = 0; i < dropdowns.length; i++) ...[
                Expanded(child: dropdowns[i]),
                if (i < dropdowns.length - 1) const SizedBox(width: 16),
              ],
              const SizedBox(width: 16),
              actionButtons,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
  }) {
    return FilterDropdownWidget(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildStatsBar(FirearmProvider provider) {
    final stats = provider.stats;

    final statItems = [
      _StatCardData(
        icon: Icons.inventory_2,
        iconColor: const Color(0xFF1E88E5),
        number: '${stats['total'] ?? provider.firearms.length}',
        label: 'Total Registered',
      ),
      _StatCardData(
        icon: Icons.check_circle,
        iconColor: const Color(0xFF3CCB7F),
        number: '${stats['available'] ?? 0}',
        label: 'Available',
        percentage: '${stats['available_percentage'] ?? 0}%',
        percentageColor: const Color(0xFF3CCB7F),
      ),
      _StatCardData(
        icon: Icons.badge,
        iconColor: const Color(0xFF42A5F5),
        number: '${stats['in_custody'] ?? 0}',
        label: 'In Custody',
        percentage: '${stats['custody_percentage'] ?? 0}%',
        percentageColor: const Color(0xFF42A5F5),
      ),
      _StatCardData(
        icon: Icons.build,
        iconColor: const Color(0xFFFFC857),
        number: '${stats['maintenance'] ?? 0}',
        label: 'Maintenance',
      ),
      _StatCardData(
        icon: Icons.warning,
        iconColor: const Color(0xFFE85C5C),
        number: '${stats['lost_stolen'] ?? 0}',
        label: 'Lost/Stolen',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopLayoutBreakpoint;

        if (isDesktop) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF252A3A),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(children: _buildDesktopStatWidgets(statItems)),
          );
        }

        final cardWidth = constraints.maxWidth < 760
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            border: Border.all(color: const Color(0xFF37404F)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: statItems
                .map((item) => SizedBox(
                      width: cardWidth,
                      child: _buildTabletStatCard(
                        icon: item.icon,
                        iconColor: item.iconColor,
                        number: item.number,
                        label: item.label,
                        percentage: item.percentage,
                        percentageColor: item.percentageColor,
                      ),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  List<Widget> _buildDesktopStatWidgets(List<_StatCardData> statItems) {
    final widgets = <Widget>[];

    for (int i = 0; i < statItems.length; i++) {
      widgets.add(
        _buildStatCard(
          icon: statItems[i].icon,
          iconColor: statItems[i].iconColor,
          number: statItems[i].number,
          label: statItems[i].label,
          percentage: statItems[i].percentage,
          percentageColor: statItems[i].percentageColor,
        ),
      );

      if (i < statItems.length - 1) {
        widgets.add(_buildDivider());
      }
    }

    return widgets;
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

  Widget _buildTabletStatCard({
    required IconData icon,
    required Color iconColor,
    required String number,
    required String label,
    String? percentage,
    Color? percentageColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF37404F), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
                if (percentage != null)
                  Text(
                    percentage,
                    style: TextStyle(
                      color: percentageColor ?? const Color(0xFF78909C),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
        LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount;
            if (constraints.maxWidth >= 1200) {
              crossAxisCount = 4;
            } else if (constraints.maxWidth >= 900) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth >= 600) {
              crossAxisCount = 2;
            } else {
              crossAxisCount = 1;
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth < 600 ? 0.88 : 0.83,
              ),
              itemCount: firearms.length,
              itemBuilder: (context, index) =>
                  _buildFirearmCard(firearms[index]),
            );
          },
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
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 8),

            // Firearm icon
            Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  color: Color(0xFF252A3A),
                  shape: BoxShape.circle,
                ),
                child: _buildFirearmIndicator(firearm,
                    size: 60, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 8),

            // Firearm details
            Text(
              '${firearm.manufacturer} ${firearm.model}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
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
                    Clipboard.setData(
                        ClipboardData(text: firearm.serialNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Serial number copied: ${firearm.serialNumber}'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF3CCB7F),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const Divider(color: Color(0xFF37404F), height: 16),

            // Specifications
            _buildSpecRow('Type', _formatFirearmType(firearm.firearmType)),
            _buildSpecRow('Caliber', firearm.caliber ?? 'N/A'),
            _buildSpecRow('Year', firearm.manufactureYear?.toString() ?? 'N/A'),

            const SizedBox(height: 12),

            // Assignment section
            if (firearm.assignedUnitId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business,
                        color: Color(0xFF42A5F5), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assigned Unit',
                            style: TextStyle(
                                color: Color(0xFF78909C), fontSize: 10),
                          ),
                          Text(
                            firearm.unitDisplayName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (firearm.assignedUnitId == null)
              Container(height: 38), // placeholder to keep card height consistent

            const Spacer(),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _selectedFirearmForDetail = firearm);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      side: const BorderSide(color: Color(0xFF1E88E5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('View Details',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
                if (!_isInvestigator) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: Color(0xFF78909C)),
                    onPressed: () {
                      setState(() {
                        _firearmToEdit = firearm;
                        _showRegisterModal = true;
                      });
                    },
                  ),
                  if (_canDeleteFirearm)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFE85C5C)),
                      tooltip: 'Delete firearm',
                      onPressed: () => _confirmDeleteFirearm(firearm),
                    ),
                ],
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
    if (provider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    final firearms = provider.paginatedFirearms;

    if (firearms.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopLayoutBreakpoint;

        if (isDesktop) {
          return Column(
            children: [
              // Table header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF252A3A),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF37404F), width: 1),
                  ),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 48),
                    Expanded(
                      flex: 3,
                      child: Text('SERIAL / MODEL',
                          style: TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('TYPE / CALIBER',
                          style: TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('UNIT',
                          style: TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('LEVEL',
                          style: TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('STATUS',
                          style: TextStyle(
                              color: Color(0xFF78909C),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8)),
                    ),
                    SizedBox(width: 80),
                  ],
                ),
              ),
              // Table rows
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: firearms.length,
                itemBuilder: (context, index) =>
                    _buildFirearmListRow(firearms[index], index),
              ),
              const SizedBox(height: 24),
              _buildPagination(provider),
            ],
          );
        }

        return Column(
          children: [
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: firearms.length,
              itemBuilder: (context, index) =>
                  _buildTabletFirearmCard(firearms[index], index),
            ),
            const SizedBox(height: 24),
            _buildPagination(provider),
          ],
        );
      },
    );
  }

  Widget _buildTabletFirearmCard(FirearmModel firearm, int index) {
    return InkWell(
      onTap: () => setState(() => _selectedFirearmForDetail = firearm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              index.isEven ? const Color(0xFF252A3A) : const Color(0xFF232838),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF37404F), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A3040),
                    shape: BoxShape.circle,
                  ),
                  child: _buildFirearmIndicator(firearm, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firearm.serialNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${firearm.manufacturer} ${firearm.model}',
                        style: const TextStyle(
                            color: Color(0xFF78909C), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(firearm.currentStatus),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  _formatFirearmType(firearm.firearmType),
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
                ),
                Text(
                  firearm.caliber ?? 'N/A',
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
                ),
                Text(
                  firearm.unitDisplayName,
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 12),
                ),
                _buildRegistrationLevelBadge(firearm.registrationLevel),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        setState(() => _selectedFirearmForDetail = firearm),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1E88E5),
                      side: const BorderSide(color: Color(0xFF1E88E5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('View', style: TextStyle(fontSize: 12)),
                  ),
                ),
                if (!_isInvestigator) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: Color(0xFF78909C)),
                    onPressed: () {
                      setState(() {
                        _firearmToEdit = firearm;
                        _showRegisterModal = true;
                      });
                    },
                    tooltip: 'Edit',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (_canDeleteFirearm) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFE85C5C)),
                      tooltip: 'Delete firearm',
                      onPressed: () => _confirmDeleteFirearm(firearm),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirearmListRow(FirearmModel firearm, int index) {
    return InkWell(
      onTap: () => setState(() => _selectedFirearmForDetail = firearm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color:
              index.isEven ? const Color(0xFF252A3A) : const Color(0xFF232838),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF37404F), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF2A3040),
                shape: BoxShape.circle,
              ),
              child: _buildFirearmIndicator(firearm, size: 18),
            ),
            // Serial / Model
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firearm.serialNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${firearm.manufacturer} ${firearm.model}',
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Type / Caliber
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatFirearmType(firearm.firearmType),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    firearm.caliber ?? 'N/A',
                    style:
                        const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                  ),
                ],
              ),
            ),
            // Unit
            Expanded(
              flex: 2,
              child: Text(
                firearm.unitDisplayName,
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Registration Level
            Expanded(
              flex: 1,
              child: _buildRegistrationLevelBadge(firearm.registrationLevel),
            ),
            // Status
            Expanded(
              flex: 1,
              child: _buildStatusBadge(firearm.currentStatus),
            ),
            // Actions
            SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility,
                        size: 18, color: Color(0xFF42A5F5)),
                    onPressed: () =>
                        setState(() => _selectedFirearmForDetail = firearm),
                    tooltip: 'View Details',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (!_isInvestigator) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.edit,
                          size: 18, color: Color(0xFF78909C)),
                      onPressed: () {
                        setState(() {
                          _firearmToEdit = firearm;
                          _showRegisterModal = true;
                        });
                      },
                      tooltip: 'Edit',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (_canDeleteFirearm) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: Color(0xFFE85C5C)),
                        onPressed: () => _confirmDeleteFirearm(firearm),
                        tooltip: 'Delete firearm',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.inventory_2_outlined,
      title: 'No firearms found',
      subtitle: 'Try adjusting your filters or register a new firearm',
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth < 900;
          final summaryText =
              'Showing ${(provider.currentPage - 1) * provider.itemsPerPage + 1}-'
              '${(provider.currentPage * provider.itemsPerPage).clamp(0, provider.totalItems)} '
              'of ${provider.totalItems} firearms';

          final controls = Row(
            mainAxisSize: MainAxisSize.min,
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
          );

          if (isTablet) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summaryText,
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                ),
                const SizedBox(height: 8),
                controls,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                summaryText,
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
              ),
              controls,
            ],
          );
        },
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

  String? _resolveImageUrl(String? rawImageUrl) {
    if (rawImageUrl == null || rawImageUrl.isEmpty) {
      return null;
    }
    if (rawImageUrl.startsWith('http://') ||
        rawImageUrl.startsWith('https://')) {
      return rawImageUrl;
    }
    return '${ApiConfig.baseUrl}$rawImageUrl';
  }

  Future<void> _confirmDeleteFirearm(FirearmModel firearm) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252A3A),
        title:
            const Text('Delete Firearm', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete firearm ${firearm.serialNumber}? This action cannot be undone.',
          style: const TextStyle(color: Color(0xFFB0BEC5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85C5C)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final firearmProvider = context.read<FirearmProvider>();
    final success = await firearmProvider.deleteFirearm(firearm.firearmId);

    if (!mounted) return;

    if (success) {
      if (_selectedFirearmForDetail?.firearmId == firearm.firearmId) {
        setState(() => _selectedFirearmForDetail = null);
      }

      final dashboardProvider = context.read<DashboardProvider>();

      // Keep HQ dashboard stats in sync with successful deletions.
      try {
        await dashboardProvider.loadDashboardStats();
      } catch (_) {
        // Dashboard refresh is best-effort; firearm delete already succeeded.
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firearm ${firearm.serialNumber} deleted'),
          backgroundColor: const Color(0xFF3CCB7F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final message = _formatDeleteErrorMessage(firearmProvider.errorMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFE85C5C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDeleteErrorMessage(String? rawMessage) {
    if (rawMessage == null || rawMessage.isEmpty) {
      return 'Failed to delete firearm.';
    }

    final normalized = rawMessage.toLowerCase();
    if (normalized.contains('cannot delete firearm with') ||
        normalized.contains('operational history') ||
        normalized.contains('violates foreign key constraint') ||
        normalized.contains('code: 23503')) {
      return 'Delete blocked: this firearm has custody/ballistic history. '
          'Set status to Destroyed instead.';
    }

    return rawMessage;
  }

  Widget _buildFirearmIndicator(
    FirearmModel firearm, {
    required double size,
    BoxFit fit = BoxFit.cover,
  }) {
    final imageUrl = _resolveImageUrl(firearm.imageUrl);
    if (imageUrl == null) {
      return Icon(
        _getFirearmIcon(firearm.firearmType),
        color: const Color(0xFF42A5F5),
        size: size,
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (_, __, ___) => Icon(
          _getFirearmIcon(firearm.firearmType),
          color: const Color(0xFF42A5F5),
          size: size,
        ),
      ),
    );
  }

  String _formatFirearmType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _StatCardData {
  final IconData icon;
  final Color iconColor;
  final String number;
  final String label;
  final String? percentage;
  final Color? percentageColor;

  const _StatCardData({
    required this.icon,
    required this.iconColor,
    required this.number,
    required this.label,
    this.percentage,
    this.percentageColor,
  });
}
