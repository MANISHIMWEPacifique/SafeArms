// Station Custody Management Screen
// SafeArms Frontend - Unit-specific firearm custody management for Station Commanders

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/custody_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/assign_custody_modal.dart';
import '../../widgets/return_custody_modal.dart';
import '../../widgets/filter_dropdown_widget.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/custody_verification_badge.dart';

class StationCustodyManagementScreen extends StatefulWidget {
  const StationCustodyManagementScreen({super.key});

  @override
  State<StationCustodyManagementScreen> createState() =>
      _StationCustodyManagementScreenState();
}

class _StationCustodyManagementScreenState
    extends State<StationCustodyManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showAssignModal = false;
  bool _showReturnModal = false;
  Map<String, dynamic>? _selectedCustodyForReturn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnitCustody();
    });
  }

  Future<void> _loadUnitCustody() async {
    final authProvider = context.read<AuthProvider>();
    final custodyProvider = context.read<CustodyProvider>();
    final unitId = authProvider.currentUser?['unit_id']?.toString();

    if (unitId != null) {
      // Load all data in parallel for faster loading
      await Future.wait([
        custodyProvider.loadUnitCustody(unitId: unitId),
        custodyProvider.loadStats(),
        custodyProvider.loadAnomalyStatus(),
      ]);
    }
  }

  Future<void> _refreshDashboardAfterCustodyChange() async {
    if (!mounted) return;

    final dashboardProvider = context.read<DashboardProvider>();

    await dashboardProvider.loadDashboardStats(force: true);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    await dashboardProvider.loadDashboardStats(force: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custodyProvider = context.watch<CustodyProvider>();
    final authProvider = context.watch<AuthProvider>();
    final unitName =
        authProvider.currentUser?['unit_name']?.toString() ?? 'Your Unit';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(context, custodyProvider, unitName),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(custodyProvider),
                        const SizedBox(height: 24),
                        _buildFilterBar(custodyProvider),
                        const SizedBox(height: 24),
                        _buildCustodySection(custodyProvider),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Modal Overlays
          if (_showAssignModal)
            AssignCustodyModal(
              onClose: () => setState(() => _showAssignModal = false),
              onSuccess: () async {
                setState(() => _showAssignModal = false);
                await Future.wait([
                  _loadUnitCustody(),
                  // Retry once to handle stale reads from transient caches.
                  _refreshDashboardAfterCustodyChange(),
                ]);
              },
            ),

          if (_showReturnModal && _selectedCustodyForReturn != null)
            ReturnCustodyModal(
              custodyRecord: _selectedCustodyForReturn!,
              onClose: () => setState(() {
                _showReturnModal = false;
                _selectedCustodyForReturn = null;
              }),
              onSuccess: () async {
                setState(() {
                  _showReturnModal = false;
                  _selectedCustodyForReturn = null;
                });
                await Future.wait([
                  _loadUnitCustody(),
                  // Retry once to handle stale reads from transient caches.
                  _refreshDashboardAfterCustodyChange(),
                ]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(
      BuildContext context, CustodyProvider provider, String unitName) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          final title = _buildHeaderTitle(unitName);
          final actions = _buildHeaderActions(provider, isCompact: isCompact);

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 12),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderTitle(String unitName) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custody Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          unitName,
          style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHeaderActions(
    CustodyProvider provider, {
    required bool isCompact,
  }) {
    final assignButton = ElevatedButton.icon(
      onPressed: () => setState(() => _showAssignModal = true),
      icon: const Icon(Icons.add, size: 18),
      label: const Text(
        'Assign Custody',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final refreshButton = OutlinedButton.icon(
      onPressed: _loadUnitCustody,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Refresh'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFB0BEC5),
        side: const BorderSide(color: Color(0xFF37404F)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    if (isCompact) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          assignButton,
          _buildMLStatus(provider),
          refreshButton,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        assignButton,
        const SizedBox(width: 12),
        _buildMLStatus(provider),
        const SizedBox(width: 12),
        refreshButton,
      ],
    );
  }

  Widget _buildMLStatus(CustodyProvider provider) {
    final status = provider.anomalyStatus;
    final isActive = status['active'] == true;
    final count = status['count'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        border: Border.all(
            color:
                isActive ? const Color(0xFF3CCB7F) : const Color(0xFF78909C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isActive ? const Color(0xFF3CCB7F) : const Color(0xFF78909C),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'ML',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 6),
          Text(
            '$count anomalies',
            style: TextStyle(
              color:
                  count > 0 ? const Color(0xFFE85C5C) : const Color(0xFF3CCB7F),
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(CustodyProvider provider) {
    final stats = provider.stats;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Switch to wrap on small screens
        final isSmall = constraints.maxWidth < 600;
        final childWidth = isSmall ? (constraints.maxWidth / 2) - 8 : (constraints.maxWidth / 4) - 12;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: childWidth,
              child: _buildStatCard(
                'Active Custody',
                stats['active']?.toString() ?? '0',
                Icons.assignment_ind,
                const Color(0xFF3CCB7F),
              ),
            ),
            SizedBox(
              width: childWidth,
              child: _buildStatCard(
                'Permanent',
                stats['permanent']?.toString() ?? '0',
                Icons.lock,
                const Color(0xFF42A5F5),
              ),
            ),
            SizedBox(
              width: childWidth,
              child: _buildStatCard(
                'Temporary',
                stats['temporary']?.toString() ?? '0',
                Icons.schedule,
                const Color(0xFFFFC857),
              ),
            ),
            SizedBox(
              width: childWidth,
              child: _buildStatCard(
                'Personal',
                stats['personal']?.toString() ?? '0',
                Icons.person,
                const Color(0xFF9575CD),
              ),
            ),
          ],
        );
      }
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
                  color: color.withValues(alpha: 0.1),
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

  Widget _buildFilterBar(CustodyProvider provider) {
    final statusDropdown = _buildFilterDropdown(
      label: 'Status',
      value: provider.statusFilter,
      items: const [
        {'value': 'active', 'label': 'Active'},
        {'value': 'all', 'label': 'All'},
        {'value': 'returned', 'label': 'Returned'},
      ],
      onChanged: (value) => provider.setStatusFilter(value ?? 'active'),
    );

    final typeDropdown = _buildFilterDropdown(
      label: 'Custody Type',
      value: provider.typeFilter,
      items: const [
        {'value': 'all', 'label': 'All Types'},
        {'value': 'permanent', 'label': 'Permanent'},
        {'value': 'temporary', 'label': 'Temporary'},
        {'value': 'personal_long_term', 'label': 'Personal Long-term'},
      ],
      onChanged: (value) => provider.setTypeFilter(value ?? 'all'),
    );

    final searchField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Search',
            style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
        const SizedBox(height: 8),
        Container(
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
              hintText: 'Search by officer or serial number',
              hintStyle: TextStyle(color: Color(0xFF78909C), fontSize: 14),
              prefixIcon:
                  Icon(Icons.search, color: Color(0xFF78909C), size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow layout: stack dropdowns 2-per-row then search full-width
          if (constraints.maxWidth < 700) {
            final halfWidth = (constraints.maxWidth - 16) / 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(width: halfWidth, child: statusDropdown),
                    const SizedBox(width: 16),
                    SizedBox(width: halfWidth, child: typeDropdown),
                  ],
                ),
                const SizedBox(height: 16),
                searchField,
              ],
            );
          }
          // Wide layout: all in one row
          return Row(
            children: [
              Expanded(child: statusDropdown),
              const SizedBox(width: 16),
              Expanded(child: typeDropdown),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: searchField),
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

  Widget _buildCustodySection(CustodyProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Active Custody Records',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${provider.filteredCustodyRecords.length} records',
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCustodyGrid(provider),
      ],
    );
  }

  Widget _buildCustodyGrid(CustodyProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
        ),
      );
    }

    final custodyRecords = provider.filteredCustodyRecords;

    if (custodyRecords.isEmpty) {
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double width;
        if (constraints.maxWidth < 600) {
          width = constraints.maxWidth;
        } else if (constraints.maxWidth < 900) {
          width = (constraints.maxWidth - 16) / 2;
        } else {
          width = (constraints.maxWidth - 32) / 3;
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: custodyRecords.map((c) => SizedBox(
            width: width,
            child: _buildCustodyCard(c),
          )).toList(),
        );
      },
    );
  }

  Widget _buildCustodyCard(Map<String, dynamic> custody) {
    final hasAnomaly = custody['has_anomaly'] == true;
    final custodyType = custody['custody_type'] ?? 'permanent';
    final assignedDate = DateTime.tryParse(custody['assigned_date'] ?? '');
    final duration = assignedDate != null
        ? DateTime.now().difference(assignedDate)
        : Duration.zero;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(
          color: hasAnomaly ? const Color(0xFFE85C5C) : const Color(0xFF37404F),
          width: hasAnomaly ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with firearm icon and anomaly badge
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF2A3040),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_police,
                    color: Color(0xFF42A5F5), size: 24),
              ),
              const Spacer(),
              if (hasAnomaly)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE85C5C),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.warning, color: Colors.white, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Firearm details
          Text(
            custody['firearm_serial'] ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${custody['manufacturer'] ?? ''} ${custody['model'] ?? ''}'.trim(),
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: Color(0xFF37404F), height: 24),

          // Officer info
          Row(
            children: [
              const Icon(Icons.person, color: Color(0xFF78909C), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  custody['officer_name'] ?? 'Unknown Officer',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Custody type badge
          _buildCustodyTypeBadge(custodyType),
          const SizedBox(height: 12),

          // Duration counter
          Row(
            children: [
              const Icon(Icons.access_time, color: Color(0xFF78909C), size: 14),
              const SizedBox(width: 6),
              Text(
                _formatDuration(duration),
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CustodyVerificationBadge(custody: custody),

          const SizedBox(height: 8),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCustodyForReturn = custody;
                      _showReturnModal = true;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF42A5F5),
                    side: const BorderSide(color: Color(0xFF42A5F5)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Return', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustodyTypeBadge(String type) {
    Color backgroundColor;
    String displayText;

    switch (type) {
      case 'permanent':
        backgroundColor = const Color(0xFF3CCB7F);
        displayText = 'PERMANENT';
        break;
      case 'temporary':
        backgroundColor = const Color(0xFFFFC857);
        displayText = 'TEMPORARY';
        break;
      case 'personal_long_term':
        backgroundColor = const Color(0xFF42A5F5);
        displayText = 'PERSONAL';
        break;
      default:
        backgroundColor = const Color(0xFF78909C);
        displayText = type.toUpperCase();
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
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.assignment_outlined,
      title: 'No custody records found',
      subtitle: 'Assign a firearm to an officer in your unit to get started',
      padding: const EdgeInsets.all(64),
      actionButton: ElevatedButton.icon(
        onPressed: () => setState(() => _showAssignModal = true),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Assign Custody'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3CCB7F),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }
}
