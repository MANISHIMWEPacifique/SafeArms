// Anomaly Detection Screen
// Real-time anomaly monitoring and investigation dashboard

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/anomaly_provider.dart';

class AnomalyDetectionScreen extends StatefulWidget {
  const AnomalyDetectionScreen({super.key});

  @override
  State<AnomalyDetectionScreen> createState() => _AnomalyDetectionScreenState();
}

class _AnomalyDetectionScreenState extends State<AnomalyDetectionScreen> {
  String _selectedSeverity = 'all';
  String _selectedStatus = 'all';
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    // Schedule load after build to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAnomalies();
      if (_autoRefresh) {
        _startAutoRefresh();
      }
    });
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
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

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: Column(
        children: [
          _buildHeader(role),
          _buildStatsCards(),
          _buildFilters(),
          Expanded(child: _buildAnomalyList()),
        ],
      ),
    );
  }

  Widget _buildHeader(String? role) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF252A3A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE85C5C).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE85C5C),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anomaly Detection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role == 'station_commander'
                      ? 'Unit-level anomaly monitoring'
                      : 'ML-powered custody pattern analysis',
                  style: const TextStyle(
                    color: Color(0xFFB0BEC5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // Auto-refresh toggle
          Row(
            children: [
              Icon(
                Icons.refresh,
                color: _autoRefresh
                    ? const Color(0xFF3CCB7F)
                    : const Color(0xFF78909C),
                size: 20,
              ),
              const SizedBox(width: 8),
              Switch(
                value: _autoRefresh,
                onChanged: (value) {
                  setState(() => _autoRefresh = value);
                  if (value) _startAutoRefresh();
                },
                activeThumbColor: const Color(0xFF3CCB7F),
              ),
              const SizedBox(width: 8),
              const Text(
                'Auto-refresh',
                style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _loadAnomalies,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
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
        final open = anomalies
            .where((a) => a['status'] == 'open' || a['status'] == 'detected')
            .length;

        return Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Anomalies',
                  anomalies.length.toString(),
                  Icons.warning_amber,
                  const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Critical',
                  critical.toString(),
                  Icons.error,
                  const Color(0xFFE85C5C),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'High Priority',
                  high.toString(),
                  Icons.warning,
                  const Color(0xFFFFA726),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Medium',
                  medium.toString(),
                  Icons.info,
                  const Color(0xFFFFCA28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Open Cases',
                  open.toString(),
                  Icons.folder_open,
                  const Color(0xFF3CCB7F),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
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
          const SizedBox(height: 8),
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

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          const Text(
            'Filters:',
            style: TextStyle(
              color: Color(0xFFB0BEC5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          _buildFilterDropdown(
            'Severity',
            _selectedSeverity,
            ['all', 'critical', 'high', 'medium', 'low'],
            (value) {
              setState(() => _selectedSeverity = value!);
              _loadAnomalies();
            },
          ),
          const SizedBox(width: 16),
          _buildFilterDropdown(
            'Status',
            _selectedStatus,
            [
              'all',
              'open',
              'detected',
              'investigating',
              'resolved',
              'false_positive'
            ],
            (value) {
              setState(() => _selectedStatus = value!);
              _loadAnomalies();
            },
          ),
          const Spacer(),
          Text(
            'Last updated: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF37404F), width: 1),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(0xFF78909C),
              fontSize: 13,
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            underline: const SizedBox(),
            dropdownColor: const Color(0xFF252A3A),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(
                  item.toUpperCase(),
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }).toList(),
          ),
        ],
      ),
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

        return Container(
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF252A3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF37404F), width: 1),
          ),
          child: Column(
            children: [
              // Table Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF37404F), width: 1),
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
              // Table Body
              Expanded(
                child: ListView.builder(
                  itemCount: provider.anomalies.length,
                  itemBuilder: (context, index) {
                    final anomaly = provider.anomalies[index];
                    return _buildAnomalyRow(anomaly, index);
                  },
                ),
              ),
            ],
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
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAnomalyRow(Map<String, dynamic> anomaly, int index) {
    final severity = anomaly['severity'] ?? 'medium';
    final status = anomaly['status'] ?? 'open';
    final score = (anomaly['anomaly_score'] ?? 0.0) as double;

    Color severityColor;
    switch (severity) {
      case 'critical':
        severityColor = const Color(0xFFE85C5C);
        break;
      case 'high':
        severityColor = const Color(0xFFFFA726);
        break;
      case 'medium':
        severityColor = const Color(0xFFFFCA28);
        break;
      case 'low':
        severityColor = const Color(0xFF3CCB7F);
        break;
      default:
        severityColor = const Color(0xFF78909C);
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              '#${anomaly['anomaly_id']?.toString().substring(0, 8) ?? 'N/A'}',
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
              anomaly['anomaly_type'] ?? 'Unknown',
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
              anomaly['firearm_serial'] ?? 'N/A',
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

  void _showAnomalyDetails(Map<String, dynamic> anomaly) {
    showDialog(
      context: context,
      builder: (context) => _AnomalyDetailDialog(anomaly: anomaly),
    );
  }
}

// Anomaly Detail Dialog
class _AnomalyDetailDialog extends StatelessWidget {
  final Map<String, dynamic> anomaly;

  const _AnomalyDetailDialog({required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final contributingFactors =
        anomaly['contributing_factors'] as Map<String, dynamic>?;
    final featureImportance =
        anomaly['feature_importance'] as Map<String, dynamic>?;

    return Dialog(
      backgroundColor: const Color(0xFF252A3A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF37404F), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE85C5C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE85C5C),
                      size: 24,
                    ),
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
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${anomaly['anomaly_id']?.toString().substring(0, 12) ?? 'N/A'}',
                          style: const TextStyle(
                            color: Color(0xFF78909C),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF78909C)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('Detection Information', [
                      _InfoRow('Type', anomaly['anomaly_type'] ?? 'N/A'),
                      _InfoRow('Severity', anomaly['severity'] ?? 'N/A'),
                      _InfoRow('Score',
                          '${((anomaly['anomaly_score'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
                      _InfoRow('Detection Method',
                          anomaly['detection_method'] ?? 'N/A'),
                      _InfoRow('Confidence',
                          '${((anomaly['confidence_level'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
                      _InfoRow('Detected At',
                          _formatDateTime(anomaly['detected_at'])),
                    ]),
                    const SizedBox(height: 24),
                    _buildInfoSection('Custody Information', [
                      _InfoRow('Firearm', anomaly['firearm_serial'] ?? 'N/A'),
                      _InfoRow('Officer', anomaly['officer_name'] ?? 'N/A'),
                      _InfoRow('Unit', anomaly['unit_name'] ?? 'N/A'),
                      _InfoRow(
                          'Custody Type', anomaly['custody_type'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 24),
                    if (contributingFactors != null) ...[
                      _buildContributingFactors(contributingFactors),
                      const SizedBox(height: 24),
                    ],
                    if (featureImportance != null) ...[
                      _buildFeatureImportance(featureImportance),
                      const SizedBox(height: 24),
                    ],
                    _buildInvestigationSection(anomaly),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF37404F), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB0BEC5),
                      side: const BorderSide(color: Color(0xFF37404F)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Mark as investigating
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Mark as Investigating'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildContributingFactors(Map<String, dynamic> factors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contributing Factors',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
                      child: Text(
                        entry.key.replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFFB0BEC5), fontSize: 13),
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        color: Color(0xFFE85C5C),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureImportance(Map<String, dynamic> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feature Importance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Column(
            children: features.entries.map((entry) {
              final value = (entry.value as num).toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(
                              color: Color(0xFFB0BEC5), fontSize: 12),
                        ),
                        Text(
                          '${(value * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                              color: Color(0xFF1E88E5), fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF37404F),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF1E88E5)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInvestigationSection(Map<String, dynamic> anomaly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Investigation Status',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3040),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Status', anomaly['status'] ?? 'N/A'),
              if (anomaly['investigation_notes'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Investigation Notes:',
                  style: TextStyle(color: Color(0xFF78909C), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  anomaly['investigation_notes'],
                  style:
                      const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                ),
              ],
            ],
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
      return DateFormat('MMM dd, yyyy HH:mm:ss').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Color(0xFF78909C),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFFB0BEC5),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
