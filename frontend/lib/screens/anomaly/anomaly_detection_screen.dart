// Anomaly Detection Screen
// Real-time anomaly monitoring and investigation dashboard
// Severity-based workflow: critical requires explanation, medium for reference, false positive feeds ML

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/anomaly_provider.dart';
import '../../providers/unit_provider.dart';
import '../../utils/app_transitions.dart';
import '../../widgets/anomaly_card_widget.dart';
import '../../widgets/base_modal_widget.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/searchable_dropdown.dart';

const double _anomalyDesktopBreakpoint = 1024;
const double _anomalyMobileBreakpoint = 768;
const double _investigationFormGap = 16;
const double _investigationControlHeight = 48;

const List<Map<String, String>> _anomalySeverityFilterItems = [
  {'value': 'all', 'label': 'All Severities'},
  {'value': 'critical', 'label': 'Critical'},
  {'value': 'high', 'label': 'High'},
  {'value': 'medium', 'label': 'Medium'},
  {'value': 'low', 'label': 'Low'},
];

const List<Map<String, String>> _anomalyStatusFilterItems = [
  {'value': 'all', 'label': 'All Statuses'},
  {'value': 'open', 'label': 'Open'},
  {'value': 'investigating', 'label': 'Investigating'},
  {'value': 'resolved', 'label': 'Resolved'},
  {'value': 'false_positive', 'label': 'False Positive'},
  {'value': 'acceptable_change', 'label': 'Acceptable Change'},
  {'value': 'archived', 'label': 'Archived'},
];

({Color color, IconData icon}) _statusStyle(String status) {
  switch (status) {
    case 'open':
    case 'detected':
      return (color: const Color(0xFFE85C5C), icon: Icons.circle);
    case 'investigating':
      return (color: const Color(0xFFFFCA28), icon: Icons.search);
    case 'resolved':
      return (color: const Color(0xFF3CCB7F), icon: Icons.check_circle);
    case 'false_positive':
      return (color: const Color(0xFF78909C), icon: Icons.cancel);
    case 'acceptable_change':
      return (color: const Color(0xFF42A5F5), icon: Icons.rule);
    case 'archived':
      return (color: const Color(0xFF78909C), icon: Icons.archive_outlined);
    default:
      return (color: const Color(0xFF78909C), icon: Icons.help_outline);
  }
}

