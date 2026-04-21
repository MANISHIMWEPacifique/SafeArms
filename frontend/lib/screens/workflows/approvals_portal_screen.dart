// Approvals Portal Screen (Screen 16)
// SafeArms Frontend - HQ Commander review and approval interface

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/approvals_provider.dart';
import '../../widgets/expandable_report_card.dart';

class ApprovalsPortalScreen extends StatefulWidget {
  const ApprovalsPortalScreen({super.key});

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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                    onPressed: () {
                      _tabController.animateTo(0);
                    },
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
    return Column(
      children: [
        _buildFilterBar(provider, 'loss'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingLossReports.length,
            itemBuilder: (context, index) {
              final report = provider.pendingLossReports[index];
              return ExpandableReportCard(
                key: ValueKey("loss-${report['loss_id'] ?? index}"),
                reportId: 'LOSS-${report['loss_id'] ?? 'N/A'}',
                status: report['status'] ?? 'pending',
                primaryCodeLabel: 'FIREARM',
                primaryCodeValue: report['serial_number'] ?? 'N/A',
                dateReported: report['created_at'] != null
                    ? DateTime.parse(report['created_at'])
                    : DateTime.now(),
                location: report['loss_location'],
                reportingUnit: report['unit_name'],
                circumstancesLabel: 'CIRCUMSTANCES',
                circumstances: report['circumstances'] ?? 'N/A',
                severityColor: const Color(0xFFF59E0B),
                onStatusChanged: (newStatus) {
                  provider.updateRequestStatus(
                      report['loss_id'], 'loss', newStatus);
                },
                detailsWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Officer Info',
                        "${report['officer_rank'] ?? ''} ${report['officer_name'] ?? ''} (${report['service_number'] ?? 'N/A'})"),
                    _buildDetailRow('Firearm Model',
                        "${report['manufacturer'] ?? ''} ${report['model'] ?? ''}"),
                    _buildDetailRow('Caliber', report['caliber'] ?? 'N/A'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDestructionTab(ApprovalsProvider provider) {
    return Column(
      children: [
        _buildFilterBar(provider, 'destruction'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingDestructionRequests.length,
            itemBuilder: (context, index) {
              final req = provider.pendingDestructionRequests[index];
              return ExpandableReportCard(
                key: ValueKey("destruction-${req['destruction_id'] ?? index}"),
                reportId: 'DEST-${req['destruction_id'] ?? 'N/A'}',
                status: req['status'] ?? 'pending',
                primaryCodeLabel: 'FIREARM',
                primaryCodeValue: req['serial_number'] ?? 'N/A',
                dateReported: req['created_at'] != null
                    ? DateTime.parse(req['created_at'])
                    : DateTime.now(),
                location: req['condition_description'],
                reportingUnit: req['unit_name'],
                circumstancesLabel: 'REASON',
                circumstances: req['destruction_reason'] ?? 'N/A',
                severityColor: const Color(0xFFEF4444),
                onStatusChanged: (newStatus) {
                  provider.updateRequestStatus(
                      req['destruction_id'], 'destruction', newStatus);
                },
                detailsWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                        'Condition', req['condition_description'] ?? 'N/A'),
                    _buildDetailRow('Firearm Model',
                        "${req['manufacturer'] ?? ''} ${req['model'] ?? ''}"),
                    _buildDetailRow('Caliber', req['caliber'] ?? 'N/A'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProcurementTab(ApprovalsProvider provider) {
    return Column(
      children: [
        _buildFilterBar(provider, 'procurement'),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingProcurementRequests.length,
            itemBuilder: (context, index) {
              final req = provider.pendingProcurementRequests[index];
              return ExpandableReportCard(
                key: ValueKey("procurement-${req['procurement_id'] ?? index}"),
                reportId: 'PROC-${req['procurement_id'] ?? 'N/A'}',
                status: req['status'] ?? 'pending',
                primaryCodeLabel: 'TYPE',
                primaryCodeValue: req['firearm_type'] ?? 'N/A',
                dateReported: req['created_at'] != null
                    ? DateTime.parse(req['created_at'])
                    : DateTime.now(),
                location: 'Qty: ${req['quantity'] ?? 'N/A'}',
                reportingUnit: req['unit_name'],
                circumstancesLabel: 'JUSTIFICATION',
                circumstances: req['justification'] ?? 'N/A',
                severityColor: const Color(0xFF3B82F6),
                onStatusChanged: (newStatus) {
                  provider.updateRequestStatus(
                      req['procurement_id'], 'procurement', newStatus);
                },
                detailsWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Quantity Requested',
                        req['quantity']?.toString() ?? 'N/A'),
                    _buildDetailRow('Priority', req['priority'] ?? 'Standard'),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
}
