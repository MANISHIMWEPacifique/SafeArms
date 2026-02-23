import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';

/// HQ Firearm Commander – National Reports Screen
/// Report types: Firearm History, Custody Timeline, Ballistic Reference Summary, Anomaly Summary
class HqReportsScreen extends StatefulWidget {
  const HqReportsScreen({super.key});

  @override
  State<HqReportsScreen> createState() => _HqReportsScreenState();
}

class _HqReportsScreenState extends State<HqReportsScreen> {
  final AuthService _authService = AuthService();

  // Filter state
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _selectedUnitId;
  String _selectedReportType = 'firearm_history';

  // Data state
  bool _isLoading = false;
  bool _reportGenerated = false;
  String? _error;
  Map<String, dynamic> _reportData = {};
  List<Map<String, dynamic>> _units = [];

  final List<Map<String, String>> _reportTypes = [
    {'value': 'firearm_history', 'label': 'Firearm History Report'},
    {'value': 'custody_timeline', 'label': 'Custody Timeline Report'},
    {
      'value': 'ballistic_summary',
      'label': 'Ballistic Reference Summary Report'
    },
    {'value': 'anomaly_summary', 'label': 'Anomaly Summary Report'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadUnits() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(Uri.parse(ApiConfig.unitsUrl), headers: headers)
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _units = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _reportGenerated = false;
    });

    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'type': _selectedReportType,
      };
      if (_dateFrom != null) {
        queryParams['start_date'] = _dateFrom!.toIso8601String();
      }
      if (_dateTo != null) {
        queryParams['end_date'] = _dateTo!.toIso8601String();
      }
      if (_selectedUnitId != null && _selectedUnitId!.isNotEmpty) {
        queryParams['unit_id'] = _selectedUnitId!;
      }

      final uri = Uri.parse('${ApiConfig.reportsUrl}/generate')
          .replace(queryParameters: queryParams);
      final response =
          await http.get(uri, headers: headers).timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _reportData = Map<String, dynamic>.from(data['data'] ?? {});
          _reportGenerated = true;
        });
      } else {
        final err = json.decode(response.body);
        setState(() {
          _error = err['message'] ?? 'Failed to generate report';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error generating report: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'National Reports – HQ Oversight',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate structured reports for national firearms oversight',
            style: TextStyle(color: Color(0xFF78909C), fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Filters
          _buildFilterSection(),
          const SizedBox(height: 24),

          // Error
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE85C5C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFFE85C5C).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Color(0xFFE85C5C), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              color: Color(0xFFE85C5C), fontSize: 13))),
                ],
              ),
            ),

          // Loading
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(48),
                child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
              ),
            ),

          // Report content
          if (_reportGenerated && !_isLoading) _buildReportContent(),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Row(
        children: [
          // Date From
          Expanded(
            child: _buildDatePicker('From', _dateFrom, (date) {
              setState(() => _dateFrom = date);
            }),
          ),
          const SizedBox(width: 12),
          // Date To
          Expanded(
            child: _buildDatePicker('To', _dateTo, (date) {
              setState(() => _dateTo = date);
            }),
          ),
          const SizedBox(width: 12),
          // Unit Filter
          Expanded(
            child: _buildDropdown(
              label: 'Unit',
              value: _selectedUnitId,
              items: [
                const DropdownMenuItem(value: '', child: Text('All Units')),
                ..._units.map((u) => DropdownMenuItem(
                      value: u['unit_id']?.toString() ?? '',
                      child: Text(u['unit_name']?.toString() ?? ''),
                    )),
              ],
              onChanged: (v) => setState(() => _selectedUnitId = v),
            ),
          ),
          const SizedBox(width: 12),
          // Report Type
          Expanded(
            child: _buildDropdown(
              label: 'Report Type',
              value: _selectedReportType,
              items: _reportTypes
                  .map((rt) => DropdownMenuItem(
                        value: rt['value'],
                        child:
                            Text(rt['label']!, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedReportType = v ?? 'firearm_history'),
            ),
          ),
          const SizedBox(width: 16),
          // Generate
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateReport,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Generate Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          // Export PDF
          OutlinedButton.icon(
            onPressed: _reportGenerated ? () {} : null,
            icon: const Icon(Icons.picture_as_pdf, size: 18),
            label: const Text('Export PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _reportGenerated
                  ? const Color(0xFFB0BEC5)
                  : const Color(0xFF546E7A),
              side: BorderSide(
                  color: _reportGenerated
                      ? const Color(0xFF37404F)
                      : const Color(0xFF37404F).withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker(
      String label, DateTime? value, ValueChanged<DateTime?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12)),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme:
                      const ColorScheme.dark(primary: Color(0xFF1E88E5)),
                ),
                child: child!,
              ),
            );
            if (date != null) onChanged(date);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? DateFormat('MMM d, yyyy').format(value)
                        : 'Select date',
                    style: TextStyle(
                      color: value != null
                          ? Colors.white
                          : const Color(0xFF78909C),
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today,
                    color: Color(0xFF78909C), size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: const Color(0xFF252A3A),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              icon: const Icon(Icons.expand_more,
                  color: Color(0xFF78909C), size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportContent() {
    final reportLabel = _reportTypes
        .firstWhere((r) => r['value'] == _selectedReportType)['label']!;
    final generatedAt =
        DateFormat('MMM d, yyyy – h:mm a').format(DateTime.now());
    final unitName = _selectedUnitId != null && _selectedUnitId!.isNotEmpty
        ? _units
            .firstWhere((u) => u['unit_id']?.toString() == _selectedUnitId,
                orElse: () => {'unit_name': 'Unknown'})['unit_name']
            ?.toString()
        : 'All Units';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3040),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          _buildReportHeader(reportLabel, generatedAt, unitName ?? 'All Units'),
          const Divider(color: Color(0xFF37404F), height: 32),

          // Report body by type
          if (_selectedReportType == 'firearm_history')
            _buildFirearmHistoryReport(),
          if (_selectedReportType == 'custody_timeline')
            _buildCustodyTimelineReport(),
          if (_selectedReportType == 'ballistic_summary')
            _buildBallisticSummaryReport(),
          if (_selectedReportType == 'anomaly_summary')
            _buildAnomalySummaryReport(),
        ],
      ),
    );
  }

  Widget _buildReportHeader(String title, String generatedAt, String unitName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 32,
          runSpacing: 8,
          children: [
            _buildHeaderMeta('Generated', generatedAt),
            _buildHeaderMeta(
                'Date Range',
                _dateFrom != null && _dateTo != null
                    ? '${DateFormat('MMM d, yyyy').format(_dateFrom!)} – ${DateFormat('MMM d, yyyy').format(_dateTo!)}'
                    : 'All time'),
            _buildHeaderMeta('Unit', unitName),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderMeta(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ==============================
  // FIREARM HISTORY REPORT
  // ==============================
  Widget _buildFirearmHistoryReport() {
    final firearms =
        List<Map<String, dynamic>>.from(_reportData['firearms'] ?? []);

    if (firearms.isEmpty) {
      return _buildEmptyState(
          'No firearm records found for the selected filters.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Firearm Details'),
        const SizedBox(height: 12),
        _buildDataTable(
          columns: const [
            'Serial Number',
            'Type',
            'Caliber',
            'Registered',
            'Current Unit'
          ],
          rows: firearms
              .map((f) => [
                    f['serial_number']?.toString() ?? '',
                    f['firearm_type']?.toString() ?? '',
                    f['caliber']?.toString() ?? '',
                    _fmtDate(f['registration_date']?.toString()),
                    f['unit_name']?.toString() ?? 'Unassigned',
                  ])
              .toList(),
        ),

        // Unit assignment history
        if (_reportData['unit_history'] != null) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Unit Assignment History'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Unit Name', 'Assigned Date', 'Released Date'],
            rows: List<Map<String, dynamic>>.from(
                    _reportData['unit_history'] ?? [])
                .map((h) => [
                      h['unit_name']?.toString() ?? '',
                      _fmtDate(h['assigned_date']?.toString()),
                      _fmtDate(h['released_date']?.toString()),
                    ])
                .toList(),
          ),
        ],

        // Custody timeline
        if (_reportData['custody_records'] != null) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Custody Timeline'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const [
              'Officer',
              'Issued Date',
              'Returned Date',
              'Duration',
              'Unit'
            ],
            rows: List<Map<String, dynamic>>.from(
                    _reportData['custody_records'] ?? [])
                .map((c) => [
                      c['officer_name']?.toString() ??
                          c['officer_id']?.toString() ??
                          '',
                      _fmtDate(c['issued_at']?.toString()),
                      _fmtDate(c['returned_at']?.toString()),
                      c['duration']?.toString() ?? '–',
                      c['unit_name']?.toString() ?? '',
                    ])
                .toList(),
          ),
        ],

        // Related anomalies
        if (_reportData['anomalies'] != null &&
            (_reportData['anomalies'] as List).isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Related Anomalies'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const ['Anomaly ID', 'Severity', 'Status'],
            rows:
                List<Map<String, dynamic>>.from(_reportData['anomalies'] ?? [])
                    .map((a) => [
                          a['anomaly_id']?.toString() ?? '',
                          a['severity']?.toString() ?? '',
                          a['status']?.toString() ?? '',
                        ])
                    .toList(),
          ),
        ],
      ],
    );
  }

  // ==============================
  // CUSTODY TIMELINE REPORT
  // ==============================
  Widget _buildCustodyTimelineReport() {
    final records =
        List<Map<String, dynamic>>.from(_reportData['custody_records'] ?? []);

    if (records.isEmpty) {
      return _buildEmptyState(
          'No custody records found for the selected filters.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Custody Records'),
        const SizedBox(height: 12),
        _buildDataTable(
          columns: const [
            'Serial Number',
            'Officer',
            'Unit',
            'Issued',
            'Returned',
            'Status'
          ],
          rows: records
              .map((c) => [
                    c['serial_number']?.toString() ?? '',
                    c['officer_name']?.toString() ?? '',
                    c['unit_name']?.toString() ?? '',
                    _fmtDate(c['issued_at']?.toString()),
                    _fmtDate(c['returned_at']?.toString()),
                    c['custody_status']?.toString() ?? '',
                  ])
              .toList(),
        ),
      ],
    );
  }

  // ==============================
  // BALLISTIC SUMMARY REPORT
  // ==============================
  Widget _buildBallisticSummaryReport() {
    final profiles =
        List<Map<String, dynamic>>.from(_reportData['profiles'] ?? []);

    if (profiles.isEmpty) {
      return _buildEmptyState(
          'No ballistic profiles found for the selected filters.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Ballistic Profiles'),
        const SizedBox(height: 12),
        _buildDataTable(
          columns: const [
            'Serial Number',
            'Caliber',
            'Barrel Length',
            'Rifling',
            'Recorded'
          ],
          rows: profiles
              .map((p) => [
                    p['serial_number']?.toString() ?? '',
                    p['caliber']?.toString() ?? '',
                    p['barrel_length']?.toString() ?? '',
                    p['rifling_type']?.toString() ?? '',
                    _fmtDate(p['created_at']?.toString()),
                  ])
              .toList(),
        ),
      ],
    );
  }

  // ==============================
  // ANOMALY SUMMARY REPORT
  // ==============================
  Widget _buildAnomalySummaryReport() {
    final anomalies =
        List<Map<String, dynamic>>.from(_reportData['anomalies'] ?? []);
    final summary = Map<String, dynamic>.from(_reportData['summary'] ?? {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary cards
        Row(
          children: [
            _buildSummaryCard(
                'Total Anomalies', summary['total']?.toString() ?? '0'),
            const SizedBox(width: 12),
            _buildSummaryCard(
                'High Severity', summary['high']?.toString() ?? '0'),
            const SizedBox(width: 12),
            _buildSummaryCard(
                'Medium Severity', summary['medium']?.toString() ?? '0'),
            const SizedBox(width: 12),
            _buildSummaryCard(
                'Low Severity', summary['low']?.toString() ?? '0'),
          ],
        ),
        const SizedBox(height: 24),

        if (anomalies.isEmpty)
          _buildEmptyState('No anomalies found for the selected filters.')
        else ...[
          _buildSectionTitle('Anomaly Details'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const [
              'Anomaly ID',
              'Firearm Serial',
              'Unit',
              'Severity',
              'Status',
              'Date Detected'
            ],
            rows: anomalies
                .map((a) => [
                      a['anomaly_id']?.toString() ?? '',
                      a['serial_number']?.toString() ?? '',
                      a['unit_name']?.toString() ?? '',
                      a['severity']?.toString() ?? '',
                      a['status']?.toString() ?? '',
                      _fmtDate(a['detected_at']?.toString()),
                    ])
                .toList(),
          ),
        ],
      ],
    );
  }

  // ==============================
  // SHARED WIDGETS
  // ==============================

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF42A5F5),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF37404F)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable({
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF37404F)),
      ),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFF252A3A)),
        dataRowColor: WidgetStateProperty.all(const Color(0xFF1A1F2E)),
        headingRowHeight: 44,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 44,
        columnSpacing: 24,
        columns: columns
            .map((c) => DataColumn(
                  label: Text(
                    c.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFB0BEC5),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ))
            .toList(),
        rows: rows
            .map((r) => DataRow(
                  cells: r
                      .map((cell) => DataCell(
                            Text(
                              cell,
                              style: const TextStyle(
                                  color: Color(0xFFB0BEC5), fontSize: 13),
                            ),
                          ))
                      .toList(),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined,
                color: Color(0xFF78909C), size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Color(0xFF78909C), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '–';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}
