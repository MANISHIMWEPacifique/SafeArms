// Anomaly Detection Screen
// Real-time anomaly monitoring and investigation dashboard
// Severity-based workflow: critical requires explanation, medium for reference, false positive feeds ML

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../../providers/unit_provider.dart';

class AnomalyDetectionScreen extends StatefulWidget {
  const AnomalyDetectionScreen({super.key});

  @override
  State<AnomalyDetectionScreen> createState() => _AnomalyDetectionScreenState();
}

class _AnomalyDetectionScreenState extends State<AnomalyDetectionScreen> {
  String _selectedSeverity = 'all';
  String _selectedStatus = 'all';
  bool _autoRefresh = true;
  // Track which view is active: 'monitoring' or 'investigation'
  String _activeView = 'monitoring';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnomalies();
      if (_autoRefresh) {
        _startAutoRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 120), () {
      if (mounted && _autoRefresh) {
        _loadAnomalies();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _loadAnomalies() async {
    final anomalyProvider =
        Provider.of<AnomalyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.currentUser?['role'] == 'station_commander') {
      await anomalyProvider.loadUnitAnomalies(
        authProvider.currentUser!['unit_id'],
        limit: 100,
      );
    } else {
      await anomalyProvider.loadAnomalies(
        limit: 100,
        severity: _selectedSeverity == 'all' ? null : _selectedSeverity,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.currentUser?['role'];
    final isInvestigator = role == 'investigator';
    final isCompact = MediaQuery.of(context).size.width < 1100;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Column(
        children: [
          _buildHeader(role, isCompact: isCompact),
          if (isInvestigator ||
              role == 'hq_firearm_commander' ||
              role == 'admin')
            _buildViewTabs(isCompact: isCompact),
          if (_activeView == 'monitoring') ...[
            _buildStatsCards(),
            _buildFilters(),
            Expanded(child: _buildAnomalyList()),
          ] else ...[
            Expanded(child: _InvestigationSearchPanel()),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(String? role, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 20,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anomaly Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  role == 'station_commander'
                      ? 'Unit-level monitoring'
                      : 'ML-powered analysis',
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _loadAnomalies,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewTabs({bool isCompact = false}) {
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isCompact ? 12 : 20, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTab('Monitoring', 'monitoring', Icons.monitor_heart),
            const SizedBox(width: 8),
            _buildTab('Investigation Search', 'investigation', Icons.search),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, String view, IconData icon) {
    final isActive = _activeView == view;
    return InkWell(
      onTap: () => setState(() => _activeView = view),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1E88E5).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF1E88E5).withValues(alpha: 0.5)
                : const Color(0xFF37404F),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isActive
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFF78909C),
                size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFF78909C),
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Consumer<AnomalyProvider>(
      builder: (context, provider, child) {
        final anomalies = provider.anomalies;
        final critical =
            anomalies.where((a) => a['severity'] == 'critical').length;
        final high = anomalies.where((a) => a['severity'] == 'high').length;
        final medium = anomalies.where((a) => a['severity'] == 'medium').length;
        final open = anomalies.where((a) => a['status'] == 'open').length;

        final cards = [
          _buildStatCard(
            'Total Anomalies',
            anomalies.length.toString(),
            Icons.warning_amber,
            const Color(0xFF1E88E5),
          ),
          _buildStatCard(
            'Critical',
            critical.toString(),
            Icons.error,
            const Color(0xFF1E88E5),
          ),
          _buildStatCard(
            'High Priority',
            high.toString(),
            Icons.warning,
            const Color(0xFF1E88E5),
          ),
          _buildStatCard(
            'Medium',
            medium.toString(),
            Icons.info,
            const Color(0xFF1E88E5),
          ),
          _buildStatCard(
            'Open Cases',
            open.toString(),
            Icons.folder_open,
            const Color(0xFF1E88E5),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 900 ? 12 : 20,
                vertical: 12,
              ),
              child: constraints.maxWidth >= 1100
                  ? Row(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i < cards.length - 1) const SizedBox(width: 12),
                        ],
                      ],
                    )
                  : Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: cards
                          .map((card) => SizedBox(
                                width: constraints.maxWidth >= 700
                                    ? (constraints.maxWidth - 12) / 2
                                    : constraints.maxWidth,
                                child: card,
                              ))
                          .toList(),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF37404F), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF252A3A),
          border: Border.all(color: const Color(0xFF37404F)),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 980;
            final itemWidth = constraints.maxWidth < 700
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;

            final severityWidget = _buildFilterDropdown(
              label: 'Severity',
              value: _selectedSeverity,
              items: [
                {'value': 'all', 'label': 'All Severities'},
                {'value': 'critical', 'label': 'Critical'},
                {'value': 'high', 'label': 'High'},
                {'value': 'medium', 'label': 'Medium'},
                {'value': 'low', 'label': 'Low'},
              ],
              onChanged: (value) {
                setState(() => _selectedSeverity = value!);
                _loadAnomalies();
              },
            );

            final statusWidget = _buildFilterDropdown(
              label: 'Status',
              value: _selectedStatus,
              items: [
                {'value': 'all', 'label': 'All Statuses'},
                {'value': 'open', 'label': 'Open'},
                {'value': 'investigating', 'label': 'Investigating'},
                {'value': 'resolved', 'label': 'Resolved'},
                {'value': 'false_positive', 'label': 'False Positive'},
              ],
              onChanged: (value) {
                setState(() => _selectedStatus = value!);
                _loadAnomalies();
              },
            );

            final autoRefreshWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Auto Refresh',
                    style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
                const SizedBox(height: 2),
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3040),
                    border: Border.all(color: const Color(0xFF37404F)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: Color(0xFF78909C), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _autoRefresh ? 'Every 2min' : 'Disabled',
                        style: TextStyle(
                          color: _autoRefresh
                              ? Colors.white
                              : const Color(0xFF78909C),
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _autoRefresh,
                        onChanged: (val) {
                          setState(() => _autoRefresh = val);
                          if (val) {
                            _startAutoRefresh();
                          }
                        },
                        activeThumbColor: const Color(0xFF3CCB7F),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ],
            );

            final updatedRow = Row(
              children: [
                if (_selectedSeverity != 'all' || _selectedStatus != 'all')
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedSeverity = 'all';
                        _selectedStatus = 'all';
                      });
                      _loadAnomalies();
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64B5F6)),
                  ),
                const SizedBox(width: 8),
                Text(
                  'Updated ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                  style: const TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 12,
                  ),
                ),
              ],
            );

            if (!isCompact) {
              return Row(
                children: [
                  Expanded(child: severityWidget),
                  const SizedBox(width: 16),
                  Expanded(child: statusWidget),
                  const SizedBox(width: 16),
                  Expanded(child: autoRefreshWidget),
                  const SizedBox(width: 16),
                  updatedRow,
                ],
              );
            }

            return Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(width: itemWidth, child: severityWidget),
                SizedBox(width: itemWidth, child: statusWidget),
                SizedBox(width: itemWidth, child: autoRefreshWidget),
                SizedBox(width: constraints.maxWidth, child: updatedRow),
              ],
            );
          },
        ),
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
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
        const SizedBox(height: 2),
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
              style: const TextStyle(color: Colors.white, fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildAnomalyList() {
    return Consumer<AnomalyProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
        }

        if (provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFE85C5C),
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error: ${provider.error}',
                  style: const TextStyle(color: Color(0xFFE85C5C)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadAnomalies,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (provider.anomalies.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: const Color(0xFF3CCB7F).withValues(alpha: 0.5),
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No anomalies detected',
                  style: TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'All custody patterns are within normal parameters',
                  style: TextStyle(
                    color: Color(0xFF78909C),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        // Show the last 4 anomalies to fill available space
        final displayAnomalies = provider.anomalies.length > 4
            ? provider.anomalies.sublist(provider.anomalies.length - 4)
            : provider.anomalies;

        return Padding(
          padding:
              const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth =
                  constraints.maxWidth < 800 ? 800.0 : constraints.maxWidth;
              final listHeight = constraints.maxHeight - 52;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF252A3A),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFF37404F), width: 1),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Color(0xFF37404F), width: 1),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildHeaderCell('Anomaly ID', flex: 2),
                              _buildHeaderCell('Type', flex: 2),
                              _buildHeaderCell('Severity', flex: 1),
                              _buildHeaderCell('Score', flex: 1),
                              _buildHeaderCell('Firearm', flex: 2),
                              _buildHeaderCell('Officer', flex: 2),
                              _buildHeaderCell('Unit', flex: 2),
                              _buildHeaderCell('Detected', flex: 2),
                              _buildHeaderCell('Status', flex: 1),
                              _buildHeaderCell('Actions', flex: 1),
                            ],
                          ),
                        ),
                        // Table Body - scrollable rows
                        SizedBox(
                          height: listHeight > 0 ? listHeight : 260,
                          child: ListView.builder(
                            itemCount: displayAnomalies.length,
                            itemBuilder: (context, index) => _buildAnomalyRow(
                                displayAnomalies[index], index),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF78909C),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAnomalyRow(Map<String, dynamic> anomaly, int index) {
    final severity = anomaly['severity'] ?? 'medium';
    final status = anomaly['status'] ?? 'open';
    final score =
        double.tryParse(anomaly['anomaly_score']?.toString() ?? '0') ?? 0.0;

    Color severityColor;
    switch (severity) {
      case 'critical':
        severityColor = const Color(0xFFE85C5C);
        break;
      case 'high':
        severityColor = const Color(0xFFFF8A65);
        break;
      case 'medium':
        severityColor = const Color(0xFFFFCA28);
        break;
      case 'low':
        severityColor = const Color(0xFF78909C);
        break;
      default:
        severityColor = const Color(0xFF78909C);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            index % 2 == 0 ? const Color(0xFF2A3040) : const Color(0xFF252A3A),
        border: const Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '#${anomaly['anomaly_id']?.toString() ?? 'N/A'}',
              style: const TextStyle(
                color: Color(0xFF1E88E5),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatAnomalyType(anomaly['anomaly_type'] ?? 'Unknown'),
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: severityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: severityColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                severity.toUpperCase(),
                style: TextStyle(
                  color: severityColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF37404F),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: score,
                    child: Container(
                      decoration: BoxDecoration(
                        color: severityColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  (score * 100).toStringAsFixed(0),
                  style: TextStyle(
                    color: severityColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              anomaly['serial_number'] ?? 'N/A',
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              anomaly['officer_name'] ?? 'N/A',
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              anomaly['unit_name'] ?? 'N/A',
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatDateTime(anomaly['detected_at']),
              style: const TextStyle(
                color: Color(0xFF78909C),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: _buildStatusBadge(status),
          ),
          Expanded(
            flex: 1,
            child: IconButton(
              icon: const Icon(Icons.info_outline, size: 18),
              color: const Color(0xFF1E88E5),
              onPressed: () => _showAnomalyDetails(anomaly),
              tooltip: 'View Details',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'open':
      case 'detected':
        statusColor = const Color(0xFFE85C5C);
        statusIcon = Icons.circle;
        break;
      case 'investigating':
        statusColor = const Color(0xFFFFCA28);
        statusIcon = Icons.search;
        break;
      case 'resolved':
        statusColor = const Color(0xFF3CCB7F);
        statusIcon = Icons.check_circle;
        break;
      case 'false_positive':
        statusColor = const Color(0xFF78909C);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF78909C);
        statusIcon = Icons.help_outline;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 12),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date =
          timestamp is DateTime ? timestamp : DateTime.parse(timestamp);
      return DateFormat('MMM dd, HH:mm').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  String _formatAnomalyType(String type) {
    const typeLabels = {
      'overdue_return': 'Overdue Return',
      'overdue_return_extended': 'Extended Overdue (3+ days)',
      'overdue_return_critical': 'Critical Overdue (7+ days)',
      'cross_unit_transfer': 'Cross-Unit Transfer',
      'rapid_exchange_pattern': 'Rapid Exchange',
      'unusual_custody_duration': 'Unusual Duration',
      'unusual_issue_frequency': 'Unusual Frequency',
      'off_hours_activity': 'Off-Hours Activity',
      'cluster_outlier': 'Pattern Outlier',
      'high_exchange_rate': 'High Exchange Rate',
      'behavioral_deviation': 'Behavioral Deviation',
      'ballistic_access_before_custody': 'Ballistic Access Before Custody',
      'ballistic_access_after_custody': 'Ballistic Access After Custody',
      'ballistic_access_timing_pattern': 'Ballistic Timing Pattern',
      'cross_unit_anomaly': 'Cross-Unit Pattern',
    };
    return typeLabels[type] ?? type.replaceAll('_', ' ');
  }

  void _showAnomalyDetails(Map<String, dynamic> anomaly) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => _AnomalyDetailModal(
        anomaly: anomaly,
        onActionComplete: () => _loadAnomalies(),
      ),
    );
  }
}

// ============================================================
// Investigation Search Panel - Filter by unit and time interval
// ============================================================
class _InvestigationSearchPanel extends StatefulWidget {
  @override
  State<_InvestigationSearchPanel> createState() =>
      _InvestigationSearchPanelState();
}

class _InvestigationSearchPanelState extends State<_InvestigationSearchPanel> {
  String? _selectedUnitId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchSeverity = 'all';
  String _searchStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final unitProvider = Provider.of<UnitProvider>(context, listen: false);
      if (unitProvider.units.isEmpty) {
        unitProvider.loadUnits();
      }
    });
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1E88E5),
              onPrimary: Colors.white,
              surface: Color(0xFF252A3A),
              onSurface: Colors.white,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFF252A3A),
              headerBackgroundColor: const Color(0xFF1A1F2E),
              headerForegroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFF546E7A);
                }
                return Colors.white;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const Color(0xFF1E88E5);
                }
                return Colors.transparent;
              }),
              todayForegroundColor:
                  WidgetStateProperty.all(const Color(0xFF42A5F5)),
              todayBackgroundColor: WidgetStateProperty.all(Colors.transparent),
              todayBorder: const BorderSide(color: Color(0xFF42A5F5)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _performSearch() {
    final provider = Provider.of<AnomalyProvider>(context, listen: false);
    provider.searchForInvestigation(
      unitId: _selectedUnitId,
      startDate: _startDate?.toIso8601String(),
      endDate: _endDate != null
          ? DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)
              .toIso8601String()
          : null,
      severity: _searchSeverity == 'all' ? null : _searchSeverity,
      status: _searchStatus == 'all' ? null : _searchStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Form
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth < 1100;
              final fieldWidth = constraints.maxWidth < 680
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 2;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.search,
                            color: Color(0xFF1E88E5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Investigation Search',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            Text(
                                'Search anomaly data by unit and time interval',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (!isTablet) ...[
                    Row(
                      children: [
                        Expanded(child: _buildUnitDropdown()),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildDatePicker('Start Date', _startDate,
                                () => _selectDate(true))),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _buildDatePicker('End Date', _endDate,
                                () => _selectDate(false))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdownField(
                            'Severity',
                            _searchSeverity,
                            [
                              {'value': 'all', 'label': 'All Severities'},
                              {'value': 'critical', 'label': 'Critical'},
                              {'value': 'high', 'label': 'High'},
                              {'value': 'medium', 'label': 'Medium'},
                              {'value': 'low', 'label': 'Low'},
                            ],
                            (v) => setState(() => _searchSeverity = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDropdownField(
                            'Status',
                            _searchStatus,
                            [
                              {'value': 'all', 'label': 'All Statuses'},
                              {'value': 'open', 'label': 'Open'},
                              {
                                'value': 'investigating',
                                'label': 'Investigating'
                              },
                              {'value': 'resolved', 'label': 'Resolved'},
                              {
                                'value': 'false_positive',
                                'label': 'False Positive'
                              },
                            ],
                            (v) => setState(() => _searchStatus = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('', style: TextStyle(fontSize: 11)),
                              const SizedBox(height: 2),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _performSearch,
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('Search'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                            width: fieldWidth, child: _buildUnitDropdown()),
                        SizedBox(
                            width: fieldWidth,
                            child: _buildDatePicker('Start Date', _startDate,
                                () => _selectDate(true))),
                        SizedBox(
                            width: fieldWidth,
                            child: _buildDatePicker('End Date', _endDate,
                                () => _selectDate(false))),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildDropdownField(
                            'Severity',
                            _searchSeverity,
                            [
                              {'value': 'all', 'label': 'All Severities'},
                              {'value': 'critical', 'label': 'Critical'},
                              {'value': 'high', 'label': 'High'},
                              {'value': 'medium', 'label': 'Medium'},
                              {'value': 'low', 'label': 'Low'},
                            ],
                            (v) => setState(() => _searchSeverity = v!),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: _buildDropdownField(
                            'Status',
                            _searchStatus,
                            [
                              {'value': 'all', 'label': 'All Statuses'},
                              {'value': 'open', 'label': 'Open'},
                              {
                                'value': 'investigating',
                                'label': 'Investigating'
                              },
                              {'value': 'resolved', 'label': 'Resolved'},
                              {
                                'value': 'false_positive',
                                'label': 'False Positive'
                              },
                            ],
                            (v) => setState(() => _searchStatus = v!),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('', style: TextStyle(fontSize: 11)),
                              const SizedBox(height: 2),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _performSearch,
                                  icon: const Icon(Icons.search, size: 18),
                                  label: const Text('Search'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        // Results
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildUnitDropdown() {
    return Consumer<UnitProvider>(
      builder: (context, unitProvider, _) {
        final units = unitProvider.units;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unit',
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
            const SizedBox(height: 2),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                border: Border.all(color: const Color(0xFF37404F)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _selectedUnitId,
                  isExpanded: true,
                  hint: const Text('All Units',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFF78909C)),
                  dropdownColor: const Color(0xFF2A3040),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('All Units')),
                    ...units.map((u) => DropdownMenuItem<String?>(
                          value: u['unit_id']?.toString(),
                          child: Text(u['unit_name']?.toString() ?? ''),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedUnitId = v),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
        const SizedBox(height: 2),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? DateFormat('dd/MM/yyyy').format(date)
                      : 'Select date',
                  style: TextStyle(
                    color: date != null ? Colors.white : Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value,
      List<Map<String, String>> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
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
              style: const TextStyle(color: Colors.white, fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              items: items
                  .map((item) => DropdownMenuItem<String>(
                      value: item['value'], child: Text(item['label']!)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Consumer<AnomalyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
        }

        final results = provider.investigationResults;
        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off,
                    color: const Color(0xFF78909C).withValues(alpha: 0.5),
                    size: 64),
                const SizedBox(height: 16),
                const Text('No results',
                    style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 18)),
                const SizedBox(height: 8),
                const Text(
                    'Use the filters above to search for anomalies related to your investigation',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14)),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF37404F), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: Color(0xFF37404F), width: 1)),
                ),
                child: Row(
                  children: [
                    Text('${results.length} results found',
                        style: const TextStyle(
                            color: Color(0xFFB0BEC5), fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Provider.of<AnomalyProvider>(context, listen: false)
                            .clearInvestigationResults();
                      },
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Clear'),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64B5F6)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = constraints.maxWidth < 900
                        ? 900.0
                        : constraints.maxWidth;

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: tableWidth,
                        child: Column(
                          children: [
                            // Table header
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Color(0xFF37404F), width: 1)),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                      flex: 2,
                                      child: Text('ID',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Type',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 1,
                                      child: Text('Severity',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Officer',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Unit',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 2,
                                      child: Text('Detected',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 1,
                                      child: Text('Status',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                  Expanded(
                                      flex: 1,
                                      child: Text('Actions',
                                          style: TextStyle(
                                              color: Color(0xFF78909C),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600))),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (context, index) {
                                  final anomaly = results[index];
                                  final severity =
                                      anomaly['severity'] ?? 'medium';
                                  final status = anomaly['status'] ?? 'open';
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: index % 2 == 0
                                          ? const Color(0xFF2A3040)
                                          : const Color(0xFF252A3A),
                                      border: const Border(
                                          bottom: BorderSide(
                                              color: Color(0xFF37404F),
                                              width: 1)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                              '#${anomaly['anomaly_id'] ?? 'N/A'}',
                                              style: const TextStyle(
                                                  color: Color(0xFF1E88E5),
                                                  fontSize: 13,
                                                  fontFamily: 'monospace')),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                              _formatAnomalyType(
                                                  anomaly['anomaly_type'] ??
                                                      ''),
                                              style: const TextStyle(
                                                  color: Color(0xFFB0BEC5),
                                                  fontSize: 13)),
                                        ),
                                        Expanded(
                                            flex: 1,
                                            child:
                                                _buildSeverityBadge(severity)),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                              anomaly['officer_name'] ?? 'N/A',
                                              style: const TextStyle(
                                                  color: Color(0xFFB0BEC5),
                                                  fontSize: 13)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                              anomaly['unit_name'] ?? 'N/A',
                                              style: const TextStyle(
                                                  color: Color(0xFFB0BEC5),
                                                  fontSize: 13)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                              _formatDateTime(
                                                  anomaly['detected_at']),
                                              style: const TextStyle(
                                                  color: Color(0xFF78909C),
                                                  fontSize: 12)),
                                        ),
                                        Expanded(
                                            flex: 1,
                                            child: _buildStatusBadgeStatic(
                                                status)),
                                        Expanded(
                                          flex: 1,
                                          child: IconButton(
                                            icon: const Icon(Icons.info_outline,
                                                size: 18),
                                            color: const Color(0xFF1E88E5),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                barrierColor: Colors.black
                                                    .withValues(alpha: 0.5),
                                                builder: (_) =>
                                                    _AnomalyDetailModal(
                                                        anomaly: anomaly,
                                                        onActionComplete:
                                                            () {}),
                                              );
                                            },
                                            tooltip: 'View Details',
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeverityBadge(String severity) {
    final colors = {
      'critical': const Color(0xFFE85C5C),
      'high': const Color(0xFFFF8A65),
      'medium': const Color(0xFFFFCA28),
      'low': const Color(0xFF78909C),
    };
    final color = colors[severity] ?? const Color(0xFF78909C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(severity.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildStatusBadgeStatic(String status) {
    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'open':
      case 'detected':
        statusColor = const Color(0xFFE85C5C);
        statusIcon = Icons.circle;
        break;
      case 'investigating':
        statusColor = const Color(0xFFFFCA28);
        statusIcon = Icons.search;
        break;
      case 'resolved':
        statusColor = const Color(0xFF3CCB7F);
        statusIcon = Icons.check_circle;
        break;
      case 'false_positive':
        statusColor = const Color(0xFF78909C);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFF78909C);
        statusIcon = Icons.help_outline;
    }
    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 12),
        const SizedBox(width: 4),
        Expanded(
          child: Text(status.toUpperCase(),
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  String _formatAnomalyType(String type) {
    const typeLabels = {
      'overdue_return': 'Overdue Return',
      'overdue_return_extended': 'Extended Overdue (3+ days)',
      'overdue_return_critical': 'Critical Overdue (7+ days)',
      'cross_unit_transfer': 'Cross-Unit Transfer',
      'rapid_exchange_pattern': 'Rapid Exchange',
      'unusual_custody_duration': 'Unusual Duration',
      'unusual_issue_frequency': 'Unusual Frequency',
      'off_hours_activity': 'Off-Hours Activity',
      'cluster_outlier': 'Pattern Outlier',
      'high_exchange_rate': 'High Exchange Rate',
      'behavioral_deviation': 'Behavioral Deviation',
      'ballistic_access_before_custody': 'Ballistic Access Before Custody',
      'ballistic_access_after_custody': 'Ballistic Access After Custody',
      'ballistic_access_timing_pattern': 'Ballistic Timing Pattern',
      'cross_unit_anomaly': 'Cross-Unit Pattern',
    };
    return typeLabels[type] ?? type.replaceAll('_', ' ');
  }

  String _formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date =
          timestamp is DateTime ? timestamp : DateTime.parse(timestamp);
      return DateFormat('MMM dd, HH:mm').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }
}

// ============================================================
// Anomaly Detail Modal - Officer details form style
// Severity-based workflow with false positive, explanation, investigation
// ============================================================
class _AnomalyDetailModal extends StatefulWidget {
  final Map<String, dynamic> anomaly;
  final VoidCallback onActionComplete;

  const _AnomalyDetailModal({
    required this.anomaly,
    required this.onActionComplete,
  });

  @override
  State<_AnomalyDetailModal> createState() => _AnomalyDetailModalState();
}

class _AnomalyDetailModalState extends State<_AnomalyDetailModal> {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _performAction(String action) async {
    final anomalyId = widget.anomaly['anomaly_id']?.toString();
    if (anomalyId == null) return;

    setState(() => _isProcessing = true);

    final provider = Provider.of<AnomalyProvider>(context, listen: false);
    final notes = _notesController.text.trim();
    bool success;

    switch (action) {
      case 'investigate':
        success = await provider.investigateAnomaly(anomalyId,
            notes: notes.isNotEmpty ? notes : null);
        break;
      case 'resolve':
        success = await provider.resolveAnomaly(anomalyId,
            notes: notes.isNotEmpty ? notes : null);
        break;
      case 'false_positive':
        success = await provider.markFalsePositive(anomalyId,
            notes: notes.isNotEmpty ? notes : null);
        break;
      case 'explanation':
        final message = _explanationController.text.trim();
        if (message.isEmpty) {
          setState(() => _isProcessing = false);
          return;
        }
        success = await provider.submitExplanation(anomalyId, message: message);
        break;
      default:
        return;
    }

    if (!mounted) return;

    setState(() => _isProcessing = false);

    final actionLabels = {
      'investigate': 'Investigation started',
      'resolve': 'Anomaly resolved',
      'false_positive':
          'Marked as false positive — this data will be used to improve ML model accuracy',
      'explanation': 'Explanation submitted successfully',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? actionLabels[action] ?? 'Updated'
            : provider.error ?? 'Failed to update anomaly'),
        backgroundColor:
            success ? const Color(0xFF3CCB7F) : const Color(0xFFE85C5C),
        duration: const Duration(seconds: 3),
      ),
    );

    if (success) {
      widget.onActionComplete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = widget.anomaly['severity']?.toString() ?? 'medium';
    final status = widget.anomaly['status']?.toString() ?? 'open';
    final contributingFactors =
        widget.anomaly['contributing_factors'] as Map<String, dynamic>?;
    final featureImportance =
        widget.anomaly['feature_importance'] as Map<String, dynamic>?;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = authProvider.currentUser?['role'] ?? '';
    final isCritical = severity == 'critical';
    final isOpen = status == 'open' || status == 'investigating';
    final hasExplanation = widget.anomaly['explanation_message'] != null &&
        widget.anomaly['explanation_message'].toString().isNotEmpty;

    Color severityColor;
    IconData severityIcon;
    switch (severity) {
      case 'critical':
        severityColor = const Color(0xFFE85C5C);
        severityIcon = Icons.error;
        break;
      case 'high':
        severityColor = const Color(0xFFFF8A65);
        severityIcon = Icons.warning;
        break;
      case 'medium':
        severityColor = const Color(0xFFFFCA28);
        severityIcon = Icons.info;
        break;
      default:
        severityColor = const Color(0xFF78909C);
        severityIcon = Icons.info_outline;
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          width: 700,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - Officer details form style
              _buildModalHeader(severity, severityColor, severityIcon),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Severity Banner
                      _buildSeverityBanner(severity, severityColor),
                      const SizedBox(height: 24),

                      // Critical anomaly explanation requirement
                      if (isCritical &&
                          isOpen &&
                          !hasExplanation &&
                          (role == 'station_commander' ||
                              role == 'hq_firearm_commander')) ...[
                        _buildExplanationRequired(role),
                        const SizedBox(height: 24)
                      ],

                      // Existing explanation display
                      if (hasExplanation) ...[
                        _buildExplanationDisplay(),
                        const SizedBox(height: 24)
                      ],

                      // False positive ML training info
                      if (isOpen) ...[
                        _buildFalsePositiveInfo(),
                        const SizedBox(height: 24)
                      ],

                      // Detection Information
                      _buildSectionHeader('Detection Information'),
                      const SizedBox(height: 12),
                      _buildInfoCard([
                        _buildInfoRow(
                            'Type',
                            _formatAnomalyType(
                                widget.anomaly['anomaly_type'] ?? 'N/A')),
                        _buildInfoRow('Severity', severity.toUpperCase()),
                        _buildInfoRow('Score',
                            '${((double.tryParse(widget.anomaly['anomaly_score']?.toString() ?? '0') ?? 0.0) * 100).toStringAsFixed(1)}%'),
                        _buildInfoRow('Detection Method',
                            widget.anomaly['detection_method'] ?? 'N/A'),
                        _buildInfoRow('Confidence',
                            '${((double.tryParse(widget.anomaly['confidence_level']?.toString() ?? '0') ?? 0.0) * 100).toStringAsFixed(1)}%'),
                        _buildInfoRow('Detected At',
                            _formatDateTimeFull(widget.anomaly['detected_at'])),
                      ]),
                      const SizedBox(height: 24),

                      // Custody Information
                      _buildSectionHeader('Custody Information'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard([
                              _buildInfoRow('Firearm',
                                  widget.anomaly['serial_number'] ?? 'N/A'),
                              _buildInfoRow('Officer',
                                  widget.anomaly['officer_name'] ?? 'N/A'),
                            ]),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoCard([
                              _buildInfoRow(
                                  'Unit', widget.anomaly['unit_name'] ?? 'N/A'),
                              _buildInfoRow('Custody Type',
                                  widget.anomaly['custody_type'] ?? 'N/A'),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Contributing Factors
                      if (contributingFactors != null &&
                          contributingFactors.isNotEmpty) ...[
                        _buildSectionHeader('Contributing Factors'),
                        const SizedBox(height: 12),
                        _buildContributingFactors(contributingFactors),
                        const SizedBox(height: 24),
                      ],

                      // Feature Importance
                      if (featureImportance != null &&
                          featureImportance.isNotEmpty) ...[
                        _buildSectionHeader('Feature Importance'),
                        const SizedBox(height: 12),
                        _buildFeatureImportance(featureImportance),
                        const SizedBox(height: 24),
                      ],

                      // Investigation Status
                      _buildSectionHeader('Investigation Status'),
                      const SizedBox(height: 12),
                      _buildInvestigationSection(),
                      const SizedBox(height: 24),

                      // Notes input (for actionable statuses)
                      if (isOpen) ...[
                        _buildSectionHeader('Investigation Notes'),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: _inputDecoration(
                              'Enter investigation notes...', Icons.notes),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Action buttons footer
              _buildActionFooter(severity, status, role),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalHeader(
      String severity, Color severityColor, IconData severityIcon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.2),
            ),
            child: Icon(severityIcon, color: severityColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anomaly Details',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  'ID: ${widget.anomaly['anomaly_id']?.toString() ?? 'N/A'} — ${_formatAnomalyType(widget.anomaly['anomaly_type'] ?? '')}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white54),
            hoverColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityBanner(String severity, Color severityColor) {
    final messages = {
      'critical':
          'IMMEDIATE REVIEW REQUIRED — This critical anomaly requires explanation from the responsible station commander.',
      'high':
          'Review within 24 hours — This high-priority anomaly requires investigation attention.',
      'medium':
          'Reference for investigation — This anomaly can be referred to when investigation suspects related activity.',
      'low': 'Standard review queue — Low priority for routine monitoring.',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            severityColor.withValues(alpha: 0.2),
            const Color(0xFF1A1F2E)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severityColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            severity == 'critical' ? Icons.priority_high : Icons.info_outline,
            color: severityColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${severity.toUpperCase()} SEVERITY',
                  style: TextStyle(
                      color: severityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  messages[severity] ?? '',
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationRequired(String role) {
    final isStationCommander = role == 'station_commander';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE85C5C).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFE85C5C).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_late,
                  color: Color(0xFFE85C5C), size: 20),
              const SizedBox(width: 8),
              Text(
                isStationCommander
                    ? 'Explanation Required'
                    : 'Awaiting Station Commander Explanation',
                style: const TextStyle(
                    color: Color(0xFFE85C5C),
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isStationCommander
                ? 'As station commander, you must provide an explanation for this critical anomaly detected in your unit.'
                : 'The station commander responsible for this unit needs to provide an explanation for this critical anomaly.',
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
          ),
          if (isStationCommander) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _explanationController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: _inputDecoration(
                'Explain the circumstances of this anomaly...',
                Icons.edit_note,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isProcessing ? null : () => _performAction('explanation'),
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Submit Explanation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85C5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExplanationDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3CCB7F).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF3CCB7F).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF3CCB7F), size: 20),
              SizedBox(width: 8),
              Text('Explanation Provided',
                  style: TextStyle(
                      color: Color(0xFF3CCB7F),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.anomaly['explanation_message'].toString(),
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            ),
          ),
          if (widget.anomaly['explanation_date'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Submitted: ${_formatDateTimeFull(widget.anomaly['explanation_date'])}',
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFalsePositiveInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.psychology, color: Color(0xFF1E88E5), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'If this is a false positive, marking it will feed the ML training data to improve future detection accuracy.',
              style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text('$label:',
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildContributingFactors(Map<String, dynamic> factors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        children: factors.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFFE85C5C), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.key.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFFB0BEC5), fontSize: 13)),
                ),
                Text(entry.value.toString(),
                    style: const TextStyle(
                        color: Color(0xFFE85C5C),
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFeatureImportance(Map<String, dynamic> features) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        children: features.entries.map((entry) {
          final value = double.tryParse(entry.value?.toString() ?? '0') ?? 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFFB0BEC5), fontSize: 12)),
                    Text('${(value * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: Color(0xFF1E88E5), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF37404F),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInvestigationSection() {
    final anomaly = widget.anomaly;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Status', anomaly['status'] ?? 'N/A'),
          if (anomaly['investigated_by'] != null)
            _buildInfoRow(
                'Investigated By', anomaly['investigated_by'].toString()),
          if (anomaly['resolution_date'] != null)
            _buildInfoRow(
                'Resolved At', _formatDateTimeFull(anomaly['resolution_date'])),
          if (anomaly['investigation_notes'] != null &&
              anomaly['investigation_notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Investigation Notes:',
                style: TextStyle(color: Color(0xFF78909C), fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF252A3A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(anomaly['investigation_notes'].toString(),
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionFooter(String severity, String status, String role) {
    final isOpen = status == 'open' || status == 'investigating';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2E),
        border: Border(top: BorderSide(color: Color(0xFF37404F), width: 1)),
      ),
      child: Row(
        children: [
          // Close button
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB0BEC5),
              side: const BorderSide(color: Color(0xFF37404F)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close'),
          ),
          const Spacer(),
          if (isOpen) ...[
            // False Positive button - available for all open anomalies
            OutlinedButton.icon(
              onPressed:
                  _isProcessing ? null : () => _performAction('false_positive'),
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('False Positive'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF78909C),
                side: const BorderSide(color: Color(0xFF37404F)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            // Investigation button
            if (status == 'open')
              ElevatedButton.icon(
                onPressed:
                    _isProcessing ? null : () => _performAction('investigate'),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Start Investigation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFCA28),
                  foregroundColor: const Color(0xFF1A1F2E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            if (status == 'open') const SizedBox(width: 12),
            // Resolve button
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : () => _performAction('resolve'),
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Resolve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3CCB7F),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
          if (_isProcessing) ...[
            const SizedBox(width: 12),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Color(0xFF1E88E5), strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF78909C)),
      prefixIcon: Icon(icon, color: Colors.white54, size: 20),
      filled: true,
      fillColor: const Color(0xFF1A1F2E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF37404F)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF37404F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E88E5)),
      ),
    );
  }

  String _formatAnomalyType(String type) {
    const typeLabels = {
      'overdue_return': 'Overdue Return',
      'overdue_return_extended': 'Extended Overdue (3+ days)',
      'overdue_return_critical': 'Critical Overdue (7+ days)',
      'cross_unit_transfer': 'Cross-Unit Transfer',
      'rapid_exchange_pattern': 'Rapid Exchange',
      'unusual_custody_duration': 'Unusual Duration',
      'unusual_issue_frequency': 'Unusual Frequency',
      'off_hours_activity': 'Off-Hours Activity',
      'cluster_outlier': 'Pattern Outlier',
      'high_exchange_rate': 'High Exchange Rate',
      'behavioral_deviation': 'Behavioral Deviation',
      'ballistic_access_before_custody': 'Ballistic Access Before Custody',
      'ballistic_access_after_custody': 'Ballistic Access After Custody',
      'ballistic_access_timing_pattern': 'Ballistic Timing Pattern',
      'cross_unit_anomaly': 'Cross-Unit Pattern',
    };
    return typeLabels[type] ?? type.replaceAll('_', ' ');
  }

  String _formatDateTimeFull(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final date =
          timestamp is DateTime ? timestamp : DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy HH:mm:ss').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }
}
