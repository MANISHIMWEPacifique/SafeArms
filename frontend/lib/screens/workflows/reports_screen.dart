// Reports Screen - Approval-driven workflow reports
// Station commanders submit requests, HQ approves

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/report_service.dart';
import '../../services/firearm_service.dart';

class ReportsScreen extends StatefulWidget {
  final String? roleType; // 'station', 'hq', 'investigator', 'admin'

  const ReportsScreen({super.key, this.roleType});

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final unitId = authProvider.currentUser?['unit_id']?.toString();
      final role = authProvider.currentUser?['role'];

      final futures = <Future>[];

      // Load reports based on role
      if (role == 'station_commander') {
        futures.add(_reportService.getLossReports(
            unitId: unitId,
            status: _filterStatus == 'all' ? null : _filterStatus));
        futures.add(_reportService.getDestructionRequests(
            status: _filterStatus == 'all' ? null : _filterStatus));
        futures.add(_reportService.getProcurementRequests(
            status: _filterStatus == 'all' ? null : _filterStatus));
        futures.add(_firearmService.getAllFirearms(unitId: unitId));
      } else {
        futures.add(_reportService.getLossReports(
            status: _filterStatus == 'all' ? null : _filterStatus));
        futures.add(_reportService.getDestructionRequests(
            status: _filterStatus == 'all' ? null : _filterStatus));
        futures.add(_reportService.getProcurementRequests(
            status: _filterStatus == 'all' ? null : _filterStatus));
      }

