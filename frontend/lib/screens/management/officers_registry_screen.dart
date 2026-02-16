// Officers Registry Screen (Screen 12)
// SafeArms Frontend - Officer management without certification tracking

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/officer_provider.dart';
import '../../models/officer_model.dart';
import '../../widgets/add_officer_modal.dart';

class OfficersRegistryScreen extends StatefulWidget {
  const OfficersRegistryScreen({Key? key}) : super(key: key);

  @override
  State<OfficersRegistryScreen> createState() => _OfficersRegistryScreenState();
}

class _OfficersRegistryScreenState extends State<OfficersRegistryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showAddModal = false;
  final Set<String> _selectedOfficers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OfficerProvider>().loadOfficers();
      context.read<OfficerProvider>().loadStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final officerProvider = context.watch<OfficerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildTopNavBar(context, officerProvider),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatsCards(officerProvider),
                              const SizedBox(height: 24),
                              _buildFilterBar(officerProvider),
                              const SizedBox(height: 24),
                              if (_selectedOfficers.isNotEmpty)
                                _buildBulkActionsBar(),
                              if (_selectedOfficers.isNotEmpty)
                                const SizedBox(height: 16),
                              _buildOfficersTable(officerProvider),
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

          // Add Officer Modal Overlay
          if (_showAddModal)
            AddOfficerModal(
              onClose: () => setState(() => _showAddModal = false),
              onSuccess: () {
                setState(() => _showAddModal = false);
                context.read<OfficerProvider>().loadOfficers();
                context.read<OfficerProvider>().loadStats();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context, OfficerProvider provider) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Officer Registry',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Manage officers eligible for firearm custody',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search by name, badge number, or rank...',
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
            onPressed: () => setState(() => _showAddModal = true),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Add New Officer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              // Import officers
            },
            icon: const Icon(Icons.upload, size: 18),
            label: const Text('Import'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              // Export list
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(OfficerProvider provider) {
    final stats = provider.stats;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            iconColor: const Color(0xFF1E88E5),
            number: '${provider.officers.length}',
            label: 'Total Officers',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle,
            iconColor: const Color(0xFF3CCB7F),
            number: '${stats['active_count'] ?? 0}',
            label: 'Active Officers',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.local_police,
            iconColor: const Color(0xFF42A5F5),
            number: '${stats['active_custody_count'] ?? 0}',
            label: 'Active Custody',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            icon: Icons.business,
            iconColor: const Color(0xFFFFC857),
            number: '${stats['units_count'] ?? 0}',
            label: 'Units Represented',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String number,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(OfficerProvider provider) {
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
              label: 'Filter by Unit',
              value: provider.unitFilter,
              items: const [
                {'value': 'all', 'label': 'All Units'},
                {'value': 'unit1', 'label': 'Kigali Central Station'},
                {'value': 'unit2', 'label': 'Nyamirambo Station'},
              ],
              onChanged: (value) => provider.setUnitFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Filter by Rank',
              value: provider.rankFilter,
              items: const [
                {'value': 'all', 'label': 'All Ranks'},
                {'value': 'constable', 'label': 'Constable'},
                {'value': 'corporal', 'label': 'Corporal'},
                {'value': 'sergeant', 'label': 'Sergeant'},
                {'value': 'inspector', 'label': 'Inspector'},
                {'value': 'superintendent', 'label': 'Superintendent'},
              ],
              onChanged: (value) => provider.setRankFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Active Status',
              value: provider.activeFilter,
              items: const [
                {'value': 'all', 'label': 'All'},
                {'value': 'active', 'label': 'Active'},
                {'value': 'inactive', 'label': 'Inactive'},
              ],
              onChanged: (value) => provider.setActiveFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  provider.clearFilters();
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear Filters'),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64B5F6)),
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

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(8),
        border:
            const Border(left: BorderSide(color: Color(0xFF42A5F5), width: 4)),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedOfficers.length} officers selected',
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 24),
          TextButton.icon(
            onPressed: () {
              // Export selected
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Export Selected'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFF64B5F6)),
          ),
          TextButton.icon(
            onPressed: () {
              // Bulk edit
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('Bulk Edit'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFF64B5F6)),
          ),
          TextButton.icon(
            onPressed: () {
              // Bulk deactivate
            },
            icon: const Icon(Icons.block, size: 18),
            label: const Text('Bulk Deactivate'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFE85C5C)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _selectedOfficers.clear()),
            child: const Text('Cancel Selection'),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFF78909C)),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficersTable(OfficerProvider provider) {
    if (provider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    final officers = provider.paginatedOfficers;

    if (officers.isEmpty) {
      return _buildEmptyState();
    }

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
                  bottom: BorderSide(color: Color(0xFF37404F), width: 2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: const [
                SizedBox(width: 40, child: _TableHeader('')),
                Expanded(flex: 3, child: _TableHeader('OFFICER')),
                Expanded(flex: 2, child: _TableHeader('OFFICER NUMBER')),
                Expanded(flex: 2, child: _TableHeader('RANK')),
                Expanded(flex: 2, child: _TableHeader('UNIT')),
                Expanded(flex: 2, child: _TableHeader('PHONE')),
                Expanded(flex: 1, child: _TableHeader('STATUS')),
                Expanded(flex: 1, child: _TableHeader('CUSTODY')),
                SizedBox(width: 100, child: _TableHeader('ACTIONS')),
              ],
            ),
          ),

          // Table rows
          ...officers
              .map((officer) => _buildOfficerRow(officer, provider))
              .toList(),

          // Pagination
          _buildPagination(provider),
        ],
      ),
    );
  }

  Widget _buildOfficerRow(OfficerModel officer, OfficerProvider provider) {
    final isSelected = _selectedOfficers.contains(officer.officerId);

    return InkWell(
      onTap: () => provider.selectOfficer(officer),
      hoverColor: const Color(0xFF252A3A),
      child: Container(
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 40,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedOfficers.add(officer.officerId);
                    } else {
                      _selectedOfficers.remove(officer.officerId);
                    }
                  });
                },
                fillColor: WidgetStateProperty.all(
                  isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
                ),
                side: const BorderSide(color: Color(0xFF37404F)),
              ),
            ),

            // Officer column with avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getAvatarColor(officer.fullName),
                    child: Text(
                      _getInitials(officer.fullName),
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
                          officer.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (officer.email != null)
                          Text(
                            officer.email!,
                            style: const TextStyle(
                                color: Color(0xFF78909C), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Officer Number
            Expanded(
              flex: 2,
              child: Text(
                officer.officerNumber,
                style: const TextStyle(
                  color: Color(0xFFB0BEC5),
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Rank
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(Icons.military_tech,
                      color: Color(0xFF78909C), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _formatRank(officer.rank),
                      style: const TextStyle(
                          color: Color(0xFFB0BEC5), fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Unit
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const Icon(Icons.business,
                      color: Color(0xFF78909C), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      officer.unitId,
                      style: const TextStyle(
                          color: Color(0xFFB0BEC5), fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Phone
            Expanded(
              flex: 2,
              child: Text(
                officer.phoneNumber ?? '—',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
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
                      color: officer.isActive
                          ? const Color(0xFF3CCB7F)
                          : const Color(0xFF78909C),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    officer.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: officer.isActive
                          ? const Color(0xFF3CCB7F)
                          : const Color(0xFF78909C),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Active Custody (placeholder - would need backend integration)
            Expanded(
              flex: 1,
              child: Row(
                children: [
                  Icon(
                    Icons.local_police,
                    size: 16,
                    color: const Color(0xFF78909C),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '—',
                    style: const TextStyle(
                      color: Color(0xFF78909C),
                      fontSize: 13,
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
                      provider.selectOfficer(officer);
                      setState(() => _showAddModal = true);
                    },
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    color: const Color(0xFF78909C),
                    onPressed: () {
                      // Show actions menu
                    },
                    tooltip: 'More actions',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(OfficerProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(top: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(provider.currentPage - 1) * provider.itemsPerPage + 1}-'
            '${(provider.currentPage * provider.itemsPerPage).clamp(0, provider.totalItems)} '
            'of ${provider.totalItems} officers',
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: const Color(0xFF78909C)),
            const SizedBox(height: 16),
            const Text(
              'No officers found',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filters or add a new officer',
              style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAddModal = true),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Officer'),
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

  String _formatRank(String rank) {
    return rank
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
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
