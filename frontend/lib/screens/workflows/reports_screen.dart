// Reports Screen - Approval-driven workflow reports
// Station commanders submit requests, HQ approves

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/approval_provider.dart';
import '../../providers/approvals_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../models/lifecycle_request.dart';
import '../../services/report_service.dart';
import '../../services/firearm_service.dart';
import '../../widgets/delete_confirmation_dialog.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/empty_state_widget.dart';
import 'procurement_request_dialog.dart';

class ReportsScreen extends StatefulWidget {
  final String? roleType; // 'station', 'hq', 'investigator', 'admin'
  final bool autoLoad;
  final List<Map<String, dynamic>>? initialLossReports;
  final List<Map<String, dynamic>>? initialDestructionRequests;
  final List<Map<String, dynamic>>? initialProcurementRequests;

  const ReportsScreen({
    super.key,
    this.roleType,
    this.autoLoad = true,
    this.initialLossReports,
    this.initialDestructionRequests,
    this.initialProcurementRequests,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ReportService _reportService = ReportService();
  final FirearmService _firearmService = FirearmService();

  List<Map<String, dynamic>> _lossReports = [];
  List<Map<String, dynamic>> _destructionRequests = [];
  List<Map<String, dynamic>> _procurementRequests = [];
  List<Map<String, dynamic>> _unitFirearms = [];
  bool _isLoading = false;
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _lossReports = widget.initialLossReports ?? _lossReports;
    _destructionRequests =
        widget.initialDestructionRequests ?? _destructionRequests;
    _procurementRequests =
        widget.initialProcurementRequests ?? _procurementRequests;
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _refreshDataIfMounted(),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshDataIfMounted() {
    if (!mounted) {
      return;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) {
      return;
    }

    final authProvider = Provider.of<AuthProvider?>(context, listen: false);
    final unitId = authProvider?.currentUser?['unit_id']?.toString();
    final role = authProvider?.currentUser?['role'] ?? _roleFromType();
    final status = _filterStatus == 'all' ? null : _filterStatus;

    setState(() => _isLoading = true);
    try {
      final futures = <Future>[];

      // Load reports based on role
      if (role == 'station_commander') {
        futures.add(
          _reportService.getLossReports(unitId: unitId, status: status),
        );
        futures.add(
          _reportService.getDestructionRequests(unitId: unitId, status: status),
        );
        futures.add(
          _reportService.getProcurementRequests(unitId: unitId, status: status),
        );
        futures.add(_firearmService.getAllFirearms(unitId: unitId));
      } else {
        futures.add(_reportService.getLossReports(status: status));
        futures.add(_reportService.getDestructionRequests(status: status));
        futures.add(_reportService.getProcurementRequests(status: status));
      }

      final results = await Future.wait(futures);

      if (!mounted) {
        return;
      }

      setState(() {
        _lossReports = results[0] as List<Map<String, dynamic>>;
        _destructionRequests = results[1] as List<Map<String, dynamic>>;
        _procurementRequests = results[2] as List<Map<String, dynamic>>;
        if (results.length > 3) {
          final firearms = results[3];
          _unitFirearms = (firearms as List)
              .map((f) => f is Map<String, dynamic>
                  ? f
                  : (f as dynamic).toJson() as Map<String, dynamic>)
              .toList();
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: const Color(0xFFE85C5C)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider?>(context);
    final role = authProvider?.currentUser?['role'] ?? _roleFromType();
    final isStation = role == 'station_commander';
    final isHQ = role == 'hq_firearm_commander';
    final isInvestigator = role == 'investigator';
    // HQ commanders and admin can approve/reject
    final canApprove = role == 'admin' || role == 'hq_firearm_commander';
    final canDelete = role == 'admin' || role == 'hq_firearm_commander';

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Column(
        children: [
          if (!isHQ) _buildHeader(isStation, isHQ, isInvestigator),
          _buildStatsRow(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLossReportsTab(isStation,
                    canApprove: canApprove, canDelete: canDelete, isHQ: isHQ),
                _buildDestructionRequestsTab(isStation,
                    canApprove: canApprove, canDelete: canDelete, isHQ: isHQ),
                _buildProcurementRequestsTab(isStation,
                    canApprove: canApprove, canDelete: canDelete, isHQ: isHQ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _roleFromType() {
    switch (widget.roleType) {
      case 'station':
        return 'station_commander';
      case 'hq':
        return 'hq_firearm_commander';
      case 'investigator':
        return 'investigator';
      case 'admin':
        return 'admin';
      default:
        return null;
    }
  }

  Widget _buildHeader(bool isStation, bool isHQ, bool isInvestigator) {
    String title;
    String subtitle;
    if (isStation) {
      title = 'Unit Reports';
      subtitle = 'Submit loss reports, destruction and procurement requests';
    } else if (isHQ) {
      title = 'Approvals';
      subtitle = 'Review and approve station requests nationwide';
    } else if (isInvestigator) {
      title = 'Reports Review';
      subtitle = 'View submitted reports and requests across all units';
    } else {
      title = 'Reports Management';
      subtitle = 'Review and manage all submitted reports and requests';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 600;
          final isTablet = constraints.maxWidth < 1000;
          final heading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isPhone ? 21 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                softWrap: true,
                style: const TextStyle(
                  color: Color(0xFF78909C),
                  fontSize: 14,
                ),
              ),
            ],
          );

          final actions = isStation
              ? [
                  _buildActionButton('Report Loss', Icons.report_problem,
                      const Color(0xFF1E88E5), _showLossReportDialog,
                      expanded: isPhone),
                  _buildActionButton(
                      'Request Destruction',
                      Icons.delete_forever,
                      const Color(0xFF1E88E5),
                      _showDestructionRequestDialog,
                      expanded: isPhone),
                  _buildActionButton(
                      'Request Firearms',
                      Icons.add_shopping_cart,
                      const Color(0xFF1E88E5),
                      _showProcurementRequestDialog,
                      expanded: isPhone),
                ]
              : <Widget>[];

          if (!isStation) {
            return heading;
          }

          if (isPhone) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 16),
                ...actions.asMap().entries.map((entry) => Padding(
                      padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 10),
                      child: entry.value,
                    )),
              ],
            );
          }

          if (isTablet) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: actions,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: actions,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool expanded = false,
  }) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }

  Widget _buildStatsRow() {
    final pendingLoss =
        _lossReports.where((r) => r['status'] == 'pending').length;
    final pendingDestruction =
        _destructionRequests.where((r) => r['status'] == 'pending').length;
    final pendingProcurement =
        _procurementRequests.where((r) => r['status'] == 'pending').length;

    return Container(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 600;
          final isTinyPhone = constraints.maxWidth < 380;
          final isNarrow = constraints.maxWidth < 760;
          final cards = [
            _buildStatCard('Loss Reports', _lossReports.length.toString(),
                pendingLoss, const Color(0xFF1E88E5),
                compact: isPhone),
            _buildStatCard(
                'Destruction Requests',
                _destructionRequests.length.toString(),
                pendingDestruction,
                const Color(0xFF1E88E5),
                compact: isPhone),
            _buildStatCard(
                'Procurement Requests',
                _procurementRequests.length.toString(),
                pendingProcurement,
                const Color(0xFF1E88E5),
                compact: isPhone),
          ];

          if (isTinyPhone) {
            return Column(
              children: cards
                  .asMap()
                  .entries
                  .map((entry) => Padding(
                        padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 10),
                        child: entry.value,
                      ))
                  .toList(),
            );
          }

          if (isPhone) {
            return SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: 240,
                  child: cards[index],
                ),
              ),
            );
          }