      final results = await Future.wait(futures);

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
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading data: $e'),
              backgroundColor: const Color(0xFFE85C5C)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.currentUser?['role'];
    final isStation = role == 'station_commander';
    final isHQ = role == 'hq_firearm_commander';
    final isInvestigator = role == 'investigator';
    // HQ commanders and admin can approve/reject
    final canApprove = role == 'admin' || role == 'hq_firearm_commander';

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
                _buildLossReportsTab(isStation, canApprove: canApprove),
                _buildDestructionRequestsTab(isStation, canApprove: canApprove),
                _buildProcurementRequestsTab(isStation, canApprove: canApprove),
              ],
            ),
          ),
        ],
      ),
    );
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 14),
                ),
              ],
            ),
          ),
          if (isStation) ...[
            _buildActionButton('Report Loss', Icons.report_problem,
                const Color(0xFF1E88E5), _showLossReportDialog),
            const SizedBox(width: 12),
            _buildActionButton('Request Destruction', Icons.delete_forever,
                const Color(0xFF1E88E5), _showDestructionRequestDialog),
            const SizedBox(width: 12),
            _buildActionButton('Request Firearms', Icons.add_shopping_cart,
                const Color(0xFF1E88E5), _showProcurementRequestDialog),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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
      child: Row(
        children: [
          Expanded(
              child: _buildStatCard(
                  'Loss Reports',
                  _lossReports.length.toString(),
                  pendingLoss,
                  const Color(0xFF1E88E5))),
          const SizedBox(width: 12),
          Expanded(
              child: _buildStatCard(
                  'Destruction Requests',
                  _destructionRequests.length.toString(),
                  pendingDestruction,
                  const Color(0xFF1E88E5))),
          const SizedBox(width: 12),
          Expanded(
              child: _buildStatCard(
                  'Procurement Requests',
                  _procurementRequests.length.toString(),
                  pendingProcurement,
                  const Color(0xFF1E88E5))),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String total, int pending, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                total,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('$pending pending',
                    style: TextStyle(
                        color: pending > 0
                            ? const Color(0xFFFFC857)
                            : const Color(0xFF78909C),
                        fontSize: 12)),
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
      child: Row(
        children: [
          Expanded(
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1E88E5),
              labelColor: const Color(0xFF1E88E5),
              unselectedLabelColor: const Color(0xFF78909C),
              tabs: [
                Tab(text: 'Loss Reports (${_lossReports.length})'),
                Tab(text: 'Destruction (${_destructionRequests.length})'),
                Tab(text: 'Procurement (${_procurementRequests.length})'),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildFilterDropdown(),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF78909C)),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
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
            _loadData();
          },
        ),
      ),
    );
  }

  Widget _buildLossReportsTab(bool isStation, {bool canApprove = false}) {
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
          canApprove: canApprove),
    );
  }

  Widget _buildLossReportCard(Map<String, dynamic> report, bool isStation,
      {bool canApprove = false}) {
    final status = report['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
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
          Row(
            children: [
              const Icon(Icons.report_problem,
                  color: Color(0xFFE85C5C), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Loss Report #${report['loss_report_id']?.toString().substring(0, 8) ?? 'N/A'}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              _buildStatusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Firearm',
              report['serial_number'] ?? report['firearm_serial'] ?? 'N/A'),
          _buildInfoRow('Circumstance', report['circumstance'] ?? 'N/A'),
          _buildInfoRow('Date Reported', createdAt),
          if (report['description'] != null)
            _buildInfoRow('Description', report['description']),
          if (!isStation && report['unit_name'] != null)
            _buildInfoRow('Reporting Unit', report['unit_name']),
          if (canApprove && status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _handleReportAction(report, 'loss', 'rejected'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85C5C)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _handleReportAction(report, 'loss', 'approved'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5)),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDestructionRequestsTab(bool isStation,
      {bool canApprove = false}) {
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
          canApprove: canApprove),
    );
  }

  Widget _buildDestructionCard(Map<String, dynamic> request, bool isStation,
      {bool canApprove = false}) {
    final status = request['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
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
          Row(
            children: [
              const Icon(Icons.delete_forever,
                  color: Color(0xFFFFC857), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Destruction Request #${request['destruction_request_id']?.toString().substring(0, 8) ?? 'N/A'}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              _buildStatusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Firearm',
              request['serial_number'] ?? request['firearm_serial'] ?? 'N/A'),
          _buildInfoRow('Reason', request['reason'] ?? 'N/A'),
          _buildInfoRow('Date Requested', createdAt),
          if (request['notes'] != null)
            _buildInfoRow('Notes', request['notes']),
          if (!isStation && request['unit_name'] != null)
            _buildInfoRow('Requesting Unit', request['unit_name']),
          if (canApprove && status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _handleReportAction(request, 'destruction', 'rejected'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85C5C)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _handleReportAction(request, 'destruction', 'approved'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5)),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcurementRequestsTab(bool isStation,
      {bool canApprove = false}) {
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
          canApprove: canApprove),
    );
  }

  Widget _buildProcurementCard(Map<String, dynamic> request, bool isStation,
      {bool canApprove = false}) {
    final status = request['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
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
          Row(
            children: [
              const Icon(Icons.add_shopping_cart,
                  color: Color(0xFF1E88E5), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Procurement Request #${request['procurement_request_id']?.toString().substring(0, 8) ?? 'N/A'}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              _buildStatusBadge(status, statusColor),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Firearm Type', request['firearm_type'] ?? 'N/A'),
          _buildInfoRow('Quantity', request['quantity']?.toString() ?? 'N/A'),
          _buildInfoRow('Justification', request['justification'] ?? 'N/A'),
          _buildInfoRow('Date Requested', createdAt),
          if (!isStation && request['unit_name'] != null)
            _buildInfoRow('Requesting Unit', request['unit_name']),
          if (canApprove && status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      _handleReportAction(request, 'procurement', 'rejected'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE85C5C)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      _handleReportAction(request, 'procurement', 'approved'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5)),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF78909C)),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 16)),
        ],
      ),
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
          backgroundColor: const Color(0xFF2A3040),
          title: const Row(
            children: [
              Icon(Icons.report_problem, color: Color(0xFFE85C5C)),
              SizedBox(width: 12),
              Text('Report Firearm Loss',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 500,
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF78909C))),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Loss report submitted successfully'),
                          backgroundColor: Color(0xFF3CCB7F)),
                    );
                    _loadData();
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85C5C)),
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
          backgroundColor: const Color(0xFF2A3040),
          title: const Row(
            children: [
              Icon(Icons.delete_forever, color: Color(0xFFFFC857)),
              SizedBox(width: 12),
              Text('Request Destruction',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 500,
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
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF78909C))),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Destruction request submitted'),
                          backgroundColor: Color(0xFF3CCB7F)),
                    );
                    _loadData();
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC857)),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProcurementRequestDialog() {
    String firearmType = 'pistol';
    int quantity = 1;
    final justificationController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A3040),
          title: const Row(
            children: [
              Icon(Icons.add_shopping_cart, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Request Firearms', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDropdownField(
                    'Firearm Type',
                    firearmType,
                    ['pistol', 'rifle', 'shotgun', 'smg', 'other'],
                    (value) => setDialogState(() => firearmType = value!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Quantity:',
                          style: TextStyle(color: Color(0xFF78909C))),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.remove_circle,
                            color: Color(0xFF1E88E5)),
                        onPressed: quantity > 1
                            ? () => setDialogState(() => quantity--)
                            : null,
                      ),
                      Text('$quantity',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle,
                            color: Color(0xFF1E88E5)),
                        onPressed: () => setDialogState(() => quantity++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(justificationController, 'Justification',
                      maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF78909C))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (justificationController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please provide justification'),
                        backgroundColor: Color(0xFFE85C5C)),
                  );
                  return;
                }
                Navigator.pop(dialogContext);
                try {
                  await _reportService.createProcurementRequest(
                    firearmType: firearmType,
                    quantity: quantity,
                    justification: justificationController.text,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Procurement request submitted'),
                          backgroundColor: Color(0xFF3CCB7F)),
                    );
                    _loadData();
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5)),
              child: const Text('Submit Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirearmDropdown(String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: const Text('Select Firearm',
          style: TextStyle(color: Color(0xFF78909C))),
      dropdownColor: const Color(0xFF2A3040),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Firearm',
        labelStyle: const TextStyle(color: Color(0xFF78909C)),
        prefixIcon: const Icon(Icons.gps_fixed, color: Color(0xFF78909C)),
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
      items: _unitFirearms
          .map((f) => DropdownMenuItem(
                value: f['firearm_id']?.toString(),
                child: Text(
                    '${f['serial_number']} - ${f['manufacturer']} ${f['model']}'),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items,
      Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
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
      Map<String, dynamic> report, String type, String action) async {
    try {
      // Handle approval/rejection based on type
      if (type == 'loss') {
        await _reportService.updateLossReportStatus(
            report['loss_report_id'].toString(), action);
      } else if (type == 'destruction') {
        await _reportService.updateDestructionRequestStatus(
            report['destruction_request_id'].toString(), action);
      } else if (type == 'procurement') {
        await _reportService.updateProcurementRequestStatus(
            report['procurement_request_id'].toString(), action);
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
        _loadData();
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
}