Widget _buildAnomalyStatusBadge(String status) {
  final style = _statusStyle(status);
  return Row(
    children: [
      Icon(style.icon, color: style.color, size: 12),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          status.toUpperCase(),
          style: TextStyle(
            color: style.color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

String _formatDetectionMethod(dynamic method) {
  if (method == null) return 'N/A';
  final raw = method.toString().trim();
  if (raw.isEmpty) return 'N/A';

  final parts = raw
      .split('+')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  final filtered = parts.where((part) {
    final normalized = part.toLowerCase().replaceAll('-', '_');
    return normalized != 'rules' &&
        normalized != 'rule_based' &&
        normalized != 'rules_only' &&
        normalized != 'rulebased';
  }).toList();

  if (filtered.isEmpty) {
    return 'ensemble';
  }

  return filtered.join('+');
}

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser?['role'] == 'admin') {
        return;
      }

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

  @override
  void dispose() {
    _autoRefresh = false;
    super.dispose();
  }

  Future<void> _loadAnomalies() async {
    final anomalyProvider =
        Provider.of<AnomalyProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final selectedSeverity =
        _selectedSeverity == 'all' ? null : _selectedSeverity;
    final selectedStatus = _selectedStatus == 'all' ? null : _selectedStatus;
    final includeArchived = _selectedStatus == 'archived';

    if (authProvider.currentUser?['role'] == 'station_commander') {
      await anomalyProvider.loadUnitAnomalies(
        authProvider.currentUser!['unit_id'],
        limit: 100,
        severity: selectedSeverity,
        status: selectedStatus,
        includeRemoved: includeArchived,
        force: true,
      );
    } else {
      await anomalyProvider.loadAnomalies(
        limit: 100,
        severity: selectedSeverity,
        status: selectedStatus,
        includeRemoved: includeArchived,
        force: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final role = authProvider.currentUser?['role'];

    if (role == 'admin') {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1F2E),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A3A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF37404F)),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Color(0xFF78909C),
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Access restricted for admin role',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Admin accounts are training-only for anomaly domain. Use System Settings to run model training and review ML status.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB0BEC5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final isInvestigator = role == 'investigator';
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= _anomalyDesktopBreakpoint;
    final isMobile = width < _anomalyMobileBreakpoint;
    final isCompact = !isDesktop;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1F2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(role, isCompact: isCompact, isMobile: isMobile),
            if (isInvestigator ||
                role == 'hq_firearm_commander' ||
                role == 'admin')
              _buildViewTabs(isCompact: isCompact),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity:
                      CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  child: child,
                ),
                child: _activeView == 'monitoring'
                    ? KeyedSubtree(
                        key: const ValueKey('monitoring'),
                        child: _buildMonitoringContent(),
                      )
                    : const KeyedSubtree(
                        key: ValueKey('investigation'),
                        child: _InvestigationSearchPanel(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTightHeight = constraints.maxHeight < 700;

        if (!isTightHeight) {
          return Column(
            children: [
              _buildStatsCards(),
              _buildFilters(),
              Expanded(child: _buildAnomalyList()),
            ],
          );
        }

        final compactListHeight =
            (constraints.maxHeight * 0.55).clamp(240.0, 520.0);

        return SingleChildScrollView(
          child: Column(
            children: [
              _buildStatsCards(),
              _buildFilters(),
              SizedBox(
                height: compactListHeight,
                child: _buildAnomalyList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(String? role,
      {bool isCompact = false, bool isMobile = false}) {
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
            label: Text(
              isMobile ? 'Reload' : 'Refresh',
              style: const TextStyle(fontSize: 12),
            ),
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
    final minWidth = view == 'investigation' ? 220.0 : 160.0;
    return InkWell(
      onTap: () => setState(() => _activeView = view),
      child: Container(
        constraints: BoxConstraints(minWidth: minWidth),
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
          mainAxisAlignment: MainAxisAlignment.center,
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
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 900 ? 12 : 20,
                vertical: 12,
              ),
              child: constraints.maxWidth >= _anomalyDesktopBreakpoint
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
                                width: constraints.maxWidth >=
                                        _anomalyMobileBreakpoint
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
              items: _anomalySeverityFilterItems,
              onChanged: (value) {
                setState(() => _selectedSeverity = value!);
                _loadAnomalies();
              },
            );

            final statusWidget = _buildFilterDropdown(
              label: 'Status',
              value: _selectedStatus,
              items: _anomalyStatusFilterItems,
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
        final role = Provider.of<AuthProvider>(context, listen: false)
            .currentUser?['role'];
        final canUseAnomalyActions = role != 'investigator';
        final screenWidth = MediaQuery.of(context).size.width;
        final isDesktopTable = screenWidth >= _anomalyDesktopBreakpoint;
        final isMobileTable = screenWidth < _anomalyMobileBreakpoint;
        final isTabletTable = !isDesktopTable && !isMobileTable;

        if (provider.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)));
        }

        if (provider.error != null) {
          return _buildScrollableState(
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
          return _buildScrollableState(
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
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final displayAnomalies = provider.anomalies;

        final horizontalPadding =
            MediaQuery.of(context).size.width < _anomalyMobileBreakpoint
                ? 12.0
                : 20.0;

        if (isMobileTable) {
          return Padding(
            padding: EdgeInsets.only(
              left: horizontalPadding,
              right: horizontalPadding,
              top: 12,
              bottom: 8,
            ),
            child: ListView.separated(
              itemCount: displayAnomalies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final anomaly = displayAnomalies[index];
                return AnomalyCardWidget(
                  anomaly: anomaly,
                  onTap: () => _showAnomalyDetails(anomaly),
                );
              },
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(
            left: horizontalPadding,
            right: horizontalPadding,
            top: 16,
            bottom: 8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minTableWidth = isDesktopTable
                  ? 980.0
                  : (isTabletTable ? 760.0 : constraints.maxWidth);
              final tableWidth = constraints.maxWidth < minTableWidth
                  ? minTableWidth
                  : constraints.maxWidth;
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
                              if (!isMobileTable)
                                _buildHeaderCell('Score', flex: 1),
                              if (isDesktopTable || isTabletTable)
                                _buildHeaderCell('Firearm', flex: 2),
                              if (isDesktopTable || isTabletTable)
                                _buildHeaderCell('Officer', flex: 2),
                              if (isDesktopTable)
                                _buildHeaderCell('Unit', flex: 2),
                              _buildHeaderCell('Detected', flex: 2),
                              if (!isMobileTable)
                                _buildHeaderCell('Status', flex: 1),
                              if (canUseAnomalyActions)
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
                              displayAnomalies[index],
                              index,
                              isDesktopTable: isDesktopTable,
                              isMobileTable: isMobileTable,
                              canUseAnomalyActions: canUseAnomalyActions,
                            ),
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

  Widget _buildScrollableState({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: child,
              ),
            ),
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

  Widget _buildAnomalyRow(
    Map<String, dynamic> anomaly,
    int index, {
    required bool isDesktopTable,
    required bool isMobileTable,
    required bool canUseAnomalyActions,
  }) {
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

    return staggeredItem(
      InkWell(
        onTap: canUseAnomalyActions ? null : () => _showAnomalyDetails(anomaly),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: index % 2 == 0
                ? const Color(0xFF2A3040)
                : const Color(0xFF252A3A),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 1,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: severityColor.withValues(alpha: 0.3)),
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
              if (!isMobileTable)
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
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
                      ),
                      const SizedBox(width: 6),
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
              if (!isMobileTable)
                Expanded(
                  flex: 2,
                  child: Text(
                    anomaly['serial_number'] ?? 'N/A',
                    style: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (!isMobileTable)
                Expanded(
                  flex: 2,
                  child: Text(
                    anomaly['officer_name'] ?? 'N/A',
                    style: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (isDesktopTable)
                Expanded(
                  flex: 2,
                  child: Text(
                    anomaly['unit_name'] ?? 'N/A',
                    style: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              if (!isMobileTable)
                Expanded(
                  flex: 1,
                  child: Row(
                    children: [
                      Expanded(child: _buildAnomalyStatusBadge(status)),
                      if ((anomaly['explanation_requested'] == true || severity == 'critical') &&
                          (anomaly['explanation_message'] == null ||
                              anomaly['explanation_message'].toString().isEmpty))
                        const Tooltip(
                          message: 'Explanation Required',
                          child: Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFE85C5C), size: 16),
                        ),
                    ],
                  ),
                ),
              if (canUseAnomalyActions)
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
        ),
      ),
      index,
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
      'abnormal_custody_duration': 'Abnormal Custody Duration',
      'high_transfer_frequency': 'High Transfer Frequency',
      'high_officer_rotation': 'High Officer Rotation',
      'high_station_loss_rate': 'High Station Loss Rate',
      'excessive_short_assignments': 'Excessive Short Assignments',
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

class _SearchTableHeader extends StatelessWidget {
  final String label;

  const _SearchTableHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF78909C),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ============================================================
// Investigation Search Panel - Filter by unit and time interval
// ============================================================
class _InvestigationSearchPanel extends StatefulWidget {
  const _InvestigationSearchPanel();

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
    final today = DateTime.now();
    final initialDate = isStart
        ? (_startDate ?? _endDate ?? today.subtract(const Duration(days: 30)))
        : (_endDate ?? today);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(today) ? today : initialDate,
      firstDate: DateTime(2020),
      lastDate: today,
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
          if (_endDate != null && picked.isAfter(_endDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _startDate = null;
          }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 720 ? 12.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchForm(),
              const SizedBox(height: 20),
              _buildSearchResults(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSingleColumn = constraints.maxWidth < 680;
          final fields = [
            _buildUnitDropdown(),
            _buildDatePicker(
              'Start Date',
              _startDate,
              () => _selectDate(true),
            ),
            _buildDatePicker(
              'End Date',
              _endDate,
              () => _selectDate(false),
            ),
            _buildDropdownField(
              'Severity',
              _searchSeverity,
              _anomalySeverityFilterItems,
              (v) => setState(() => _searchSeverity = v!),
            ),
            _buildDropdownField(
              'Status',
              _searchStatus,
              _anomalyStatusFilterItems,
              (v) => setState(() => _searchStatus = v!),
            ),
            _buildSearchActions(),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.search,
                      color: Color(0xFF1E88E5),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Investigation Search',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Search anomaly data by unit and time interval',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _buildInvestigationFormGrid(
                fields: fields,
                isSingleColumn: isSingleColumn,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInvestigationFormGrid({
    required List<Widget> fields,
    required bool isSingleColumn,
  }) {
    if (isSingleColumn) {
      return Column(
        children: [
          for (int i = 0; i < fields.length; i++) ...[
            fields[i],
            if (i < fields.length - 1)
              const SizedBox(height: _investigationFormGap),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (int i = 0; i < fields.length; i += 2) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: fields[i]),
              const SizedBox(width: _investigationFormGap),
              Expanded(child: fields[i + 1]),
            ],
          ),
          if (i + 2 < fields.length)
            const SizedBox(height: _investigationFormGap),
        ],
      ],
    );
  }

  Widget _buildSearchActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Actions',
          style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 11),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final stackButtons = constraints.maxWidth < 300;
            final searchButton = SizedBox(
              height: _investigationControlHeight,
              child: ElevatedButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search', overflow: TextOverflow.ellipsis),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
            final clearButton = SizedBox(
              height: _investigationControlHeight,
              child: OutlinedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_list_off, size: 18),
                label: const Text('Clear', overflow: TextOverflow.ellipsis),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB0BEC5),
                  side: const BorderSide(color: Color(0xFF37404F)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );

            if (stackButtons) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchButton,
                  const SizedBox(height: 10),
                  clearButton,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: searchButton),
                const SizedBox(width: 10),
                Expanded(child: clearButton),
              ],
            );
          },
        ),
      ],
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedUnitId = null;
      _startDate = null;
      _endDate = null;
      _searchSeverity = 'all';
      _searchStatus = 'all';
    });
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
            const SizedBox(height: 6),
            SearchableDropdown<String?>(
              items: [
                const SearchableDropdownItem<String?>(
                  value: null,
                  label: 'All Units',
                  icon: Icons.public,
                ),
                ...units.map(
                  (u) => SearchableDropdownItem<String?>(
                    value: u['unit_id']?.toString(),
                    label: u['unit_name']?.toString() ?? 'Unknown unit',
                    subtitle: u['unit_code']?.toString(),
                    icon: Icons.account_tree_outlined,
                  ),
                ),
              ],
              value: _selectedUnitId,
              hintText: 'Search unit or keep all units',
              prefixIcon: Icons.account_tree_outlined,
              fieldHeight: _investigationControlHeight,
              fillColor: const Color(0xFF1A1F2E),
              onChanged: (value) => setState(() => _selectedUnitId = value),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 11)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: _investigationControlHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              border: Border.all(color: const Color(0xFF37404F)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    date != null
                        ? DateFormat('dd/MM/yyyy').format(date)
                        : 'Select date',
                    style: TextStyle(
                      color: date != null ? Colors.white : Colors.white54,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
        const SizedBox(height: 6),
        Container(
          height: _investigationControlHeight,
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: items
                  .map((item) => DropdownMenuItem<String>(
                        value: item['value'],
                        child: Text(
                          item['label']!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
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
          return const SizedBox(
            height: 220,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
            ),
          );
        }

        final results = provider.investigationResults;
        if (results.isEmpty) {
          return Container(
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF252A3A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off,
                    color: const Color(0xFF78909C).withValues(alpha: 0.5),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No results',
                    style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use the filters above to search for anomalies related to your investigation',
                    style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final tableWidth =
                      constraints.maxWidth < 980 ? 980.0 : constraints.maxWidth;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildResultsHeaderRow(),
                          for (int index = 0; index < results.length; index++)
                            _buildResultRow(results[index], index),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultsHeaderRow() {
    final role =
        Provider.of<AuthProvider>(context, listen: false).currentUser?['role'];
    final canUseAnomalyActions = role != 'investigator';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF37404F), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Expanded(flex: 2, child: _SearchTableHeader('ID')),
          const Expanded(flex: 2, child: _SearchTableHeader('Type')),
          const Expanded(flex: 1, child: _SearchTableHeader('Severity')),
          const Expanded(flex: 2, child: _SearchTableHeader('Officer')),
          const Expanded(flex: 2, child: _SearchTableHeader('Unit')),
          const Expanded(flex: 2, child: _SearchTableHeader('Detected')),
          const Expanded(flex: 1, child: _SearchTableHeader('Status')),
          if (canUseAnomalyActions)
            const Expanded(flex: 1, child: _SearchTableHeader('Actions')),
        ],
      ),
    );
  }

  Widget _buildResultRow(Map<String, dynamic> anomaly, int index) {
    final severity = anomaly['severity']?.toString() ?? 'medium';
    final status = anomaly['status']?.toString() ?? 'open';
    final role =
        Provider.of<AuthProvider>(context, listen: false).currentUser?['role'];
    final canUseAnomalyActions = role != 'investigator';

    return InkWell(
      onTap: canUseAnomalyActions
          ? null
          : () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.5),
                builder: (_) => _AnomalyDetailModal(
                  anomaly: anomaly,
                  onActionComplete: () {},
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              index.isEven ? const Color(0xFF2A3040) : const Color(0xFF252A3A),
          border: const Border(
            bottom: BorderSide(color: Color(0xFF37404F), width: 1),
          ),
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
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatAnomalyType(anomaly['anomaly_type']?.toString() ?? ''),
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 1, child: _buildSeverityBadge(severity)),
            Expanded(
              flex: 2,
              child: Text(
                anomaly['officer_name']?.toString() ?? 'N/A',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                anomaly['unit_name']?.toString() ?? 'N/A',
                style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatDateTime(anomaly['event_at'] ?? anomaly['detected_at']),
                style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 1, child: _buildAnomalyStatusBadge(status)),
            if (canUseAnomalyActions)
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.info_outline, size: 18),
                    color: const Color(0xFF1E88E5),
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.5),
                        builder: (_) => _AnomalyDetailModal(
                          anomaly: anomaly,
                          onActionComplete: () {},
                        ),
                      );
                    },
                    tooltip: 'View Details',
                  ),
                ),
              ),
          ],
        ),
      ),
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
      'abnormal_custody_duration': 'Abnormal Custody Duration',
      'high_transfer_frequency': 'High Transfer Frequency',
      'high_officer_rotation': 'High Officer Rotation',
      'high_station_loss_rate': 'High Station Loss Rate',
      'excessive_short_assignments': 'Excessive Short Assignments',
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

    if (action == 'archive') {
      final confirmed = await ConfirmationDialog.show(
        context,
        title: 'Archive anomaly?',
        message:
            'This will hide the anomaly from the active dashboard but keep it in the system for accountability and future review.',
        confirmText: 'Archive',
        icon: Icons.archive_outlined,
      );

      if (confirmed != true) return;
      if (!mounted) return;
    }

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
      case 'acceptable_change':
        success = await provider.markAcceptableChange(anomalyId,
            notes: notes.isNotEmpty ? notes : null);
        break;
      case 'archive':
        success = await provider.archiveAnomaly(anomalyId,
            note: notes.isNotEmpty ? notes : null);
        break;
      case 'explanation':
        final message = _explanationController.text.trim();
        if (message.isEmpty) {
          setState(() => _isProcessing = false);
          return;
        }
        success = await provider.submitExplanation(anomalyId, message: message);
        break;
      case 'request_explanation':
        success = await provider.requestExplanation(anomalyId);
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
      'acceptable_change': 'Marked as acceptable operational change',
      'archive':
          'Archived from the active dashboard. It remains available in history and system records.',
      'explanation': 'Explanation submitted successfully',
      'request_explanation': 'Explanation requested successfully',
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
    final canManageAnomaly = role == 'station_commander';
    final isHqOrInvestigator = role == 'hq_firearm_commander' || role == 'investigator';
    final hasExplanation = widget.anomaly['explanation_message'] != null &&
        widget.anomaly['explanation_message'].toString().isNotEmpty;
    final explanationRequested = widget.anomaly['explanation_requested'] == true;

    IconData severityIcon;
    switch (severity) {
      case 'critical':
        severityIcon = Icons.error;
        break;
      case 'high':
        severityIcon = Icons.warning;
        break;
      case 'medium':
        severityIcon = Icons.info;
        break;
      default:
        severityIcon = Icons.info_outline;
    }

    final actionButtons = <Widget>[];

    if (isOpen && canManageAnomaly) {
      actionButtons.addAll([
        OutlinedButton.icon(
          onPressed:
              _isProcessing ? null : () => _performAction('false_positive'),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('False Positive'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB0BEC5),
            side: const BorderSide(color: Color(0xFF37404F)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed:
              _isProcessing ? null : () => _performAction('acceptable_change'),
          icon: const Icon(Icons.rule, size: 18),
          label: const Text('Acceptable Change'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF42A5F5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : () => _performAction('resolve'),
          icon: const Icon(Icons.check_circle, size: 18),
          label: const Text('Resolve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3CCB7F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ]);
    }

    if (canManageAnomaly && status != 'archived') {
      actionButtons.add(
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : () => _performAction('archive'),
          icon: const Icon(Icons.archive_outlined, size: 18),
          label: const Text('Archive'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB0BEC5),
            side: const BorderSide(color: Color(0xFF37404F)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );
    }

    if (isHqOrInvestigator && !explanationRequested) {
      actionButtons.add(
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : () => _performAction('request_explanation'),
          icon: const Icon(Icons.help_outline, size: 18),
          label: Text(hasExplanation ? 'Ask for Better Explanation' : 'Ask for Explanation'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF42A5F5),
            side: const BorderSide(color: Color(0xFF37404F)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      );
    }

    if (_isProcessing) {
      actionButtons.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: Color(0xFF1E88E5),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    final showExplanationForm = canManageAnomaly && isOpen && (!hasExplanation || explanationRequested);

    return BaseModalWidget(
      width: 700,
      headerTitle: 'Anomaly Details',
      headerSubtitle:
          'ID: ${widget.anomaly['anomaly_id']?.toString() ?? 'N/A'} — ${_formatAnomalyType(widget.anomaly['anomaly_type'] ?? '')}',
      headerIcon: severityIcon,
      onClose: () {
        if (!_isProcessing) {
          Navigator.pop(context);
        }
      },
      footerActions: actionButtons,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showExplanationForm) ...[
            _buildSectionHeader(hasExplanation ? 'Provide Updated Explanation' : 'Provide Explanation'),
            const SizedBox(height: 12),
            Text(
              explanationRequested
                  ? 'HQ has explicitly requested an explanation for this anomaly. Please provide details.'
                  : (isCritical
                      ? 'As station commander, you must provide an explanation for this critical anomaly detected in your unit.'
                      : 'You can optionally provide an explanation for this anomaly detected in your unit.'),
              style: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _explanationController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: _inputDecoration(
                hasExplanation ? 'Provide additional or updated details...' : 'Explain the circumstances of this anomaly...',
                Icons.edit_note,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  _isProcessing ? null : () => _performAction('explanation'),
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Submit Explanation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (hasExplanation) ...[
            _buildSectionHeader('Provided Explanation'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                border: Border.all(color: const Color(0xFF37404F)),
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
            const SizedBox(height: 24),
          ],
          _buildInfoSection('Detection Information', [
            _buildInfoRow('Type',
                _formatAnomalyType(widget.anomaly['anomaly_type'] ?? 'N/A')),
            _buildInfoRow('Severity', severity.toUpperCase()),
            _buildInfoRow('Score',
                '${((double.tryParse(widget.anomaly['anomaly_score']?.toString() ?? '0') ?? 0.0) * 100).toStringAsFixed(1)}%'),
            _buildInfoRow('Detection Method',
                _formatDetectionMethod(widget.anomaly['detection_method'])),
            _buildInfoRow('Confidence',
                '${((double.tryParse(widget.anomaly['confidence_level']?.toString() ?? '0') ?? 0.0) * 100).toStringAsFixed(1)}%'),
            _buildInfoRow('Detected At',
                _formatDateTimeFull(widget.anomaly['detected_at'])),
          ]),
          const SizedBox(height: 24),
          _buildInfoSection('Custody Information', [
            _buildInfoRow('Firearm', widget.anomaly['serial_number'] ?? 'N/A'),
            _buildInfoRow('Officer', widget.anomaly['officer_name'] ?? 'N/A'),
            _buildInfoRow('Unit', widget.anomaly['unit_name'] ?? 'N/A'),
            _buildInfoRow(
                'Custody Type', widget.anomaly['custody_type'] ?? 'N/A'),
          ]),
          const SizedBox(height: 24),
          if (contributingFactors != null &&
              contributingFactors.isNotEmpty) ...[
            _buildInfoSection(
              'Contributing Factors',
              contributingFactors.entries
                  .map((entry) => _buildInfoRow(
                      entry.key.replaceAll('_', ' ').toUpperCase(),
                      entry.value.toString()))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          if (featureImportance != null && featureImportance.isNotEmpty) ...[
            _buildInfoSection(
              'Feature Importance',
              featureImportance.entries.map((entry) {
                final value =
                    double.tryParse(entry.value?.toString() ?? '0') ?? 0.0;
                return _buildInfoRow(
                    entry.key.replaceAll('_', ' ').toUpperCase(),
                    '${(value * 100).toStringAsFixed(1)}%');
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          _buildInfoSection('Investigation Status', [
            _buildInfoRow('Status', widget.anomaly['status'] ?? 'N/A'),
            if (widget.anomaly['investigated_by'] != null)
              _buildInfoRow('Investigated By',
                  widget.anomaly['investigated_by'].toString()),
            if (widget.anomaly['resolution_date'] != null)
              _buildInfoRow('Resolved At',
                  _formatDateTimeFull(widget.anomaly['resolution_date'])),
            if (widget.anomaly['investigation_notes'] != null &&
                widget.anomaly['investigation_notes'].toString().isNotEmpty)
              _buildInfoRow('Investigation Notes',
                  widget.anomaly['investigation_notes'].toString()),
          ]),
          const SizedBox(height: 24),
          if (isOpen && canManageAnomaly) ...[
            _buildSectionHeader('Investigation Notes'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration:
                  _inputDecoration('Enter investigation notes...', Icons.notes),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF78909C), size: 18),
      filled: true,
      fillColor: const Color(0xFF1A1F2E),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF37404F)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1E88E5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  String _formatAnomalyType(String type) {
    return type
        .split('_')
        .map((word) =>
            word.isEmpty ? '' : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _formatDateTimeFull(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr.toString());
      return DateFormat('MMM d, yyyy HH:mm:ss').format(date);
    } catch (e) {
      return dateStr.toString();
    }
  }
}
