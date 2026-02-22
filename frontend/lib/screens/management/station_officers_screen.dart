// Station Officers Screen
// Unit-specific officers view for Station Commanders
// SafeArms Frontend

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/officer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/officer_model.dart';
import '../../widgets/station_add_officer_modal.dart';
import '../../widgets/station_edit_officer_modal.dart';
import '../../widgets/officer_detail_modal.dart';

class StationOfficersScreen extends StatefulWidget {
  const StationOfficersScreen({Key? key}) : super(key: key);

  @override
  State<StationOfficersScreen> createState() => _StationOfficersScreenState();
}

class _StationOfficersScreenState extends State<StationOfficersScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showAddModal = false;
  OfficerModel? _selectedOfficerForDetail;
  OfficerModel? _selectedOfficerForEdit;
  final Set<String> _selectedOfficers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnitOfficers();
    });
  }

  Future<void> _loadUnitOfficers() async {
    final authProvider = context.read<AuthProvider>();
    final officerProvider = context.read<OfficerProvider>();
    final unitId = authProvider.currentUser?['unit_id']?.toString();

    if (unitId != null) {
      await officerProvider.loadUnitOfficers(unitId);
      await officerProvider.loadStats(unitId: unitId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final officerProvider = context.watch<OfficerProvider>();
    final authProvider = context.watch<AuthProvider>();
    final unitName =
        authProvider.currentUser?['unit_name']?.toString() ?? 'Your Unit';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(context, officerProvider, unitName),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUnitBanner(unitName),
                        const SizedBox(height: 24),
                        _buildStatsRow(officerProvider),
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

          // Add Officer Modal Overlay
          if (_showAddModal)
            StationAddOfficerModal(
              onClose: () => setState(() => _showAddModal = false),
              onSuccess: () {
                setState(() => _showAddModal = false);
                _loadUnitOfficers();
              },
            ),

          // Officer Detail Modal
          if (_selectedOfficerForDetail != null)
            OfficerDetailModal(
              officer: _selectedOfficerForDetail!,
              onClose: () => setState(() => _selectedOfficerForDetail = null),
            ),

          // Edit Officer Modal
          if (_selectedOfficerForEdit != null)
            StationEditOfficerModal(
              officer: _selectedOfficerForEdit!,
              onClose: () => setState(() => _selectedOfficerForEdit = null),
              onSuccess: () {
                setState(() => _selectedOfficerForEdit = null);
                _loadUnitOfficers();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(
      BuildContext context, OfficerProvider provider, String unitName) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Text(
            'Officers Registry',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E88E5), width: 1),
            ),
            child: Text(
              unitName,
              style: const TextStyle(
                color: Color(0xFF1E88E5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          // Search Bar
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => provider.setSearchQuery(value),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search officers...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withValues(alpha: 0.5), size: 20),
                filled: true,
                fillColor: const Color(0xFF1A1F2E),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF37404F), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF37404F), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: Color(0xFF1E88E5), width: 1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showAddModal = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Officer',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitBanner(String unitName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E88E5).withValues(alpha: 0.2),
            const Color(0xFF252A3A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.people, color: Color(0xFF1E88E5), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unitName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Officers Registry - Personnel Management',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadUnitOfficers,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(OfficerProvider provider) {
    final stats = provider.stats;
    final total = (stats['total'] ?? provider.officers.length).toString();
    final active =
        (stats['active'] ?? provider.officers.where((o) => o.isActive).length)
            .toString();
    final inactive = (stats['inactive'] ??
            provider.officers.where((o) => !o.isActive).length)
        .toString();

    return Row(
      children: [
        _buildStatCard(
            'Total Officers', total, Icons.people, const Color(0xFF1E88E5)),
        const SizedBox(width: 16),
        _buildStatCard(
            'Active', active, Icons.check_circle, const Color(0xFF3CCB7F)),
        const SizedBox(width: 16),
        _buildStatCard(
            'Inactive', inactive, Icons.pause_circle, const Color(0xFFFFC857)),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF252A3A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF37404F)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(OfficerProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        children: [
          const Text(
            'Filters:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          _buildFilterChip(
            'All',
            provider.activeFilter == 'all',
            () => provider.setActiveFilter('all'),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Active',
            provider.activeFilter == 'active',
            () => provider.setActiveFilter('active'),
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            'Inactive',
            provider.activeFilter == 'inactive',
            () => provider.setActiveFilter('inactive'),
          ),
          const Spacer(),
          _buildRankTextField(provider),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF1E88E5) : const Color(0xFF37404F),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRankTextField(OfficerProvider provider) {
    return SizedBox(
      width: 180,
      child: TextField(
        onChanged: (value) =>
            provider.setRankFilter(value.isEmpty ? 'all' : value),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Filter by rank...',
          hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          prefixIcon: Icon(Icons.military_tech,
              color: Colors.white.withValues(alpha: 0.5), size: 20),
          filled: true,
          fillColor: const Color(0xFF1A1F2E),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F), width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 1),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteOfficer(OfficerModel officer) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A3040),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Color(0xFFE85C5C)),
            SizedBox(width: 12),
            Text('Deactivate Officer', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to deactivate ${officer.fullName}? '
          'This will mark the officer as inactive.',
          style: const TextStyle(color: Color(0xFFB0BEC5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF78909C))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final provider = context.read<OfficerProvider>();
              final success = await provider.deleteOfficer(officer.officerId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '${officer.fullName} deactivated successfully'
                        : provider.errorMessage ??
                            'Failed to deactivate officer'),
                    backgroundColor: success
                        ? const Color(0xFF3CCB7F)
                        : const Color(0xFFE85C5C),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE85C5C)),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E88E5)),
      ),
      child: Row(
        children: [
          Text(
            '${_selectedOfficers.length} selected',
            style: const TextStyle(
              color: Color(0xFF1E88E5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() => _selectedOfficers.clear()),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear Selection'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficersTable(OfficerProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
      );
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: const Color(0xFFE85C5C), size: 48),
            const SizedBox(height: 16),
            Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUnitOfficers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final officers = provider.filteredOfficers;

    if (officers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline,
                color: Colors.white.withValues(alpha: 0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'No officers found',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAddModal = true),
              icon: const Icon(Icons.add),
              label: const Text('Add Officer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF252A3A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF37404F)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            columnSpacing: 32,
            headingRowColor: WidgetStateProperty.all(const Color(0xFF1A1F2E)),
            dataRowColor: WidgetStateProperty.all(const Color(0xFF252A3A)),
            columns: const [
              DataColumn(
                  label: Text('Officer',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Rank',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Phone',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Status',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
              DataColumn(
                  label: Text('Actions',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600))),
            ],
            rows: officers.map((officer) => _buildOfficerRow(officer)).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildOfficerRow(OfficerModel officer) {
    final isSelected = _selectedOfficers.contains(officer.officerId);

    return DataRow(
      selected: isSelected,
      onSelectChanged: (selected) {
        setState(() {
          if (selected == true) {
            _selectedOfficers.add(officer.officerId);
          } else {
            _selectedOfficers.remove(officer.officerId);
          }
        });
      },
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                child: Text(
                  officer.fullName.isNotEmpty
                      ? officer.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF1E88E5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    officer.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    officer.officerNumber,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Text(
            officer.rank,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        DataCell(
          Text(
            officer.phoneNumber ?? 'N/A',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: officer.isActive
                  ? const Color(0xFF3CCB7F).withValues(alpha: 0.15)
                  : const Color(0xFFE85C5C).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              officer.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: officer.isActive
                    ? const Color(0xFF3CCB7F)
                    : const Color(0xFFE85C5C),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () =>
                    setState(() => _selectedOfficerForDetail = officer),
                icon: const Icon(Icons.visibility, size: 18),
                color: const Color(0xFF1E88E5),
                tooltip: 'View Details',
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _selectedOfficerForEdit = officer),
                icon: const Icon(Icons.edit, size: 18),
                color: const Color(0xFFFFC857),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () => _confirmDeleteOfficer(officer),
                icon: const Icon(Icons.delete_outline, size: 18),
                color: const Color(0xFFE85C5C),
                tooltip: 'Deactivate',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
