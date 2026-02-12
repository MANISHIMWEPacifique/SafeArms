// Approvals Portal Screen (Screen 16)
// SafeArms Frontend - HQ Commander review and approval interface

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/approvals_provider.dart';

class ApprovalsPortalScreen extends StatefulWidget {
  const ApprovalsPortalScreen({Key? key}) : super(key: key);

  @override
  State<ApprovalsPortalScreen> createState() => _ApprovalsPortalScreenState();
}

class _ApprovalsPortalScreenState extends State<ApprovalsPortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ApprovalsProvider>();
      provider.loadPendingLossReports();
      provider.loadPendingDestructionRequests();
      provider.loadPendingProcurementRequests();
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
    final approvalsProvider = context.watch<ApprovalsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                _buildStatsBar(approvalsProvider),
                _buildTabBar(approvalsProvider),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildLossReportsTab(approvalsProvider),
                      _buildDestructionTab(approvalsProvider),
                      _buildProcurementTab(approvalsProvider),
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

  Widget _buildHeader() {
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
                'Approvals Portal',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review and approve station requests nationwide',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.business,
                            color: Color(0xFF1E88E5), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Rwanda National Police HQ',
                          style: TextStyle(
                              color: Color(0xFF1E88E5),
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'HQ Firearm Commander',
                      style: TextStyle(
                          color: Color(0xFF1E88E5),
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(ApprovalsProvider provider) {
    final stats = provider.stats;
    final criticalCount = stats['critical_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (criticalCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE85C5C).withValues(alpha: 0.1),
                border: Border.all(color: const Color(0xFFE85C5C)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Color(0xFFE85C5C), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$criticalCount CRITICAL requests require immediate attention',
                      style: const TextStyle(
                          color: Color(0xFFE85C5C),
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE85C5C),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Review Now'),
                  ),
                ],
              ),
            ),
          ],
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.pending,
                  iconColor: const Color(0xFFFFC857),
                  number: '${stats['pending_total'] ?? 0}',
                  label: 'Awaiting Your Review',
                  trend: '+${stats['new_today'] ?? 0} today',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.check_circle,
                  iconColor: const Color(0xFF3CCB7F),
                  number: '${stats['reviewed_today'] ?? 0}',
                  label: 'Approved Today',
                  trend: '${stats['total_reviewed_today'] ?? 0} total reviewed',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.priority_high,
                  iconColor: const Color(0xFFE85C5C),
                  number: '${stats['critical_count'] ?? 0}',
                  label: 'High Priority Requests',
                  trend: null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer,
                  iconColor: const Color(0xFF42A5F5),
                  number: '${stats['avg_response_time'] ?? '0.0'}h',
                  label: 'Avg Response Time',
                  trend: 'Target: <4h',
                ),
              ),
            ],
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
    String? trend,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        border: Border.all(color: const Color(0xFF37404F)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 12),
          Text(
            number,
            style: const TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(
              trend,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(ApprovalsProvider provider) {
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
              children: [
                const Text('Loss Reports Review',
                    style: TextStyle(fontSize: 15)),
                if (provider.pendingLossReports.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE85C5C),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${provider.pendingLossReports.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Destruction Review',
                    style: TextStyle(fontSize: 15)),
                if (provider.pendingDestructionRequests.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFA726),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${provider.pendingDestructionRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Procurement Review',
                    style: TextStyle(fontSize: 15)),
                if (provider.pendingProcurementRequests.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF3CCB7F),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${provider.pendingProcurementRequests.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossReportsTab(ApprovalsProvider provider) {
    return Row(
      children: [
        // LEFT PANEL - Request List (40%)
        Expanded(
          flex: 40,
          child: Container(
            color: const Color(0xFF252A3A),
            child: Column(
              children: [
                _buildFilterBar(provider, 'loss'),
                Expanded(
                  child: provider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF1E88E5)))
                      : provider.pendingLossReports.isEmpty
                          ? const Center(
                              child: Text(
                                'No pending loss reports',
                                style: TextStyle(color: Color(0xFF78909C)),
                              ),
                            )
                          : _buildLossReportsList(provider),
                ),
              ],
            ),
          ),
        ),
        Container(width: 1, color: const Color(0xFF37404F)),
        // RIGHT PANEL - Detail View (60%)
        Expanded(
          flex: 60,
          child: provider.selectedRequest == null
              ? _buildEmptyDetailState()
              : _buildDetailView(provider),
        ),
      ],
    );
  }

  Widget _buildDestructionTab(ApprovalsProvider provider) {
    return const Center(
      child: Text(
        'Destruction Review interface',
        style: TextStyle(color: Color(0xFF78909C)),
      ),
    );
  }

  Widget _buildProcurementTab(ApprovalsProvider provider) {
    return const Center(
      child: Text(
        'Procurement Review interface',
        style: TextStyle(color: Color(0xFF78909C)),
      ),
    );
  }

  Widget _buildFilterBar(ApprovalsProvider provider, String type) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A3040),
                border: Border.all(color: const Color(0xFF37404F)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'all',
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2A3040),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Priority')),
                    DropdownMenuItem(
                        value: 'critical', child: Text('Critical')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  ],
                  onChanged: (value) {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLossReportsList(ApprovalsProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.pendingLossReports.length,
      itemBuilder: (context, index) {
        final report = provider.pendingLossReports[index];
        final isSelected = provider.selectedRequest != null &&
            provider.selectedRequest!['loss_report_id'] ==
                report['loss_report_id'];

        return InkWell(
          onTap: () => provider.selectRequest(report),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2A3040) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: _getPriorityColor(report['priority']),
                  width: 4,
                ),
              ),
            ),
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    _buildPriorityBadge(report['priority']),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report['station_name'] ?? 'Unknown Station',
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
                const Divider(color: Color(0xFF37404F), height: 16),
                Text(
                  '${report['manufacturer']} ${report['model']} - ${report['firearm_serial']}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLossTypeColor(report['loss_type'])
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        report['loss_type']?.toString().toUpperCase() ?? 'N/A',
                        style: TextStyle(
                          color: _getLossTypeColor(report['loss_type']),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDetailState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search, size: 64, color: Color(0xFF78909C)),
          SizedBox(height: 16),
          Text(
            'Select a request to review details',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Click any request from the list to begin review',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailView(ApprovalsProvider provider) {
    final request = provider.selectedRequest!;

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDetailHeader(request),
          _buildStationInfoCard(request),
          _buildFirearmDetailsCard(request),
          _buildIncidentDetailsCard(request),
          _buildReviewActionPanel(provider, request),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(Map<String, dynamic> request) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request['loss_report_id'] ?? 'LOSS-XXXX',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityBadge(request['priority']),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC857).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PENDING HQ APPROVAL',
                      style: TextStyle(
                          color: Color(0xFFFFC857),
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            _formatDate(request['submitted_date']),
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStationInfoCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Station Information',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            request['station_name'] ?? 'Unknown Station',
            style: const TextStyle(
                color: Color(0xFF1E88E5),
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Commander: ${request['commander_name'] ?? 'Unknown'}',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFirearmDetailsCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Firearm Details',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            request['firearm_serial'] ?? 'Unknown',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            '${request['manufacturer']} ${request['model']}',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentDetailsCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Incident Details',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Loss Type',
              request['loss_type']?.toString().toUpperCase() ?? 'N/A'),
          const SizedBox(height: 8),
          _buildDetailRow('Loss Date', _formatDate(request['loss_date'])),
          const SizedBox(height: 8),
          _buildDetailRow(
              'Location', request['loss_location'] ?? 'Not specified'),
          const SizedBox(height: 16),
          const Text(
            'Circumstances',
            style: TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            request['circumstances'] ?? 'No details provided',
            style: const TextStyle(
                color: Color(0xFF78909C), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewActionPanel(
      ApprovalsProvider provider, Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // Show approval modal
                provider.approveLossReport(reportId: request['loss_report_id']);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Approve Loss Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CCB7F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                // Show rejection modal
              },
              icon: const Icon(Icons.cancel),
              label: const Text('Reject Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE85C5C),
                side: const BorderSide(color: Color(0xFFE85C5C)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String? priority) {
    final Color color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority?.toUpperCase() ?? 'MEDIUM',
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'critical':
        return const Color(0xFFE85C5C);
      case 'high':
        return const Color(0xFFFFA726);
      case 'medium':
        return const Color(0xFFFFC857);
      default:
        return const Color(0xFF42A5F5);
    }
  }

  Color _getLossTypeColor(String? type) {
    return type?.toLowerCase() == 'stolen'
        ? const Color(0xFFE85C5C)
        : const Color(0xFFFFC857);
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Not specified';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }
}
