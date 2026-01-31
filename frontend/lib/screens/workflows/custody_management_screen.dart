// Custody Management Screen (Screen 11)
// SafeArms Frontend - Firearm custody assignment and return

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/custody_provider.dart';
import '../../widgets/assign_custody_modal.dart';
import '../../widgets/return_custody_modal.dart';

class CustodyManagementScreen extends StatefulWidget {
  const CustodyManagementScreen({Key? key}) : super(key: key);

  @override
  State<CustodyManagementScreen> createState() =>
      _CustodyManagementScreenState();
}

class _CustodyManagementScreenState extends State<CustodyManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showAssignModal = false;
  bool _showReturnModal = false;
  Map<String, dynamic>? _selectedCustodyForReturn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustodyProvider>().loadCustody();
      context.read<CustodyProvider>().loadStats();
      context.read<CustodyProvider>().loadAnomalyStatus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final custodyProvider = context.watch<CustodyProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildTopNavBar(context, custodyProvider),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFilterBar(custodyProvider),
                              const SizedBox(height: 24),
                              const Text(
                                'Active Custody',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildCustodyGrid(custodyProvider),
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
          if (_showAssignModal)
            AssignCustodyModal(
              onClose: () => setState(() => _showAssignModal = false),
              onSuccess: () {
                setState(() => _showAssignModal = false);
                custodyProvider.loadCustody();
                custodyProvider.loadStats();
              },
            ),

          if (_showReturnModal && _selectedCustodyForReturn != null)
            ReturnCustodyModal(
              custodyRecord: _selectedCustodyForReturn!,
              onClose: () => setState(() {
                _showReturnModal = false;
                _selectedCustodyForReturn = null;
              }),
              onSuccess: () {
                setState(() {
                  _showReturnModal = false;
                  _selectedCustodyForReturn = null;
                });
                custodyProvider.loadCustody();
                custodyProvider.loadStats();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context, CustodyProvider provider) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          const Text(
            'Custody Management',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showAssignModal = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Assign Custody',
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
              // Show message to select from the list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Click the return icon on a custody card to return a firearm'),
                  backgroundColor: Color(0xFF1E88E5),
                ),
              );
            },
            icon: const Icon(Icons.assignment_return, size: 18),
            label: const Text('Return Firearm'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E88E5),
              side: const BorderSide(color: Color(0xFF1E88E5)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              // View history
            },
            icon: const Icon(Icons.history, size: 18),
            label: const Text('View History'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 24),
          _buildMLStatus(provider),
        ],
      ),
    );
  }

  Widget _buildMLStatus(CustodyProvider provider) {
    final status = provider.anomalyStatus;
    final isActive = status['active'] == true;
    final count = status['count'] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        border: Border.all(
            color:
                isActive ? const Color(0xFF3CCB7F) : const Color(0xFF78909C)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
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
            'ML Monitoring',
            style: TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Text(
            '$count anomalies today',
            style: TextStyle(
              color:
                  count > 0 ? const Color(0xFFE85C5C) : const Color(0xFF3CCB7F),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(CustodyProvider provider) {
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
              label: 'Filter by Status',
              value: provider.statusFilter,
              items: const [
                {'value': 'all', 'label': 'All'},
                {'value': 'active', 'label': 'Active'},
                {'value': 'returned', 'label': 'Returned'},
              ],
              onChanged: (value) => provider.setStatusFilter(value ?? 'active'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Filter by Custody Type',
              value: provider.typeFilter,
              items: const [
                {'value': 'all', 'label': 'All Types'},
                {'value': 'permanent', 'label': 'Permanent'},
                {'value': 'temporary', 'label': 'Temporary'},
                {'value': 'personal_long_term', 'label': 'Personal Long-term'},
              ],
              onChanged: (value) => provider.setTypeFilter(value ?? 'all'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
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
                      hintText: 'Search by officer, firearm, or serial number',
                      hintStyle:
                          TextStyle(color: Color(0xFF78909C), fontSize: 14),
                      prefixIcon: Icon(Icons.search,
                          color: Color(0xFF78909C), size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
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

  Widget _buildCustodyGrid(CustodyProvider provider) {
    if (provider.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    final custodyRecords = provider.activeCustodyRecords;

    if (custodyRecords.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.9,
      ),
      itemCount: custodyRecords.length,
      itemBuilder: (context, index) => _buildCustodyCard(custodyRecords[index]),
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
        border: Border.all(color: const Color(0xFF37404F)),
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
            '${custody['manufacturer'] ?? ''} ${custody['model'] ?? ''}',
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

          // Assignment date
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  color: Color(0xFF78909C), size: 14),
              const SizedBox(width: 6),
              Text(
                _formatDate(assignedDate),
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),

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
          const SizedBox(height: 16),

          // Status indicator
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3CCB7F),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'In Custody',
                style: TextStyle(
                  color: Color(0xFF3CCB7F),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),

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
                icon: const Icon(Icons.assignment_return,
                    size: 18, color: Color(0xFF78909C)),
                onPressed: () {
                  setState(() {
                    _selectedCustodyForReturn = custody;
                    _showReturnModal = true;
                  });
                },
                tooltip: 'Return',
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(64.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined,
                size: 64, color: Color(0xFF78909C)),
            const SizedBox(height: 16),
            const Text(
              'No active custody assignments',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Assign a firearm to an officer to get started',
              style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => _showAssignModal = true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Assign Custody'),
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
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

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days ${duration.inHours % 24} hours';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inMinutes} minutes';
    }
  }
}