          if (isNarrow) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                    width: (constraints.maxWidth - 12) / 2, child: cards[0]),
                SizedBox(
                    width: (constraints.maxWidth - 12) / 2, child: cards[1]),
                SizedBox(width: constraints.maxWidth, child: cards[2]),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String total, int pending, Color color,
      {bool compact = false}) {
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 42 : 48,
            height: compact ? 42 : 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                total,
                style: TextStyle(
                    color: color,
                    fontSize: compact ? 17 : 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 12 : 14,
                        fontWeight: FontWeight.w500)),
                SizedBox(height: compact ? 2 : 4),
                Text('$pending pending',
                    style: TextStyle(
                        color: pending > 0
                            ? const Color(0xFFFFC857)
                            : const Color(0xFF78909C),
                        fontSize: compact ? 11 : 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF37404F))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          final tabs = TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: const Color(0xFF1E88E5),
            labelColor: const Color(0xFF1E88E5),
            unselectedLabelColor: const Color(0xFF78909C),
            tabs: [
              Tab(text: 'Loss Reports (${_lossReports.length})'),
              Tab(text: 'Destruction (${_destructionRequests.length})'),
              Tab(text: 'Procurement (${_procurementRequests.length})'),
            ],
          );
          final tools = Row(
            mainAxisAlignment: isCompact
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.end,
            children: [
              SizedBox(
                width: isCompact ? 180 : null,
                child: _buildFilterDropdown(compact: isCompact),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF78909C)),
                onPressed: _loadData,
                tooltip: 'Refresh',
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tabs,
                const SizedBox(height: 6),
                tools,
                const SizedBox(height: 8),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: tabs),
              const SizedBox(width: 16),
              tools,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterDropdown({bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          isExpanded: compact,
          dropdownColor: const Color(0xFF2A3040),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Status')),
            DropdownMenuItem(value: 'pending', child: Text('Pending')),
            DropdownMenuItem(value: 'approved', child: Text('Approved')),
            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
          ],
          onChanged: (value) {
            setState(() => _filterStatus = value!);
            _refreshDataIfMounted();
          },
        ),
      ),
    );
  }

  Widget _buildLossReportsTab(bool isStation,
      {bool canApprove = false, bool canDelete = false, bool isHQ = false}) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    if (_lossReports.isEmpty) {
      return _buildEmptyState('No loss reports found', Icons.report_off);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _lossReports.length,
      itemBuilder: (context, index) => _buildLossReportCard(
          _lossReports[index], isStation,
          canApprove: canApprove, canDelete: canDelete, isHQ: isHQ),
    );
  }

  Widget _buildLossReportCard(Map<String, dynamic> report, bool isStation,
      {bool canApprove = false, bool canDelete = false, bool isHQ = false}) {
    final status = report['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final deleteEnabled = canDelete && status != 'pending';
    final createdAt = report['created_at'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(report['created_at']))
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportCardHeader(
            icon: Icons.report_problem,
            iconColor: const Color(0xFFE85C5C),
            title: 'Loss Report #${report['loss_id']?.toString() ?? 'N/A'}',
            status: status,
            statusColor: statusColor,
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Firearm', report['serial_number'] ?? 'N/A'),
          _buildInfoRow('Circumstances', report['circumstances'] ?? 'N/A'),
          _buildInfoRow('Date Reported', createdAt),
          if (report['loss_location'] != null)
            _buildInfoRow('Location', report['loss_location']),
          if (!isStation && report['unit_name'] != null)
            _buildInfoRow('Reporting Unit', report['unit_name']),
          if (canApprove && status == 'pending') ...[
            const SizedBox(height: 12),
            _buildResponsiveActions([
              if (deleteEnabled)
                _buildDeleteAction(
                    onPressed: () => _handleDeleteReport(report, 'loss')),
              _buildRejectAction(
                  onPressed: () =>
                      _handleReportAction(report, 'loss', 'rejected')),
              _buildApproveAction(
                  onPressed: () =>
                      _handleReportAction(report, 'loss', 'approved')),
            ]),
          ],
          if ((!canApprove || status != 'pending') && deleteEnabled) ...[
            const SizedBox(height: 12),
            _buildResponsiveActions([
              _buildDeleteAction(
                  onPressed: () => _handleDeleteReport(report, 'loss')),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildDestructionRequestsTab(bool isStation,
      {bool canApprove = false, bool canDelete = false, bool isHQ = false}) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    if (_destructionRequests.isEmpty) {
      return _buildEmptyState(
          'No destruction requests found', Icons.delete_forever);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _destructionRequests.length,
      itemBuilder: (context, index) => _buildDestructionCard(
          _destructionRequests[index], isStation,
          canApprove: canApprove, canDelete: canDelete, isHQ: isHQ),
    );
  }

  Widget _buildDestructionCard(Map<String, dynamic> request, bool isStation,
      {bool canApprove = false, bool canDelete = false, bool isHQ = false}) {
    final status = request['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final deleteEnabled = canDelete && status != 'pending';
    final createdAt = request['created_at'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(request['created_at']))
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportCardHeader(
            icon: Icons.delete_forever,
            iconColor: const Color(0xFFFFC857),
            title:
                'Destruction Request #${request['destruction_id']?.toString() ?? 'N/A'}',
            status: status,
            statusColor: statusColor,
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Firearm', request['serial_number'] ?? 'N/A'),
          _buildInfoRow('Reason', request['destruction_reason'] ?? 'N/A'),
          _buildInfoRow('Date Requested', createdAt),
          if (request['condition_description'] != null)
            _buildInfoRow('Condition', request['condition_description']),
          if (!isStation && request['unit_name'] != null)
            _buildInfoRow('Requesting Unit', request['unit_name']),
          if (canApprove && status == 'pending') ...[
            const SizedBox(height: 12),
            _buildResponsiveActions([
              if (deleteEnabled)
                _buildDeleteAction(
                    onPressed: () =>
                        _handleDeleteReport(request, 'destruction')),
              _buildRejectAction(
                  onPressed: () =>
                      _handleReportAction(request, 'destruction', 'rejected')),
              _buildApproveAction(
                  onPressed: () =>
                      _handleReportAction(request, 'destruction', 'approved')),
            ]),
          ],
          if ((!canApprove || status != 'pending') && deleteEnabled) ...[
            const SizedBox(height: 12),
            _buildResponsiveActions([
              _buildDeleteAction(
                  onPressed: () => _handleDeleteReport(request, 'destruction')),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildProcurementRequestsTab(bool isStation,
      {bool canApprove = false, bool canDelete = false, bool isHQ = false}) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
    }

    if (_procurementRequests.isEmpty) {
      return _buildEmptyState(
          'No procurement requests found', Icons.add_shopping_cart);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _procurementRequests.length,
      itemBuilder: (context, index) => _buildProcurementCard(
          _procurementRequests[index], isStation,
          canApprove: canApprove, canDelete: canDelete, isHQ: isHQ),
    );
  }

  Widget _buildProcurementCard(Map<String, dynamic> request, bool isStation,
      {bool canApprove = false, bool canDelete = false, bool isHQ = false}) {
    final status = request['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final deleteEnabled = canDelete && status != 'pending';
    final createdAt = request['created_at'] != null
        ? DateFormat('MMM dd, yyyy')
            .format(DateTime.parse(request['created_at']))
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportCardHeader(
            icon: Icons.add_shopping_cart,
            iconColor: const Color(0xFF1E88E5),
            title:
                'Procurement Request #${request['procurement_id']?.toString() ?? 'N/A'}',
            status: status,
            statusColor: statusColor,
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Firearm Type(s)', request['firearm_type'] ?? 'N/A'),
          _buildInfoRow(
              'Total Quantity', request['quantity']?.toString() ?? 'N/A'),
          _buildInfoRow('Justification', request['justification'] ?? 'N/A'),
          _buildInfoRow('Date Requested', createdAt),
          if (!isStation && request['unit_name'] != null)
            _buildInfoRow('Requesting Unit', request['unit_name']),
          if (canApprove && status == 'pending') ...[
            const SizedBox(height: 12),
            _buildResponsiveActions([
              if (deleteEnabled)
                _buildDeleteAction(
                    onPressed: () =>
                        _handleDeleteReport(request, 'procurement')),
              _buildRejectAction(
                  onPressed: () => _showReviewActionDialog(
                      request, 'procurement', 'rejected')),
              _buildApproveAction(
                  onPressed: () => _showReviewActionDialog(
                      request, 'procurement', 'approved')),
            ]),
          ],
          if ((!canApprove || status != 'pending') && deleteEnabled) ...[
            const SizedBox(height: 12),
            _buildResponsiveActions([
              _buildDeleteAction(
                  onPressed: () => _handleDeleteReport(request, 'procurement')),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildResponsiveActions(List<Widget> actions) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions
                .asMap()
                .entries
                .map((entry) => Padding(
                      padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 8),
                      child: entry.value,
                    ))
                .toList(),
          );
        }

        return OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
          children: actions,
        );
      },
    );
  }

  Widget _buildDeleteAction({required VoidCallback onPressed}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE85C5C),
        side: const BorderSide(color: Color(0xFF37404F)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text('Delete'),
    );
  }

  Widget _buildRejectAction({required VoidCallback onPressed}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFE85C5C),
        side: const BorderSide(color: Color(0xFF37404F)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text('Reject'),
    );
  }

  Widget _buildApproveAction({required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: const Text('Approve'),
    );
  }

  Widget _buildReportCardHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String status,
    required Color statusColor,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;
        final titleRow = Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: isNarrow ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              const SizedBox(height: 8),
              _buildStatusBadge(status, statusColor),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleRow),
            const SizedBox(width: 12),
            _buildStatusBadge(status, statusColor),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 340) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label:',
                    style: const TextStyle(
                        color: Color(0xFF78909C), fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ],
            );
          }

          final labelWidth = constraints.maxWidth < 460 ? 96.0 : 120.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text('$label:',
                    style: const TextStyle(
                        color: Color(0xFF78909C), fontSize: 13)),
              ),
              Expanded(
                child: Text(value,
                    style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return EmptyStateWidget(
      icon: icon,
      subtitle: message,
      iconSize: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFC857);
      case 'approved':
        return const Color(0xFF3CCB7F);
      case 'rejected':
        return const Color(0xFFE85C5C);
      default:
        return const Color(0xFF78909C);
    }
  }

  void _showLossReportDialog() {
    String? selectedFirearmId;
    String circumstance = 'lost';
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF252A3A),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          title: const Row(
            children: [
              Icon(Icons.report_problem, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Report Firearm Loss',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 560
                ? MediaQuery.of(context).size.width - 64
                : 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFirearmDropdown(
                      selectedFirearmId,
                      (value) =>
                          setDialogState(() => selectedFirearmId = value)),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Circumstance',
                    circumstance,
                    ['lost', 'stolen', 'damaged', 'other'],
                    (value) => setDialogState(() => circumstance = value!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(descriptionController, 'Description',
                      maxLines: 3),
                  const SizedBox(height: 16),
                  _buildTextField(locationController, 'Location of Incident'),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB0BEC5),
                side: const BorderSide(color: Color(0xFF37404F)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedFirearmId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please select a firearm'),
                        backgroundColor: Color(0xFFE85C5C)),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  await _reportService.createLossReport(
                    firearmId: selectedFirearmId!,
                    lossType: circumstance,
                    circumstances: descriptionController.text,
                    lossLocation: locationController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                          content: Text('Loss report submitted successfully'),
                          backgroundColor: Color(0xFF3CCB7F)),
                    );
                    _refreshDataIfMounted();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: const Color(0xFFE85C5C)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  )),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDestructionRequestDialog() {
    String? selectedFirearmId;
    String reason = 'damaged_beyond_repair';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF252A3A),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Request Destruction',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width < 560
                ? MediaQuery.of(context).size.width - 64
                : 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildFirearmDropdown(
                      selectedFirearmId,
                      (value) =>
                          setDialogState(() => selectedFirearmId = value)),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Reason',
                    reason,
                    [
                      'damaged_beyond_repair',
                      'obsolete',
                      'unsafe',
                      'confiscated',
                      'other'
                    ],
                    (value) => setDialogState(() => reason = value!),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(notesController, 'Additional Notes',
                      maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB0BEC5),
                side: const BorderSide(color: Color(0xFF37404F)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedFirearmId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please select a firearm'),
                        backgroundColor: Color(0xFFE85C5C)),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  await _reportService.createDestructionRequest(
                    firearmId: selectedFirearmId!,
                    reason: reason,
                    notes: notesController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                          content: Text('Destruction request submitted'),
                          backgroundColor: Color(0xFF3CCB7F)),
                    );
                    _refreshDataIfMounted();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: const Color(0xFFE85C5C)),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  )),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProcurementRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ProcurementRequestDialog(
        onSubmit: (List<Map<String, dynamic>> requests, String priority,
            DateTime requiredBy, String justification) async {
          try {
            final requestsByType = <String, int>{};
            for (final requestItem in requests) {
              final firearmType = requestItem['type']?.toString().trim() ?? '';
              final rawQuantity = requestItem['quantity'];
              final quantity = rawQuantity is int
                  ? rawQuantity
                  : int.tryParse(rawQuantity?.toString() ?? '') ?? 0;

              if (firearmType.isNotEmpty && quantity > 0) {
                requestsByType[firearmType] =
                    (requestsByType[firearmType] ?? 0) + quantity;
              }
            }

            if (requestsByType.isEmpty) {
              throw Exception('Please add at least one firearm type');
            }

            final formattedDate = DateFormat('MMM dd, yyyy').format(requiredBy);
            final totalQuantity = requestsByType.values
                .fold<int>(0, (sum, quantity) => sum + quantity);
            final typeNames = requestsByType.keys.join(', ');
            final firearmTypeSummary = requestsByType.length == 1
                ? requestsByType.keys.single
                : typeNames.length <= 50
                    ? typeNames
                    : 'Mixed firearms (${requestsByType.length} types)';
            final requestedItems = requestsByType.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join('\n');
            final combinedJustification =
                "Firearms requested:\n$requestedItems\n\nRequired by: $formattedDate\n\n$justification";

            await _reportService.createProcurementRequest(
              firearmType: firearmTypeSummary,
              quantity: totalQuantity,
              justification: combinedJustification,
              priority: priority,
            );

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Procurement request submitted successfully'),
                    backgroundColor: Color(0xFF3CCB7F)),
              );
              _refreshDataIfMounted();
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: const Color(0xFFE85C5C)),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildFirearmDropdown(String? value, Function(String?) onChanged) {
    return SearchableDropdown<String>(
      items: _unitFirearms.map((f) {
        return SearchableDropdownItem<String>(
          value: f['firearm_id']?.toString() ?? '',
          label: '${f['serial_number']} - ${f['manufacturer']} ${f['model']}',
          subtitle:
              '${f['firearm_type'] ?? ''} \u2022 ${f['caliber'] ?? 'N/A'}',
          icon: Icons.gps_fixed,
        );
      }).toList(),
      value: value,
      hintText: 'Search by serial number, manufacturer, model...',
      labelText: 'Firearm',
      prefixIcon: Icons.gps_fixed,
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF2A3040),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E88E5))),
      ),
      items: items
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(i.replaceAll('_', ' ').toUpperCase()),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
        filled: true,
        fillColor: const Color(0xFF1A1F2E),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF37404F))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E88E5))),
      ),
    );
  }

  Future<void> _handleReportAction(
      Map<String, dynamic> report, String type, String action,
      {String? reviewNotes}) async {
    try {
      final requestType = LifecycleRequestTypeX.fromKey(type);
      final approvalsProvider = context.read<ApprovalsProvider>();
      final success = await approvalsProvider.updateRequestStatus(
        lifecycleRequestId(report, requestType),
        type,
        action,
        remarks: reviewNotes,
      );

      if (!success) {
        throw Exception(approvalsProvider.errorMessage ??
            'Unable to update request status');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Request ${action == 'approved' ? 'approved' : 'rejected'} successfully'),
            backgroundColor: action == 'approved'
                ? const Color(0xFF3CCB7F)
                : const Color(0xFFE85C5C),
          ),
        );
        _refreshDataIfMounted();
        // Refresh approval badge counts and dashboard stats so navigation
        // back to the dashboard overview reflects the updated state
        context.read<ApprovalProvider>().loadPendingApprovals();
        context.read<DashboardProvider>().loadDashboardStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFE85C5C)),
        );
      }
    }
  }

  Future<void> _showReviewActionDialog(
      Map<String, dynamic> report, String type, String action) async {
    final remarksController = TextEditingController();
    final bool isApproval = action == 'approved';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252A3A),
        title: Text(isApproval ? 'Approve Request' : 'Reject Request',
            style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                isApproval
                    ? 'Are you sure you want to approve this request?'
                    : 'Are you sure you want to reject this request?',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: remarksController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Add review notes (optional)',
                hintStyle: const TextStyle(color: Color(0xFF78909C)),
                filled: true,
                fillColor: const Color(0xFF1E2330),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFFB0BEC5))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApproval
                  ? const Color(0xFF3CCB7F)
                  : const Color(0xFFE85C5C),
            ),
            child: Text(isApproval ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _handleReportAction(report, type, action,
          reviewNotes: remarksController.text.trim().isNotEmpty
              ? remarksController.text.trim()
              : null);
    }
  }

  Future<void> _handleDeleteReport(
      Map<String, dynamic> report, String type) async {
    final recordId = _getReportId(report, type);
    final confirmed = await DeleteConfirmationDialog.show(
      context,
      title: 'Delete ${_typeLabel(type)}?',
      message: 'You are about to permanently delete',
      itemName: '#$recordId',
      detail: 'This action cannot be undone.',
      confirmText: 'Delete ${_typeLabel(type)}',
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _reportService.deleteLifecycleRequest(
        type: LifecycleRequestTypeX.fromKey(type),
        requestId: recordId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_typeLabel(type)} deleted successfully'),
            backgroundColor: const Color(0xFF3CCB7F),
          ),
        );
        _refreshDataIfMounted();
        context.read<ApprovalProvider>().loadPendingApprovals();
        context.read<DashboardProvider>().loadDashboardStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error deleting ${_typeLabel(type).toLowerCase()}: $e'),
              backgroundColor: const Color(0xFFE85C5C)),
        );
      }
    }
  }

  String _getReportId(Map<String, dynamic> report, String type) {
    return lifecycleRequestId(report, LifecycleRequestTypeX.fromKey(type));
  }

  String _typeLabel(String type) {
    return LifecycleRequestTypeX.fromKey(type).label;
  }
}
