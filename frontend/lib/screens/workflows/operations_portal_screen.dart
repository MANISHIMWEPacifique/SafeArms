// Operations Portal Screen (Screen 15)
// SafeArms Frontend - Station Commander request management

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/operations_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/side_nav.dart';

class OperationsPortalScreen extends StatefulWidget {
  const OperationsPortalScreen({Key? key}) : super(key: key);

  @override
  State<OperationsPortalScreen> createState() => _OperationsPortalScreenState();
}

class _OperationsPortalScreenState extends State<OperationsPortalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OperationsProvider>();
      provider.loadLossReports();
      provider.loadDestructionRequests();
      provider.loadProcurementRequests();
      provider.loadStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operationsProvider = context.watch<OperationsProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Row(
        children: [
          const SideNav(activeItem: 'Operations'),
          Expanded(
            child: Column(
              children: [
                _buildHeader(authProvider),
                _buildStatsBar(operationsProvider),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLossReportsTab(operationsProvider),
                      _buildDestructionTab(operationsProvider),
                      _buildProcurementTab(operationsProvider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthProvider authProvider) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Operations Portal',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Submit and track firearm lifecycle requests',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.location_on, color: Color(0xFF1E88E5), size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Nyamirambo Police Station',
                      style: TextStyle(color: Color(0xFF1E88E5), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(OperationsProvider provider) {
    final stats = provider.stats;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.pending,
              iconColor: const Color(0xFFFFC857),
              number: '${stats['pending_count'] ?? 0}',
              label: 'Awaiting HQ Approval',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              icon: Icons.check_circle,
              iconColor: const Color(0xFF3CCB7F),
              number: '${stats['approved_month'] ?? 0}',
              label: 'Approved Requests',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              icon: Icons.cancel,
              iconColor: const Color(0xFFE85C5C),
              number: '${stats['rejected_count'] ?? 0}',
              label: 'Rejected Requests',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              icon: Icons.archive,
              iconColor: const Color(0xFF42A5F5),
              number: '${stats['total_completed'] ?? 0}',
              label: 'Total Completed',
            ),
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              color: iconColor.withOpacity(0.1),
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
                  style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF1E88E5),
        indicatorWeight: 4,
        labelColor: const Color(0xFF1E88E5),
        unselectedLabelColor: const Color(0xFF78909C),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.warning, size: 20),
                SizedBox(width: 8),
                Text('Loss Reports', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.delete, size: 20),
                SizedBox(width: 8),
                Text('Destruction Requests', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.shopping_cart, size: 20),
                SizedBox(width: 8),
                Text('Procurement Requests', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossReportsTab(OperationsProvider provider) {
    return Column(
      children: [
        _buildActionBar(
          buttonText: 'Report Lost/Stolen Firearm',
          buttonColor: const Color(0xFFE85C5C),
          buttonIcon: Icons.warning,
          onPressed: () {
            // Open loss report modal
          },
          filter: provider.lossReportsFilter,
          onFilterChanged: (value) => provider.setLossReportsFilter(value ?? 'all'),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
              : provider.lossReports.isEmpty
                  ? _buildEmptyState('No loss reports submitted', 'Report lost or stolen firearms to initiate investigation')
                  : _buildLossReportsList(provider.lossReports),
        ),
      ],
    );
  }

  Widget _buildDestructionTab(OperationsProvider provider) {
    return Column(
      children: [
        _buildActionBar(
          buttonText: 'Request Firearm Destruction',
          buttonColor: const Color(0xFFFFA726),
          buttonIcon: Icons.delete,
          onPressed: () {
            // Open destruction modal
          },
          filter: provider.destructionFilter,
          onFilterChanged: (value) => provider.setDestructionFilter(value ?? 'all'),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
              : provider.destructionRequests.isEmpty
                  ? _buildEmptyState('No destruction requests submitted', 'Request firearm disposal for damaged or obsolete firearms')
                  : _buildDestructionList(provider.destructionRequests),
        ),
      ],
    );
  }

  Widget _buildProcurementTab(OperationsProvider provider) {
    return Column(
      children: [
        _buildActionBar(
          buttonText: 'Request New Firearms',
          buttonColor: const Color(0xFF3CCB7F),
          buttonIcon: Icons.add_shopping_cart,
          onPressed: () {
            // Open procurement modal
          },
          filter: provider.procurementFilter,
          onFilterChanged: (value) => provider.setProcurementFilter(value ?? 'all'),
        ),
        Expanded(
          child: provider.isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E88E5)))
              : provider.procurementRequests.isEmpty
                  ? _buildEmptyState('No procurement requests in progress', 'Request new firearms for your station')
                  : _buildProcurementList(provider.procurementRequests),
        ),
      ],
    );
  }

  Widget _buildActionBar({
    required String buttonText,
    required Color buttonColor,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    required String filter,
    required Function(String?) onFilterChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon, size: 18),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF2A3040),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: filter,
                isExpanded: true,
                dropdownColor: const Color(0xFF2A3040),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Status')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: onFilterChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossReportsList(List<Map<String, dynamic>> reports) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: reports.length,
      itemBuilder: (context, index) => _buildLossReportCard(reports[index]),
    );
  }

  Widget _buildLossReportCard(Map<String, dynamic> report) {
    final status = report['status'] ?? 'pending';
    final Color borderColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report['loss_report_id'] ?? 'LOSS-XXXX',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF78909C), size: 14),
                const SizedBox(width: 6),
                Text(
                  _formatDate(report['submitted_date']),
                  style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
                ),
              ],
            ),
            const Divider(color: Color(0xFF37404F), height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE85C5C),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.warning, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report['firearm_serial'] ?? 'Unknown',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${report['manufacturer']} ${report['model']}',
                                  style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Last Custody: ${report['officer_name'] ?? 'Unknown'}',
                        style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Loss Type', report['loss_type']?.toString().toUpperCase() ?? 'N/A', _getLossTypeColor(report['loss_type'])),
                      const SizedBox(height: 8),
                      _buildDetailRow('Loss Date', _formatDate(report['loss_date']), null),
                      const SizedBox(height: 8),
                      _buildDetailRow('Location', report['loss_location'] ?? 'Not specified', null),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E88E5),
                    side: const BorderSide(color: Color(0xFF1E88E5)),
                  ),
                  child: const Text('View Details'),
                ),
                if (status == 'pending') ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85C5C),
                      side: const BorderSide(color: Color(0xFFE85C5C)),
                    ),
                    child: const Text('Withdraw'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestructionList(List<Map<String, dynamic>> requests) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: requests.length,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF252A3A),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _getStatusColor(requests[index]['status']), width: 4)),
        ),
        child: Text(
          'Destruction Request - ${requests[index]['destruction_request_id']}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildProcurementList(List<Map<String, dynamic>> requests) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: requests.length,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF252A3A),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: _getStatusColor(requests[index]['status']), width: 4)),
        ),
        child: Text(
          'Procurement Request - ${requests[index]['procurement_request_id']}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_open, size: 64, color: Color(0xFF78909C)),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color? valueColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? const Color(0xFFB0BEC5),
              fontSize: 13,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFC857);
      case 'approved':
        return const Color(0xFF3CCB7F);
      case 'rejected':
        return const Color(0xFFE85C5C);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  Color _getLossTypeColor(String? type) {
    return type == 'stolen' ? const Color(0xFFE85C5C) : const Color(0xFFFFC857);
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not specified';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }
}
