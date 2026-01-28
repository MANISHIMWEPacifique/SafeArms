// Station Firearms Screen
// Unit-specific firearms view for Station Commanders
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/firearm_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/firearm_model.dart';
import '../../widgets/station_register_firearm_modal.dart';
import '../../widgets/firearm_detail_modal.dart';

class StationFirearmsScreen extends StatefulWidget {
  const StationFirearmsScreen({Key? key}) : super(key: key);

  @override
  State<StationFirearmsScreen> createState() => _StationFirearmsScreenState();
}

class _StationFirearmsScreenState extends State<StationFirearmsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showRegisterModal = false;
  FirearmModel? _selectedFirearmForDetail;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnitFirearms();
    });
  }

  Future<void> _loadUnitFirearms() async {
    final authProvider = context.read<AuthProvider>();
    final firearmProvider = context.read<FirearmProvider>();
    final unitId = authProvider.currentUser?['unit_id']?.toString();

    if (unitId != null) {
      await firearmProvider.loadUnitFirearms(unitId);
      await firearmProvider.loadStats(unitId: unitId);
    }
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
    final unitName =
        authProvider.currentUser?['unit_name']?.toString() ?? 'Your Unit';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(context, firearmProvider, unitName),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUnitBanner(unitName),
                        const SizedBox(height: 24),
                        _buildStatsRow(firearmProvider),
                        const SizedBox(height: 24),
                        _buildFilterBar(firearmProvider),
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

          // Modal Overlays
          if (_showRegisterModal)
            StationRegisterFirearmModal(
              onClose: () => setState(() => _showRegisterModal = false),
              onSuccess: () {
                setState(() => _showRegisterModal = false);
                _loadUnitFirearms();
              },
            ),

          if (_selectedFirearmForDetail != null)
            FirearmDetailModal(
              firearm: _selectedFirearmForDetail!,
              onClose: () => setState(() => _selectedFirearmForDetail = null),
              onEdit: () {
                // Station commanders cannot edit - just view
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Firearm editing is restricted to HQ level'),
                    backgroundColor: Color(0xFFFFC857),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(
      BuildContext context, FirearmProvider provider, String unitName) {
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
              const Text(
                'Unit Firearms Inventory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                unitName,
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 280,
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
                hintText: 'Search by serial, model...',
                hintStyle: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: Color(0xFF78909C), size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showRegisterModal = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Register Firearm',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              provider.isGridView ? Icons.view_list : Icons.grid_view,
              color: const Color(0xFFB0BEC5),
            ),
            onPressed: () => provider.toggleViewMode(),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitBanner(String unitName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF1E88E5), width: 4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Color(0xFF42A5F5), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unit-Restricted View',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Showing firearms assigned to $unitName only. Firearms registered here will be automatically assigned to your unit.',
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(FirearmProvider provider) {
    final stats = provider.stats;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Firearms',
            stats['total']?.toString() ?? '0',
            Icons.gavel,
            const Color(0xFF1E88E5),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Available',
            stats['available']?.toString() ?? '0',
            Icons.check_circle,
            const Color(0xFF3CCB7F),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'In Custody',
            stats['in_custody']?.toString() ?? '0',
            Icons.person,
            const Color(0xFFFFC857),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Maintenance',
            stats['maintenance']?.toString() ?? '0',
            Icons.build,
            const Color(0xFF78909C),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(FirearmProvider provider) {
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
          const SizedBox(width: 16),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Manufacturer',
              value: provider.manufacturerFilter,
              items: const [
                {'value': 'all', 'label': 'All Manufacturers'},
              ],
              onChanged: (value) =>
                  provider.setManufacturerFilter(value ?? 'all'),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => provider.clearFilters(),
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Clear Filters'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF78909C),
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

  Widget _buildGridView(FirearmProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
        ),
      );
    }

    final firearms = provider.filteredFirearms;

    if (firearms.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: firearms.length,
      itemBuilder: (context, index) => _buildFirearmCard(firearms[index]),
    );
  }

  Widget _buildListView(FirearmProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
      );
    }

    final firearms = provider.filteredFirearms;

    if (firearms.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: firearms.length,
      itemBuilder: (context, index) => _buildFirearmListItem(firearms[index]),
    );
  }

  Widget _buildFirearmCard(FirearmModel firearm) {
    return InkWell(
      onTap: () => setState(() => _selectedFirearmForDetail = firearm),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF252A3A),
          border: Border.all(color: const Color(0xFF37404F)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3040),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.gavel,
                      color: Color(0xFF42A5F5), size: 20),
                ),
                const Spacer(),
                _buildStatusBadge(firearm.currentStatus),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              firearm.serialNumber,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${firearm.manufacturer} ${firearm.model}',
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(
                  _getTypeIcon(firearm.firearmType),
                  color: const Color(0xFF78909C),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  firearm.caliber ?? 'N/A',
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirearmListItem(FirearmModel firearm) {
    return InkWell(
      onTap: () => setState(() => _selectedFirearmForDetail = firearm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF252A3A),
          border: Border.all(color: const Color(0xFF37404F)),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A3040),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.gavel, color: Color(0xFF42A5F5), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firearm.serialNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    '${firearm.manufacturer} ${firearm.model}',
                    style: const TextStyle(color: Color(0xFF78909C)),
                  ),
                ],
              ),
            ),
            Text(
              firearm.caliber ?? 'N/A',
              style: const TextStyle(color: Color(0xFFB0BEC5)),
            ),
            const SizedBox(width: 24),
            _buildStatusBadge(firearm.currentStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'available':
        color = const Color(0xFF3CCB7F);
        label = 'Available';
        break;
      case 'in_custody':
        color = const Color(0xFFFFC857);
        label = 'In Custody';
        break;
      case 'maintenance':
        color = const Color(0xFF78909C);
        label = 'Maintenance';
        break;
      default:
        color = const Color(0xFF78909C);
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.gavel, size: 64, color: Color(0xFF78909C)),
            const SizedBox(height: 16),
            const Text(
              'No firearms in your unit',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register a firearm to your unit to get started',
              style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showRegisterModal = true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Register Firearm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'pistol':
        return Icons.gavel;
      case 'rifle':
        return Icons.sports_mma;
      case 'shotgun':
        return Icons.sports_mma;
      default:
        return Icons.gavel;
    }
  }
}
