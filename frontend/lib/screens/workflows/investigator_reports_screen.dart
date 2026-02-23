import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/api_config.dart';
import '../../services/auth_service.dart';

/// Investigator – Investigation Support Reports Screen
/// Report types: Firearm History, Custody Timeline, Ballistic Reference Summary
class InvestigatorReportsScreen extends StatefulWidget {
  const InvestigatorReportsScreen({super.key});

  @override
  State<InvestigatorReportsScreen> createState() =>
      _InvestigatorReportsScreenState();
}

class _InvestigatorReportsScreenState extends State<InvestigatorReportsScreen> {
  final AuthService _authService = AuthService();

  // Filter state
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _caseRefController = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String _selectedReportType = 'firearm_history';

  // Data state
  bool _isLoading = false;
  bool _reportGenerated = false;
  String? _error;
  Map<String, dynamic> _reportData = {};

  final List<Map<String, String>> _reportTypes = [
    {'value': 'firearm_history', 'label': 'Firearm History Report'},
    {'value': 'custody_timeline', 'label': 'Custody Timeline Report'},
    {
      'value': 'ballistic_summary',
      'label': 'Ballistic Reference Summary Report'
    },
  ];

  @override
  void dispose() {
    _serialController.dispose();
    _caseRefController.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
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
      if (_serialController.text.trim().isNotEmpty) {
        queryParams['serial_number'] = _serialController.text.trim();
      }
      if (_caseRefController.text.trim().isNotEmpty) {
        queryParams['case_ref'] = _caseRefController.text.trim();
      }
      if (_dateFrom != null) {
        queryParams['start_date'] = _dateFrom!.toIso8601String();
      }
      if (_dateTo != null) {
        queryParams['end_date'] = _dateTo!.toIso8601String();
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
            'Investigation Support Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate read-only investigative reports for firearms and custody chains',
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
          // Serial Number Search
          Expanded(
            child: _buildTextField(
              label: 'Firearm Serial Number',
              controller: _serialController,
              hint: 'Enter serial number',
              icon: Icons.search,
            ),
          ),
          const SizedBox(width: 12),
          // Case Reference
          Expanded(
            child: _buildTextField(
              label: 'Case Reference (Optional)',
              controller: _caseRefController,
              hint: 'Enter case reference',
              icon: Icons.folder_outlined,
            ),
          ),
          const SizedBox(width: 12),
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
            label: const Text('Generate'),
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
            label: const Text('PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _reportGenerated
                  ? const Color(0xFFB0BEC5)
                  : const Color(0xFF546E7A),
              side: BorderSide(
                  color: _reportGenerated
                      ? const Color(0xFF37404F)
                      : const Color(0xFF37404F).withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Color(0xFF78909C), fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF37404F)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: Color(0xFF78909C), fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFF78909C), size: 18),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
      ],
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
          _buildReportHeader(reportLabel, generatedAt),
          const Divider(color: Color(0xFF37404F), height: 32),

          // Report body
          if (_selectedReportType == 'firearm_history')
            _buildFirearmHistoryReport(),
          if (_selectedReportType == 'custody_timeline')
            _buildCustodyTimelineReport(),
          if (_selectedReportType == 'ballistic_summary')
            _buildBallisticSummaryReport(),

          // Footer disclaimer
          const SizedBox(height: 32),
          const Divider(color: Color(0xFF37404F)),
          const SizedBox(height: 12),
          const Text(
            'This document contains administrative firearm and ballistic reference metadata '
            'and does not replace laboratory forensic examination.',
            style: TextStyle(
              color: Color(0xFF78909C),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader(String title, String generatedAt) {
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
            if (_serialController.text.isNotEmpty)
              _buildHeaderMeta('Serial Number', _serialController.text),
            if (_caseRefController.text.isNotEmpty)
              _buildHeaderMeta('Case Reference', _caseRefController.text),
            _buildHeaderMeta(
                'Date Range',
                _dateFrom != null && _dateTo != null
                    ? '${DateFormat('MMM d, yyyy').format(_dateFrom!)} – ${DateFormat('MMM d, yyyy').format(_dateTo!)}'
                    : 'All time'),
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
          'No firearm records found. Try searching by serial number.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1 – Firearm Information
        _buildSectionTitle('Firearm Information'),
        const SizedBox(height: 12),
        _buildDataTable(
          columns: const [
            'Serial Number',
            'Type',
            'Caliber',
            'Current Unit',
            'Registered'
          ],
          rows: firearms
              .map((f) => [
                    f['serial_number']?.toString() ?? '',
                    f['firearm_type']?.toString() ?? '',
                    f['caliber']?.toString() ?? '',
                    f['unit_name']?.toString() ?? 'Unassigned',
                    _fmtDate(f['registration_date']?.toString()),
                  ])
              .toList(),
        ),

        // Section 2 – Custody Timeline
        if (_reportData['custody_records'] != null) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Custody Timeline'),
          const SizedBox(height: 12),
          _buildDataTable(
            columns: const [
              'Officer',
              'Unit',
              'Issued Date',
              'Returned Date',
              'Duration'
            ],
            rows: List<Map<String, dynamic>>.from(
                    _reportData['custody_records'] ?? [])
                .map((c) => [
                      c['officer_name']?.toString() ??
                          c['officer_id']?.toString() ??
                          '',
                      c['unit_name']?.toString() ?? '',
                      _fmtDate(c['issued_at']?.toString()),
                      _fmtDate(c['returned_at']?.toString()),
                      c['duration']?.toString() ?? '–',
                    ])
                .toList(),
          ),
        ],

        // Section 3 – Linked Anomalies
        if (_reportData['anomalies'] != null &&
            (_reportData['anomalies'] as List).isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Linked Anomalies'),
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

        // Section 4 – Ballistic Reference Metadata
        if (_reportData['ballistic_profile'] != null) ...[
          const SizedBox(height: 24),
          _buildSectionTitle('Ballistic Reference Metadata'),
          const SizedBox(height: 12),
          _buildMetadataGrid(
              Map<String, dynamic>.from(_reportData['ballistic_profile'])),
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
        _buildSectionTitle('Custody Records – Chronological'),
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
        _buildSectionTitle('Ballistic Reference Profiles'),
        const SizedBox(height: 12),
        ...profiles.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF37404F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Firearm: ${p['serial_number'] ?? 'N/A'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildMetadataGrid(p),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetadataGrid(Map<String, dynamic> profile) {
    final fields = [
      {'label': 'Caliber', 'key': 'caliber'},
      {'label': 'Chamber Type', 'key': 'chamber_type'},
      {'label': 'Rifling Characteristics', 'key': 'rifling_type'},
      {'label': 'Breech-face Description', 'key': 'breech_face_marks'},
      {'label': 'Firing Pin Description', 'key': 'firing_pin_shape'},
      {'label': 'Date Recorded', 'key': 'created_at'},
    ];
    return Wrap(
      spacing: 32,
      runSpacing: 12,
      children: fields.map((f) {
        final val = f['key'] == 'created_at'
            ? _fmtDate(profile[f['key']]?.toString())
            : profile[f['key']]?.toString() ?? '–';
        return SizedBox(
          width: 260,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 140,
                child: Text(
                  '${f['label']}:',
                  style:
                      const TextStyle(color: Color(0xFF78909C), fontSize: 13),
                ),
              ),
              Expanded(
                child: Text(
                  val,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      }).toList(),
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
